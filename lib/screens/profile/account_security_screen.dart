import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
// import 'package:saidee_app/screens/home/home_screen.dart';

class AccountSecurityScreen extends StatefulWidget {
  final String email;

  const AccountSecurityScreen({super.key, required this.email});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _useBiometrics = false; // จำลองสถานะการเปิดใช้ FaceID/TouchID

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
                    onTap: () => _showPasswordResetDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            _buildSectionHeader("ความปลอดภัยกระเป๋าเงิน (Wallet)"),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: CupertinoIcons.number_square,
                    title: "รหัส PIN การชำระเงิน",
                    subtitle: "ตั้งค่าหรือเปลี่ยนรหัส 6 หลัก",
                    onTap: () {
                      // TODO: ทำหน้าตั้งรหัส PIN ทีหลัง
                      _showCustomSnackbar(
                        "เร็วๆ นี้",
                        "ระบบรหัส PIN กำลังพัฒนา",
                        CupertinoIcons.info_circle_fill,
                        Colors.blue,
                      );
                    },
                    hasBorder: true,
                  ),
                  ListTile(
                    leading: const Icon(
                      CupertinoIcons.square_on_square,
                      size: 24,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text(
                      "สแกนใบหน้า / ลายนิ้วมือ",
                      style: TextStyle(fontSize: 15),
                    ),
                    subtitle: Text(
                      "ใช้ยืนยันการชำระเงิน",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    trailing: Switch(
                      value: _useBiometrics,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) => setState(() => _useBiometrics = val),
                    ),
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
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordResetDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.lock_shield_fill,
                  color: Colors.orange,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "รีเซ็ตรหัสผ่าน",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปที่:\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "ยกเลิก",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ส่งลิงก์",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "ยืนยันการลบบัญชี",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "การกระทำนี้ไม่สามารถย้อนกลับได้ ข้อมูลร้านค้า สินค้า และยอดเงินในวอลเล็ทของคุณจะถูกลบทั้งหมด",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "ยกเลิก",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // TODO: ใส่ Logic ลบข้อมูลใน Firestore ก่อนลบ Auth ในภายหลัง
                        // try {
                        //   await FirebaseAuth.instance.currentUser?.delete();
                        //   Get.offAll(() => const HomeScreen());
                        //   _showCustomSnackbar(
                        //     "สำเร็จ",
                        //     "ลบบัญชีเรียบร้อยแล้ว",
                        //     CupertinoIcons.check_mark_circled_solid,
                        //     Colors.black87,
                        //   );
                        // } catch (e) {
                        //   Get.back();
                        //   _showCustomSnackbar(
                        //     "ข้อผิดพลาด",
                        //     "กรุณาเข้าสู่ระบบใหม่อีกครั้งก่อนทำการลบบัญชี",
                        //     CupertinoIcons.info_circle_fill,
                        //     Colors.orange,
                        //   );
                        // }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ลบถาวร",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

    Widget tile = ListTile(
      leading: Icon(icon, size: 24, color: iconColor ?? AppTheme.primaryColor),
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
