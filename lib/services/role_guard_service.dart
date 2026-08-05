import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class RoleGuardService {
  /// Check if the currently logged in user is an Admin
  static Future<bool> isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint("Error checking admin status: $e");
      return false;
    }
  }

  /// Protect Admin screens: If non-admin user attempts access, kick them out to HomeScreen
  static Future<bool> checkAdminAccess(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _denyAccessAndRedirect("กรุณาเข้าสู่ระบบก่อนใช้งานส่วนผู้ดูแลระบบ");
      return false;
    }

    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) {
      _denyAccessAndRedirect("คุณไม่มีสิทธิ์เข้าถึงส่วนผู้ดูแลระบบ (Admin Only)");
      return false;
    }

    return true;
  }

  static void _denyAccessAndRedirect(String message) {
    Get.offAll(() => const HomeScreen());
    AppDialog.showCustomDialog(
      title: "ปฏิเสธการเข้าถึง",
      message: message,
      icon: CupertinoIcons.lock_shield_fill,
      iconColor: Colors.red,
      confirmText: "ตกลง",
      onConfirm: () => Get.back(),
    );
  }
}
