import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _lastNotificationKey = '';
  static int _lastNotificationTime = 0;

  /// ตรวจสอบว่าเป็นการแจ้งเตือนซ้ำภายในระยะเวลา 2 วินาทีหรือไม่
  static bool isDuplicateNotification(String title, String body) {
    String key = "$title:$body";
    int now = DateTime.now().millisecondsSinceEpoch;

    if (_lastNotificationKey == key && (now - _lastNotificationTime) < 2000) {
      return true; // ข้ามการยิงซ้ำซ้อน
    }

    _lastNotificationKey = key;
    _lastNotificationTime = now;
    return false;
  }

  /// ส่งการแจ้งเตือนไปยังผู้ใช้รายบุคคล (ทั้งผู้ซื้อและผู้ขาย)
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type, // 'order', 'wallet', 'dispute', 'system'
    String? orderId,
    Map<String, dynamic>? extraData,
  }) async {
    if (userId.isEmpty) return;

    try {
      await _db.collection('users').doc(userId).collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId ?? '',
        'extraData': extraData ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error sending notification to $userId: $e");
    }
  }

  /// อ่านการแจ้งเตือนทั้งหมดของผู้ใช้
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// อ่านจำนวนการแจ้งเตือนที่ยังไม่ได้อ่าน
  static Stream<int> getUnreadCount(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// ทำเครื่องหมายว่าอ่านแล้วสำหรับ 1 รายการ
  static Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  /// ทำเครื่องหมายว่าอ่านแล้วทั้งหมด
  static Future<void> markAllAsRead(String userId) async {
    try {
      var unreadDocs = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = _db.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
    }
  }
}
