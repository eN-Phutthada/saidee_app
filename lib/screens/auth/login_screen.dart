import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/register_screen.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/admin/admin_dashboard.dart';

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
            "ยินดีต้อนรับ",
            "เข้าสู่ระบบ Admin เรียบร้อยแล้ว",
            backgroundColor: Colors.blueAccent,
            colorText: Colors.white,
          );
          Get.offAll(() => const AdminDashboard());
        } else {
          Get.snackbar(
            "สำเร็จ",
            "เข้าสู่ระบบเรียบร้อยแล้ว",
            backgroundColor: AppTheme.primaryColor,
            colorText: Colors.white,
          );
          Get.offAll(() => const HomeScreen());
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "เกิดข้อผิดพลาดในการเข้าสู่ระบบ";
      if (e.code == 'user-not-found')
        message = 'ไม่พบผู้ใช้งานนี้ กรุณาลงทะเบียน';
      else if (e.code == 'wrong-password')
        message = 'รหัสผ่านไม่ถูกต้อง';
      else if (e.code == 'invalid-email')
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      else
        message = e.message ?? message;

      Get.snackbar(
        "เข้าสู่ระบบไม่สำเร็จ",
        message,
        backgroundColor: AppTheme.errorColor.withOpacity(0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.black, Colors.grey[900]!]
                    : [AppTheme.primaryColor.withOpacity(0.1), Colors.white],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              CupertinoIcons.cube_box_fill,
                              size: 100,
                              color: AppTheme.primaryColor,
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        Text(
                          "ยินดีต้อนรับกลับมา!",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "เข้าสู่ระบบเพื่อเริ่มช็อปและขายเสื้อผ้าของคุณ",
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 40),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildInputField(
                                controller: _emailController,
                                label: "อีเมล",
                                icon: CupertinoIcons.mail_solid,
                                keyboardType: TextInputType.emailAddress,
                                isDark: isDark,
                                validator: (val) => (val == null || val.isEmpty)
                                    ? 'กรุณากรอกอีเมล'
                                    : null,
                              ),
                              const SizedBox(height: 15),
                              _buildInputField(
                                controller: _passwordController,
                                label: "รหัสผ่าน",
                                icon: CupertinoIcons.lock_fill,
                                isPassword: true,
                                isDark: isDark,
                                obscureText: _hidePassword,
                                onToggleVisibility: _togglePasswordVisibility,
                                validator: (val) => (val == null || val.isEmpty)
                                    ? 'กรุณากรอกรหัสผ่าน'
                                    : null,
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {}, // TODO: ลืมรหัสผ่าน
                                  child: Text(
                                    "ลืมรหัสผ่าน?",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text(
                                          "เข้าสู่ระบบ",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "คุณยังไม่มีบัญชีใช่ไหม? ",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Get.to(() => const RegisterScreen()),
                              child: const Text(
                                "ลงทะเบียนเลย",
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // --- DEBUG SECTION ---
                        const Divider(),
                        const Text(
                          "DEBUG MODE (Login ด่วน)",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildDebugBtn(
                              "Admin",
                              CupertinoIcons.at_badge_minus,
                              Colors.black87,
                              () {
                                _emailController.text = "admin@saidee.com";
                                _passwordController.text = "password1234";
                                _login();
                              },
                            ),
                            _buildDebugBtn(
                              "User 1",
                              CupertinoIcons.person,
                              Colors.blueGrey,
                              () {
                                _emailController.text = "saidee@gmail.com";
                                _passwordController.text = "123456";
                                _login();
                              },
                            ),
                            _buildDebugBtn(
                              "User 2",
                              CupertinoIcons.person,
                              Colors.blueGrey,
                              () {
                                _emailController.text = "saidee2@gmail.com";
                                _passwordController.text = "12345678";
                                _login();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? CupertinoIcons.eye_slash_fill
                      : CupertinoIcons.eye_fill,
                  color: Colors.grey,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildDebugBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      ),
    );
  }
}
