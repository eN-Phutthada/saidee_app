import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/register_screen.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/admin/admin_dashboard.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _hidePassword = !_hidePassword;
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      User? user = userCredential.user;
      if (user != null) {
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();

        if (adminDoc.exists) {
          Get.snackbar(
            "ยินดีต้อนรับผู้ดูแลระบบ",
            "เข้าสู่ระบบ Admin เรียบร้อยแล้ว",
            backgroundColor: Colors.blueAccent.withOpacity(0.9),
            colorText: Colors.white,
          );
          Get.offAll(() => const AdminDashboard());
        } else {
          Get.snackbar(
            "สำเร็จ",
            "เข้าสู่ระบบเรียบร้อยแล้ว",
            backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
            colorText: Colors.white,
          );
          Get.offAll(() => const HomeScreen());
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "เกิดข้อผิดพลาดในการเข้าสู่ระบบ";
      if (e.code == 'user-not-found') {
        message = 'ไม่พบผู้ใช้งานนี้ กรุณาลงทะเบียน';
      } else if (e.code == 'wrong-password') {
        message = 'รหัสผ่านไม่ถูกต้อง';
      } else if (e.code == 'invalid-email') {
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else {
        message = e.message ?? message;
      }

      Get.snackbar(
        "เข้าสู่ระบบไม่สำเร็จ",
        message,
        backgroundColor: AppTheme.errorColor.withOpacity(0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const TopGreenShape(),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppLogo(size: 100),
                    ),
                    const SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "เข้าสู่ระบบ",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    CustomTextField(
                      label: "อีเมล",
                      inputType: TextInputType.emailAddress,
                      controller: _emailController,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'กรุณากรอกอีเมล'
                          : null,
                    ),

                    CustomTextField(
                      label: "รหัสผ่าน",
                      isPassword: true,
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      onToggleVisibility: _togglePasswordVisibility,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'กรุณากรอกรหัสผ่าน'
                          : null,
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : const Text("เข้าสู่ระบบ"),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "คุณยังไม่มีบัญชี? ",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text(
                            "ลงทะเบียน",
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- DEBUG SECTION (ลบออกเมื่อขึ้น Production) ---
                    const Divider(),
                    const Text(
                      "DEBUG MODE (Login ด่วน)",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ปุ่ม Login Admin
                        ElevatedButton.icon(
                          onPressed: () {
                            _emailController.text =
                                "admin@saidee.com"; // อีเมล Admin ที่สร้างไว้
                            _passwordController.text = "password1234";
                            _login(); // เรียกฟังก์ชัน Login เดิม
                          },
                          icon: const Icon(
                            CupertinoIcons.at_badge_minus,
                            size: 18,
                          ),
                          label: const Text("Admin"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),

                        ElevatedButton.icon(
                          onPressed: () {
                            _emailController.text =
                                "saidee@gmail.com"; // อีเมล User ตามตัวอย่างในเอกสาร
                            _passwordController.text = "123456";
                            _login();
                          },
                          icon: const Icon(CupertinoIcons.person, size: 18),
                          label: const Text("User"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
