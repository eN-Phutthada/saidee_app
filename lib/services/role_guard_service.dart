import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/screens/admin/admin_dashboard.dart';
import 'package:saidee_app/screens/error/permission_denied_screen.dart';
import 'package:saidee_app/config/firestore_collections.dart';

class RoleGuardService {
  static final Map<String, bool> _adminCache = {};
  static final Map<String, int> _cacheTimestamps = {};
  static const int _cacheTtlMs = 60000;

  static void clearCache() {
    _adminCache.clear();
    _cacheTimestamps.clear();
  }

  static Future<bool> isUserIdAdmin(String uid) async {
    if (uid.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_adminCache.containsKey(uid) &&
        (now - (_cacheTimestamps[uid] ?? 0) < _cacheTtlMs)) {
      return _adminCache[uid]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.admins)
          .doc(uid)
          .get();
      final exists = doc.exists;
      _adminCache[uid] = exists;
      _cacheTimestamps[uid] = now;
      return exists;
    } catch (e) {
      debugPrint("Error checking admin status by uid: $e");
      return false;
    }
  }

  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      return await isUserIdAdmin(user.uid);
    } catch (e) {
      debugPrint("Error checking admin status: $e");
      return false;
    }
  }

  static Future<bool> checkAdminAccess(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        _denyAccessAndRedirect("กรุณาเข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบก่อนใช้งานส่วนนี้");
        return false;
      }

      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        _denyAccessAndRedirect("คุณไม่มีสิทธิ์เข้าถึงส่วนผู้ดูแลระบบ (Admin Only)\nบัญชีของคุณไม่มีสิทธิ์ในการเข้าถึงข้อมูลส่วนนี้");
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Error checking admin access: $e");
      return false;
    }
  }

  static Future<bool> redirectIfAdmin([BuildContext? context]) async {
    try {
      final isAdmin = await isCurrentUserAdmin();
      if (isAdmin) {
        debugPrint("[RoleGuard] Admin detected on user-facing screen. Redirecting to AdminDashboard.");
        Get.offAll(() => const AdminDashboard());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error redirecting admin: $e");
      return false;
    }
  }

  static void _denyAccessAndRedirect(String message) {
    Get.off(
      () => PermissionDeniedScreen(
        title: "สิทธิ์การเข้าถึงไม่เพียงพอ",
        message: message,
        technicalDetails:
            "[cloud_firestore/permission-denied] PERMISSION_DENIED: Missing or insufficient permissions.",
      ),
    );
  }
}
