import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/main.dart';

/// บริการจัดการด้านการยืนยันตัวตนและการออกจากระบบอย่างปลอดภัย
class AuthService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ออกจากระบบอย่างสมบูรณ์ พร้อมตัดการเชื่อมต่อ FCM Token และล้างการแจ้งเตือน
  static Future<void> signOut() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;

        // 1. ลบ FCM Token จากคอลเลกชัน users ใน Firestore
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

        // 2. ลบ FCM Token จากคอลเลกชัน admins ใน Firestore (ถ้ามี)
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

      // 3. ทำลาย Device FCM Token บนเครื่อง เพื่อป้องกันไม่ให้รับ Push Notification ของผู้ใช้เดิมอีก
      try {
        await FirebaseMessaging.instance.deleteToken().timeout(
              const Duration(seconds: 3),
            );
        debugPrint("Successfully deleted FCM device token from device.");
      } catch (e) {
        debugPrint("Failed to delete FCM device token: $e");
      }

      // 4. ล้างการแจ้งเตือน Local Notifications ทั้งหมดที่อาจค้างอยู่ใน Notification Tray
      try {
        await flutterLocalNotificationsPlugin.cancelAll();
        debugPrint("Cancelled all local notifications from tray.");
      } catch (e) {
        debugPrint("Failed to cancel local notifications: $e");
      }
    } catch (e) {
      debugPrint("Error during signOut cleanup: $e");
    } finally {
      // 5. ออกจากระบบ Firebase Authentication
      await _auth.signOut();
      debugPrint("User successfully signed out from FirebaseAuth.");
    }
  }
}
