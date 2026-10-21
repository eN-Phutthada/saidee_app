import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/config/firestore_collections.dart';

class NotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Map<String, dynamic>? pendingNotificationData;

  static final Map<String, int> _recentNotifications = {};
  static const int _dedupTtlMs = 8000;

  static final Map<String, int> _handledNotificationIds = {};
  static const int _handledTtlMs = 30000;

  static void markNotificationAsHandled(String id) {
    if (id.isEmpty) return;
    int now = DateTime.now().millisecondsSinceEpoch;
    _handledNotificationIds.removeWhere(
      (_, time) => now - time > _handledTtlMs,
    );
    _handledNotificationIds[id] = now;
  }

  static bool wasNotificationRecentlyHandled(String id) {
    if (id.isEmpty) return false;
    int now = DateTime.now().millisecondsSinceEpoch;
    int? time = _handledNotificationIds[id];
    if (time != null && (now - time < _handledTtlMs)) {
      return true;
    }
    return false;
  }

  static bool isDuplicateNotification(
    String title,
    String body, {
    String? customId,
  }) {
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
      final docRef = await _db
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

      try {
        final adminDoc = await _db
            .collection(FirestoreCollections.admins)
            .doc(userId)
            .get();
        if (adminDoc.exists) {
          await _db
              .collection(FirestoreCollections.admins)
              .doc(userId)
              .collection(FirestoreCollections.notifications)
              .doc(docRef.id)
              .set({
                'title': title,
                'body': body,
                'type': type,
                'orderId': orderId ?? '',
                'extraData': extraData ?? {},
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      } catch (_) {}

      return docRef;
    } catch (e) {
      debugPrint("Error sending notification to $userId: $e");
      return null;
    }
  }

  static Future<void> notifyAllAdmins({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final adminDocs = await _db.collection(FirestoreCollections.admins).get();
      for (var admin in adminDocs.docs) {
        await sendNotification(
          userId: admin.id,
          title: title,
          body: body,
          type: type,
          extraData: extraData,
        );
      }
    } catch (e) {
      debugPrint("Error notifying all admins: $e");
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
      debugPrint("Error marking notification as read in users: $e");
    }

    try {
      await _db
          .collection(FirestoreCollections.admins)
          .doc(userId)
          .collection(FirestoreCollections.notifications)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (_) {}
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

      if (unreadDocs.docs.isNotEmpty) {
        WriteBatch batch = _db.batch();
        for (var doc in unreadDocs.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error marking all notifications as read in users: $e");
    }

    try {
      var adminUnreadDocs = await _db
          .collection(FirestoreCollections.admins)
          .doc(userId)
          .collection(FirestoreCollections.notifications)
          .where('isRead', isEqualTo: false)
          .get();

      if (adminUnreadDocs.docs.isNotEmpty) {
        WriteBatch batch = _db.batch();
        for (var doc in adminUnreadDocs.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (_) {}
  }
}
