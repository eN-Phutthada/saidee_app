import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/main.dart';
import 'package:saidee_app/services/role_guard_service.dart';

class AuthService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> signOut() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;

        try {
          await _db
              .collection(FirestoreCollections.users)
              .doc(uid)
              .update({
                'fcmToken': FieldValue.delete(),
                'lastLogout': FieldValue.serverTimestamp(),
              })
              .timeout(const Duration(seconds: 3));
          debugPrint("Removed FCM token from users/$uid");
        } catch (e) {
          debugPrint("Failed to remove FCM token from users/$uid: $e");
        }

        try {
          final adminDoc = await _db
              .collection(FirestoreCollections.admins)
              .doc(uid)
              .get()
              .timeout(const Duration(seconds: 2));
          if (adminDoc.exists) {
            await _db
                .collection(FirestoreCollections.admins)
                .doc(uid)
                .update({
                  'fcmToken': FieldValue.delete(),
                  'lastLogout': FieldValue.serverTimestamp(),
                })
                .timeout(const Duration(seconds: 2));
            debugPrint("Removed FCM token from admins/$uid");
          }
        } catch (e) {
          debugPrint("Failed to remove FCM token from admins/$uid: $e");
        }
      }

      try {
        await FirebaseMessaging.instance.deleteToken().timeout(
              const Duration(seconds: 3),
            );
        debugPrint("Successfully deleted FCM device token from device.");
      } catch (e) {
        debugPrint("Failed to delete FCM device token: $e");
      }

      try {
        await flutterLocalNotificationsPlugin.cancelAll();
        debugPrint("Cancelled all local notifications from tray.");
      } catch (e) {
        debugPrint("Failed to cancel local notifications: $e");
      }
    } catch (e) {
      debugPrint("Error during signOut cleanup: $e");
    } finally {
      RoleGuardService.clearCache();
      await _auth.signOut();
      debugPrint("User successfully signed out from FirebaseAuth.");
    }
  }
}
