import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/services/notification_service.dart';

/// บริการจัดการด้านการกำกับดูแลความปลอดภัย การลงโทษ และการระงับบัญชีผู้ใช้
class ModerationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ระงับการใช้งานบัญชีผู้ใช้ (รองรับทั้งชั่วคราวและถาวร) พร้อมซ่อนสินค้าอัตโนมัติ
  static Future<bool> banUser({
    required String userId,
    required String reason,
    Duration? duration,
    String? adminUid,
  }) async {
    if (userId.isEmpty) return false;

    try {
      Timestamp? bannedUntil;
      if (duration != null) {
        bannedUntil = Timestamp.fromDate(DateTime.now().add(duration));
      }

      // 1. อัปเดตสถานะผู้ใช้
      await _db.collection(FirestoreCollections.users).doc(userId).update({
        'status': 'banned',
        'banReason': reason,
        'bannedUntil': bannedUntil,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': adminUid ?? 'Admin',
        'moderated_at': FieldValue.serverTimestamp(),
        'moderated_by': adminUid ?? 'Admin',
        'strikeCount': FieldValue.increment(1),
      });

      // 2. ซ่อนสินค้าทั้งหมดของผู้ขายชั่วคราว
      try {
        final productsQuery = await _db
            .collection(FirestoreCollections.products)
            .where('sellerId', isEqualTo: userId)
            .where('status', isEqualTo: 'active')
            .get();

        if (productsQuery.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var doc in productsQuery.docs) {
            batch.update(doc.reference, {
              'status': 'suspended_by_admin',
              'suspendedReason': reason,
              'suspendedAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
      } catch (prodErr) {
        debugPrint("Error hiding products for banned user $userId: $prodErr");
      }

      // 3. ส่งข้อความแจ้งเตือนผู้ใช้
      String durationText = duration != null
          ? "เป็นเวลา ${_formatDuration(duration)}"
          : "อย่างถาวร";
      await NotificationService.sendNotification(
        userId: userId,
        title: "บัญชีถูกระงับการใช้งาน 🚫",
        body: "บัญชีของคุณถูกระงับ $durationText เนื่องจาก: $reason",
        type: 'system',
      );

      return true;
    } catch (e) {
      debugPrint("Error banning user $userId: $e");
      return false;
    }
  }

  /// ปลดการระงับบัญชีผู้ใช้ และคืนสถานะสินค้ากลับมาขายตามปกติ
  static Future<bool> unbanUser({
    required String userId,
    String? adminUid,
  }) async {
    if (userId.isEmpty) return false;

    try {
      // 1. อัปเดตสถานะผู้ใช้กลับเป็น active
      await _db.collection(FirestoreCollections.users).doc(userId).update({
        'status': 'active',
        'banReason': FieldValue.delete(),
        'bannedUntil': FieldValue.delete(),
        'unbannedAt': FieldValue.serverTimestamp(),
        'unbannedBy': adminUid ?? 'Admin',
      });

      // 2. คืนสถานะสินค้าของผู้ขาย
      try {
        final productsQuery = await _db
            .collection(FirestoreCollections.products)
            .where('sellerId', isEqualTo: userId)
            .where('status', isEqualTo: 'suspended_by_admin')
            .get();

        if (productsQuery.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var doc in productsQuery.docs) {
            batch.update(doc.reference, {
              'status': 'active',
              'restoredAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
      } catch (prodErr) {
        debugPrint("Error restoring products for user $userId: $prodErr");
      }

      // 3. ส่งแจ้งเตือนการคืนสถานะ
      await NotificationService.sendNotification(
        userId: userId,
        title: "บัญชีของคุณได้รับการปลดระงับแล้ว 🎉",
        body: "คุณสามารถเข้าสู่ระบบและทำรายการบนแอปพลิเคชันได้ตามปกติ",
        type: 'system',
      );

      return true;
    } catch (e) {
      debugPrint("Error unbanning user $userId: $e");
      return false;
    }
  }

  /// ตรวจสอบการหมดอายุของการแบนชั่วคราว (Auto-Expiry)
  /// คืนค่า true หากได้รับการปลดแบนอัตโนมัติแล้ว
  static Future<bool> checkAndExpireBan({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    String status = userData['status'] ?? 'active';
    if (status != 'banned' && status != 'suspended') return false;

    dynamic bannedUntilRaw = userData['bannedUntil'];
    if (bannedUntilRaw is Timestamp) {
      DateTime expiryDate = bannedUntilRaw.toDate();
      if (DateTime.now().isAfter(expiryDate)) {
        debugPrint("Ban expired for user $userId, automatically unbanning...");
        await unbanUser(userId: userId, adminUid: 'System Auto-Expiry');
        return true;
      }
    }

    return false;
  }

  /// ซ่อนสินค้าที่ละเมิดกฎโดยไม่ต้องแบนทั้งบัญชี
  static Future<bool> hideProduct({
    required String productId,
    required String reason,
    String? adminUid,
  }) async {
    if (productId.isEmpty) return false;

    try {
      final doc = await _db.collection(FirestoreCollections.products).doc(productId).get();
      if (!doc.exists) return false;

      String sellerId = doc.data()?['sellerId'] ?? '';

      await _db.collection(FirestoreCollections.products).doc(productId).update({
        'status': 'hidden_by_admin',
        'hiddenReason': reason,
        'hiddenAt': FieldValue.serverTimestamp(),
        'hiddenBy': adminUid ?? 'Admin',
      });

      if (sellerId.isNotEmpty) {
        await NotificationService.sendNotification(
          userId: sellerId,
          title: "สินค้าถูกระงับการแสดงผล ⚠️",
          body: "สินค้าของคุณถูกระงับเนื่องจาก: $reason กรุณาตรวจสอบและแก้ไข",
          type: 'system',
        );
      }

      return true;
    } catch (e) {
      debugPrint("Error hiding product $productId: $e");
      return false;
    }
  }

  /// ส่งหนังสือเตือนอย่างเป็นทางการ (Official Warning)
  static Future<bool> sendWarning({
    required String userId,
    required String reason,
    String? adminUid,
  }) async {
    if (userId.isEmpty) return false;

    try {
      await _db.collection(FirestoreCollections.users).doc(userId).update({
        'strikeCount': FieldValue.increment(1),
        'lastWarningReason': reason,
        'lastWarningAt': FieldValue.serverTimestamp(),
        'lastWarningBy': adminUid ?? 'Admin',
      });

      await NotificationService.sendNotification(
        userId: userId,
        title: "⚠️ หนังสือแจ้งเตือนการปฏิบัติตามกฎ",
        body: "ทีมงานขอแจ้งเตือน: $reason โปรดปฏิบัติตามนโยบายเพื่อหลีกเลี่ยงการถูกระงับบัญชี",
        type: 'system',
      );

      return true;
    } catch (e) {
      debugPrint("Error sending warning to user $userId: $e");
      return false;
    }
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays >= 1) {
      return "${duration.inDays} วัน";
    } else if (duration.inHours >= 1) {
      return "${duration.inHours} ชั่วโมง";
    } else {
      return "${duration.inMinutes} นาที";
    }
  }
}
