import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class AccountSecurityScreen extends StatefulWidget {
  final String email;

  const AccountSecurityScreen({super.key, required this.email});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "ความปลอดภัยบัญชี",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("การเข้าสู่ระบบ"),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: CupertinoIcons.lock_shield,
                    title: "เปลี่ยนรหัสผ่าน",
                    subtitle: "ส่งลิงก์รีเซ็ตไปที่อีเมลของคุณ",
                    onTap: () => _showPasswordResetDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            _buildSectionHeader("การจัดการบัญชี"),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: CupertinoIcons.trash,
                    iconColor: Colors.red,
                    title: "ลบบัญชีผู้ใช้",
                    titleColor: Colors.red,
                    onTap: () => _showDeleteAccountDialog(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordResetDialog() {
    AppDialog.showCustomDialog(
      title: "รีเซ็ตรหัสผ่าน",
      message: "เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปที่:\n${widget.email}",
      icon: CupertinoIcons.lock_shield_fill,
      iconColor: Colors.orange,
      confirmText: "ส่งลิงก์",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();

        if (widget.email.isEmpty) {
          _showCustomSnackbar(
            "เกิดข้อผิดพลาด",
            "ไม่พบอีเมลผู้ใช้",
            CupertinoIcons.xmark_circle_fill,
            Colors.red,
          );
          return;
        }
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(
            email: widget.email,
          );
          _showCustomSnackbar(
            "สำเร็จ",
            "ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว",
            CupertinoIcons.check_mark_circled_solid,
            AppTheme.primaryColor,
          );
        } catch (e) {
          _showCustomSnackbar(
            "ผิดพลาด",
            "ไม่สามารถส่งอีเมลได้",
            CupertinoIcons.xmark_circle_fill,
            Colors.red,
          );
        }
      },
    );
  }

  void _showDeleteAccountDialog() {
    AppDialog.showCustomDialog(
      title: "ยืนยันการลบบัญชี",
      message:
          "การกระทำนี้ไม่สามารถย้อนกลับได้ ข้อมูลร้านค้า สินค้า และยอดเงินในวอลเล็ทของคุณจะถูกลบทั้งหมด",
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      iconColor: Colors.red,
      confirmText: "ลบถาวร",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();

        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // ลบข้อมูลผู้ใช้จาก Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .delete();
            // ลบบัญชีผู้ใช้ออกจาก Firebase Auth
            await user.delete();

            Get.offAll(() => const HomeScreen());
            _showCustomSnackbar(
              "สำเร็จ",
              "ลบบัญชีเรียบร้อยแล้ว",
              CupertinoIcons.check_mark_circled_solid,
              Colors.black87,
            );
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            _showCustomSnackbar(
              "ข้อผิดพลาด",
              "เพื่อความปลอดภัย กรุณาเข้าสู่ระบบใหม่อีกครั้งก่อนลบบัญชี",
              CupertinoIcons.info_circle_fill,
              Colors.orange,
            );
          } else {
            _showCustomSnackbar(
              "ข้อผิดพลาด",
              e.message ?? "ไม่สามารถลบบัญชีได้",
              CupertinoIcons.xmark_circle_fill,
              Colors.red,
            );
          }
        } catch (e) {
          _showCustomSnackbar(
            "ข้อผิดพลาด",
            "เกิดข้อผิดพลาดในการลบบัญชี",
            CupertinoIcons.xmark_circle_fill,
            Colors.red,
          );
        }
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    bool hasBorder = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget tile = Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          size: 24,
          color: iconColor ?? AppTheme.primaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: titleColor ?? theme.colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              )
            : null,
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );

    if (hasBorder) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.1),
            ),
          ),
        ),
        child: tile,
      );
    }
    return tile;
  }

  void _showCustomSnackbar(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    Get.snackbar(
      title,
      message,
      icon: Icon(icon, color: Colors.white, size: 28),
      snackPosition: SnackPosition.TOP,
      backgroundColor: color.withOpacity(0.9),
      colorText: Colors.white,
      borderRadius: 16,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      duration: const Duration(seconds: 3),
      boxShadows: [
        BoxShadow(
          color: color.withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}
