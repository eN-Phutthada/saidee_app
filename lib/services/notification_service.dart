import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/config/firestore_collections.dart';

class NotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final Map<String, int> _recentNotifications = {};
  static const int _dedupTtlMs = 8000;

  static bool isDuplicateNotification(String title, String body, {String? customId}) {
    int now = DateTime.now().millisecondsSinceEpoch;

    _recentNotifications.removeWhere((_, time) => now - time > _dedupTtlMs);

    String key = customId != null && customId.isNotEmpty
        ? customId
        : "${title.trim()}:${body.trim()}";

    if (_recentNotifications.containsKey(key)) {
      int lastTime = _recentNotifications[key]!;
      if (now - lastTime < _dedupTtlMs) {
        return true;
      }
    }

    _recentNotifications[key] = now;
    return false;
  }

  static Future<DocumentReference?> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? orderId,
    Map<String, dynamic>? extraData,
  }) async {
    if (userId.isEmpty) return null;

    try {
      return await _db
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.notifications)
          .add({
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
      return null;
    }
  }

  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    if (userId.isEmpty) {
      return const Stream.empty();
    }
    return _db
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.notifications)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<int> getUnreadCount(String userId) {
    if (userId.isEmpty) {
      return Stream.value(0);
    }
    return _db
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.notifications)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((error) {
          debugPrint("Error fetching unread count: $error");
          return 0;
        });
  }

  static Future<void> markAsRead(String userId, String notificationId) async {
    if (userId.isEmpty || notificationId.isEmpty) return;
    try {
      await _db
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.notifications)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    if (userId.isEmpty) return;
    try {
      var unreadDocs = await _db
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.notifications)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isEmpty) return;

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
