import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/services/notification_service.dart';

class EscrowService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _isChecking = false;

  static const int autoReleaseDays = 7;

  static Future<int> checkAndAutoCompleteOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    if (_isChecking) return 0;

    _isChecking = true;
    int completedCount = 0;

    try {
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
        var snap = await _db
            .collection(FirestoreCollections.orders)
            .where('status', isEqualTo: 'shipping')
            .get();
        candidates.addAll(snap.docs);
      } else {
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

  static Future<bool> _processOrderReleaseIfDue({
    required String orderId,
    required Map<String, dynamic> orderData,
    required DocumentReference orderRef,
    required DateTime now,
  }) async {
    String status = orderData['status'] ?? '';
    if (status != 'shipping') return false;

    bool isDisputed = orderData['isDisputed'] == true || status == 'disputed';
    if (isDisputed) return false;

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

      batch.update(orderRef, {
        'status': 'completed',
        'escrowStatus': 'released',
        'escrowReleasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'autoCompleted': true,
      });

      DocumentReference sellerRef =
          _db.collection(FirestoreCollections.users).doc(sellerId);
      batch.update(sellerRef, {
        'walletBalance': FieldValue.increment(totalAmount),
      });

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

      NotificationService.sendNotification(
        userId: sellerId,
        title: "ได้รับโอนเงินคำสั่งซื้ออัตโนมัติ 💰",
        body:
            "คำสั่งซื้อครบกำหนด 7 วันแล้ว ยอดเงิน ${totalAmount.toStringAsFixed(2)} ฿ ถูกโอนเข้า SAIDEE Wallet เรียบร้อยแล้ว",
        type: 'wallet',
        orderId: orderId,
      );

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
