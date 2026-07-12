import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/profile/login_history_screen.dart';

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
                    icon: CupertinoIcons.envelope,
                    title: "ยืนยันตัวตนด้วยอีเมล",
                    subtitle:
                        (FirebaseAuth.instance.currentUser?.emailVerified ??
                            false)
                        ? "ยืนยันอีเมลแล้ว"
                        : "แตะเพื่อส่งอีเมลยืนยัน",
                    iconColor:
                        (FirebaseAuth.instance.currentUser?.emailVerified ??
                            false)
                        ? Colors.green
                        : Colors.orange,
                    hasBorder: true,
                    onTap: () => _verifyEmail(),
                  ),
                  _buildMenuTile(
                    icon: CupertinoIcons.lock_shield,
                    title: "เปลี่ยนรหัสผ่าน",
                    subtitle: "ตั้งรหัสผ่านใหม่เพื่อความปลอดภัย",
                    onTap: () => _showChangePasswordDialog(),
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
                    icon: CupertinoIcons.clock,
                    title: "ประวัติการเข้าสู่ระบบ",
                    hasBorder: true,
                    onTap: () => Get.to(() => const LoginHistoryScreen()),
                  ),
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

  Future<void> _verifyEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await user.reload(); // Refresh current user state from Firebase
    if (user.emailVerified) {
      setState(() {});
      _showCustomSnackbar(
        "ยืนยันแล้ว",
        "อีเมลนี้ได้รับการยืนยันเรียบร้อยแล้ว",
        CupertinoIcons.check_mark_circled_solid,
        Colors.green,
      );
      return;
    }

    try {
      await user.sendEmailVerification();
      _showCustomSnackbar(
        "สำเร็จ",
        "ส่งอีเมลยืนยันตัวตนไปที่ ${user.email} แล้ว กรุณาตรวจสอบกล่องจดหมายของคุณ",
        CupertinoIcons.envelope_fill,
        AppTheme.primaryColor,
      );
    } catch (e) {
      _showCustomSnackbar(
        "ข้อผิดพลาด",
        "ไม่สามารถส่งอีเมลได้ กรุณาลองใหม่ในภายหลัง",
        CupertinoIcons.xmark_circle_fill,
        Colors.red,
      );
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.lock_shield_fill,
                      color: Colors.orange,
                      size: 50,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "เปลี่ยนรหัสผ่าน",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: oldPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "รหัสผ่านเดิม",
                        prefixIcon: const Icon(CupertinoIcons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'กรุณากรอกรหัสผ่านเดิม'
                          : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "รหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)",
                        prefixIcon: const Icon(CupertinoIcons.lock_rotation),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกรหัสผ่านใหม่';
                        }
                        if (value.length < 6) {
                          return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isLoading ? null : () => Get.back(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("ยกเลิก"),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      setStateDialog(() => isLoading = true);
                                      try {
                                        final user =
                                            FirebaseAuth.instance.currentUser;
                                        if (user != null) {
                                          final cred =
                                              EmailAuthProvider.credential(
                                                email: user.email!,
                                                password:
                                                    oldPasswordController.text,
                                              );
                                          await user
                                              .reauthenticateWithCredential(
                                                cred,
                                              );
                                          await user.updatePassword(
                                            newPasswordController.text,
                                          );

                                          Get.back();
                                          _showCustomSnackbar(
                                            "สำเร็จ",
                                            "เปลี่ยนรหัสผ่านเรียบร้อยแล้ว",
                                            CupertinoIcons
                                                .check_mark_circled_solid,
                                            AppTheme.primaryColor,
                                          );
                                        }
                                      } on FirebaseAuthException catch (e) {
                                        setStateDialog(() => isLoading = false);
                                        _showCustomSnackbar(
                                          "ข้อผิดพลาด",
                                          e.code == 'wrong-password'
                                              ? 'รหัสผ่านเดิมไม่ถูกต้อง'
                                              : (e.message ??
                                                    'เปลี่ยนรหัสผ่านไม่สำเร็จ'),
                                          CupertinoIcons.xmark_circle_fill,
                                          Colors.red,
                                        );
                                      } catch (e) {
                                        setStateDialog(() => isLoading = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "บันทึก",
                                    style: TextStyle(
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
        },
      ),
      barrierDismissible: false,
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool isLoading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color: Colors.red,
                    size: 50,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "ยืนยันการลบบัญชี",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "การกระทำนี้ไม่สามารถย้อนกลับได้ ข้อมูลทั้งหมดจะถูกลบ กรุณากรอกรหัสผ่านของคุณเพื่อยืนยัน",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "รหัสผ่าน",
                      prefixIcon: const Icon(CupertinoIcons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("ยกเลิก"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (passwordController.text.isEmpty) {
                                    _showCustomSnackbar(
                                      "ข้อผิดพลาด",
                                      "กรุณากรอกรหัสผ่าน",
                                      CupertinoIcons.xmark_circle_fill,
                                      Colors.red,
                                    );
                                    return;
                                  }
                                  setStateDialog(() => isLoading = true);
                                  await _deleteAccountData(
                                    passwordController.text,
                                  );
                                  if (context.mounted) {
                                    setStateDialog(() => isLoading = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "ลบถาวร",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _deleteAccountData(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      String uid = user.uid;

      // 2. Cascading Delete
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // a. Delete all products from this seller
      var productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: uid)
          .get();
      for (var doc in productsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // b. Delete store document (if exists)
      batch.delete(FirebaseFirestore.instance.collection('stores').doc(uid));

      // c. Delete user document
      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));

      await batch.commit();

      // 3. Delete from Firebase Auth
      await user.delete();

      Get.offAll(() => const HomeScreen());
      _showCustomSnackbar(
        "สำเร็จ",
        "ลบบัญชีเรียบร้อยแล้ว",
        CupertinoIcons.check_mark_circled_solid,
        Colors.black87,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showCustomSnackbar(
          "ข้อผิดพลาด",
          "รหัสผ่านไม่ถูกต้อง",
          CupertinoIcons.xmark_circle_fill,
          Colors.red,
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
