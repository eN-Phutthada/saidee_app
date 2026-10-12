import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/services/notification_service.dart';

/// บริการจัดการ Saidee Escrow Guarantee และการโอนเงินอัตโนมัติเมื่อครบ 7 วัน
class EscrowService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _isChecking = false;

  /// จำนวนวันที่ระบบจะโอนเงินให้อัตโนมัติหลังจัดส่งหากผู้ซื้อไม่กดยืนยัน (7 วัน)
  static const int autoReleaseDays = 7;

  /// ตรวจสอบและโอนเงินคำสั่งซื้อที่ครบกำหนด 7 วันอัตโนมัติ
  /// ทำงานแบบ Background/Service ให้ทั้งระบบโดยที่ผู้ซื้อหรือผู้ขายไม่ต้องคอยเข้าไปเช็คหน้าคำสั่งซื้อ
  static Future<int> checkAndAutoCompleteOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    if (_isChecking) return 0;

    _isChecking = true;
    int completedCount = 0;

    try {
      // ตรวจสอบว่าผู้ใช้ปัจจุบันเป็น Admin หรือไม่
      bool isAdmin = false;
      try {
        final adminDoc = await _db
            .collection(FirestoreCollections.admins)
            .doc(user.uid)
            .get();
        isAdmin = adminDoc.exists;
      } catch (_) {
        isAdmin = false;
      }

      List<DocumentSnapshot> candidates = [];

      if (isAdmin) {
        // แอดมินสามารถดึงคำสั่งซื้อสถานะจัดส่งทั้งหมดในระบบมาตรวจสอบ
        var snap = await _db
            .collection(FirestoreCollections.orders)
            .where('status', isEqualTo: 'shipping')
            .get();
        candidates.addAll(snap.docs);
      } else {
        // ผู้ใช้ทั่วไป: ตรวจสอบทั้งคำสั่งซื้อที่ตนเองเป็นผู้ขาย และที่ตนเองเป็นผู้ซื้อ
        var sellerSnap = await _db
            .collection(FirestoreCollections.orders)
            .where('sellerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'shipping')
            .get();
        candidates.addAll(sellerSnap.docs);

        var buyerSnap = await _db
            .collection(FirestoreCollections.orders)
            .where('buyerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'shipping')
            .get();

        final existingIds = candidates.map((d) => d.id).toSet();
        for (var doc in buyerSnap.docs) {
          if (!existingIds.contains(doc.id)) {
            candidates.add(doc);
          }
        }
      }

      final now = DateTime.now();

      for (var doc in candidates) {
        var data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        bool success = await _processOrderReleaseIfDue(
          orderId: doc.id,
          orderData: data,
          orderRef: doc.reference,
          now: now,
        );

        if (success) {
          completedCount++;
        }
      }
    } catch (e) {
      debugPrint("Error in EscrowService.checkAndAutoCompleteOrders: $e");
    } finally {
      _isChecking = false;
    }

    return completedCount;
  }

  /// ตรวจสอบและโอนเงินสำหรับออเดอร์เดี่ยวทันที (เช่น เมื่อผู้ใช้เปิดดูรายละเอียดออเดอร์)
  static Future<bool> checkAndAutoCompleteSingleOrder({
    required String orderId,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      final docRef = _db.collection(FirestoreCollections.orders).doc(orderId);
      return await _processOrderReleaseIfDue(
        orderId: orderId,
        orderData: orderData,
        orderRef: docRef,
        now: DateTime.now(),
      );
    } catch (e) {
      debugPrint("Error in EscrowService.checkAndAutoCompleteSingleOrder: $e");
      return false;
    }
  }

  /// ประมวลผลการตรวจสอบเงื่อนไขเวลา 7 วันและการโอนเงิน
  static Future<bool> _processOrderReleaseIfDue({
    required String orderId,
    required Map<String, dynamic> orderData,
    required DocumentReference orderRef,
    required DateTime now,
  }) async {
    // 1. สถานะต้องเป็น 'shipping' เท่านั้น
    String status = orderData['status'] ?? '';
    if (status != 'shipping') return false;

    // 2. หากมีข้อพิพาท ระงับการปล่อยเงินทันทีตามนโยบาย Saidee Guarantee
    bool isDisputed = orderData['isDisputed'] == true || status == 'disputed';
    if (isDisputed) return false;

    // 3. ตรวจสอบเวลาจัดส่ง (shippedAt โดยมี fallback เป็น updatedAt หรือ createdAt)
    Timestamp? ts = orderData['shippedAt'] ??
        orderData['updatedAt'] ??
        orderData['createdAt'];
    if (ts == null) return false;

    DateTime shippedDate = ts.toDate();
    final diff = now.difference(shippedDate);
    if (diff.inDays < autoReleaseDays) return false;

    try {
      double totalAmount =
          (orderData['total'] ?? orderData['grandTotal'] ?? 0).toDouble();
      String sellerId = orderData['sellerId'] ?? '';
      String buyerId = orderData['buyerId'] ?? '';

      if (sellerId.isEmpty) return false;

      WriteBatch batch = _db.batch();

      // อัปเดตสถานะคำสั่งซื้อเป็นเสร็จสิ้น และปล่อยเงิน Escrow
      batch.update(orderRef, {
        'status': 'completed',
        'escrowStatus': 'released',
        'escrowReleasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'autoCompleted': true,
      });

      // โอนเงินเข้ากระเป๋า SAIDEE Wallet ของผู้ขาย
      DocumentReference sellerRef =
          _db.collection(FirestoreCollections.users).doc(sellerId);
      batch.update(sellerRef, {
        'walletBalance': FieldValue.increment(totalAmount),
      });

      // บันทึกประวัติธุรกรรมทางการเงิน
      DocumentReference txRef =
          _db.collection(FirestoreCollections.transactions).doc();
      batch.set(txRef, {
        'uid': sellerId,
        'type': 'income',
        'amount': totalAmount,
        'order_id': orderId,
        'status': 'success',
        'note': 'โอนเงินอัตโนมัติ (ครบกำหนด 7 วันหลังจัดส่ง)',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // ส่งแจ้งเตือนผู้ขาย
      NotificationService.sendNotification(
        userId: sellerId,
        title: "ได้รับโอนเงินคำสั่งซื้ออัตโนมัติ 💰",
        body:
            "คำสั่งซื้อครบกำหนด 7 วันแล้ว ยอดเงิน ${totalAmount.toStringAsFixed(2)} ฿ ถูกโอนเข้า SAIDEE Wallet เรียบร้อยแล้ว",
        type: 'wallet',
        orderId: orderId,
      );

      // ส่งแจ้งเตือนผู้ซื้อ
      if (buyerId.isNotEmpty) {
        NotificationService.sendNotification(
          userId: buyerId,
          title: "คำสั่งซื้อเสร็จสมบูรณ์อัตโนมัติ ✨",
          body:
              "คำสั่งซื้อครบกำหนด 7 วันหลังจากจัดส่ง ระบบได้ทำการยืนยันการรับสินค้าและปล่อยยอดเงินให้ผู้ขายเรียบร้อยแล้ว",
          type: 'order',
          orderId: orderId,
        );
      }

      debugPrint("Auto-completed order successfully: $orderId");
      return true;
    } catch (e) {
      debugPrint("Error processing auto-complete for order $orderId: $e");
      return false;
    }
  }
}
