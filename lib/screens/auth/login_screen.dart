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
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          String status = userData['status'] ?? 'active';

          if (status == 'suspended') {
            await FirebaseAuth.instance.signOut();

            _showCustomSnackbar(
              title: "บัญชีถูกระงับ",
              message:
                  "บัญชีของคุณถูกระงับการใช้งานเนื่องจากละเมิดกฎของระบบ กรุณาติดต่อแอดมิน",
              icon: CupertinoIcons.nosign,
              backgroundColor: Colors.red[800]!,
            );

            setState(() => _isLoading = false);
            return;
          }
        }

        DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();

        if (adminDoc.exists) {
          _showCustomSnackbar(
            title: "ยินดีต้อนรับ",
            message: "เข้าสู่ระบบ Admin เรียบร้อยแล้ว",
            icon: CupertinoIcons.shield_lefthalf_fill,
            backgroundColor: Colors.blueAccent,
          );
          Get.offAll(() => const AdminDashboard());
        } else {
          _showCustomSnackbar(
            title: "สำเร็จ",
            message: "เข้าสู่ระบบเรียบร้อยแล้ว",
            icon: CupertinoIcons.checkmark_alt_circle_fill,
            backgroundColor: AppTheme.primaryColor,
          );
          Get.offAll(() => const HomeScreen());
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "เกิดข้อผิดพลาดในการเข้าสู่ระบบ กรุณาลองใหม่อีกครั้ง";
      switch (e.code) {
        case 'user-not-found':
          message = 'ไม่พบผู้ใช้งานนี้ กรุณาตรวจสอบอีเมลหรือลงทะเบียนใหม่';
          break;
        case 'wrong-password':
          message = 'รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง';
          break;
        case 'invalid-credential':
          message = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
          break;
        case 'invalid-email':
          message = 'รูปแบบอีเมลไม่ถูกต้อง (เช่น ขาด @)';
          break;
        case 'user-disabled':
          message = 'บัญชีผู้ใช้นี้ถูกระงับการใช้งานโดยผู้ดูแลระบบ';
          break;
        case 'too-many-requests':
          message =
              'เข้าสู่ระบบผิดพลาดหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
          break;
        case 'operation-not-allowed':
          message = 'ระบบยังไม่เปิดใช้งานการเข้าสู่ระบบด้วยวิธีนี้';
          break;
        case 'network-request-failed':
          message = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
          break;
        default:
          message = e.message ?? message;
      }

      _showCustomSnackbar(
        title: "เข้าสู่ระบบไม่สำเร็จ",
        message: message,
        icon: CupertinoIcons.exclamationmark_circle_fill,
        backgroundColor: AppTheme.errorColor,
      );
    } catch (e) {
      _showCustomSnackbar(
        title: "Error",
        message: e.toString(),
        icon: CupertinoIcons.xmark_circle_fill,
        backgroundColor: Colors.red[800]!,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomSnackbar({
    required String title,
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    Get.snackbar(
      title,
      message,
      icon: Icon(icon, color: Colors.white, size: 28),
      snackPosition: SnackPosition.TOP,
      backgroundColor: backgroundColor.withOpacity(0.9),
      colorText: Colors.white,
      borderRadius: 16,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      duration: const Duration(seconds: 3),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      barBlur: 20,
      boxShadows: [
        BoxShadow(
          color: backgroundColor.withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _buildBgCircle(isDark, top: -100, right: -100, size: 300),

          _buildBgCircle(
            isDark,
            bottom: -80,
            left: -80,
            size: 250,
            opacityFactor: 0.8,
          ),

          _buildBgCircle(
            isDark,
            top: size.height * 0.15,
            left: -100,
            size: 200,
            opacityFactor: 0.6,
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 80,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                CupertinoIcons.cube_box_fill,
                                size: 80,
                                color: AppTheme.primaryColor,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          "ยินดีต้อนรับกลับมา!",
                          style: TextStyle(
                            fontSize: 26,
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
                                color: Colors.black.withOpacity(
                                  isDark ? 0.2 : 0.05,
                                ),
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
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 5,
                                    shadowColor: AppTheme.primaryColor
                                        .withOpacity(0.4),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _isLoading
                                        ? const SizedBox(
                                            key: ValueKey('loading'),
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : const Text(
                                            "เข้าสู่ระบบ",
                                            key: ValueKey('text'),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                            _buildDebugBtn(
                              "User 3",
                              CupertinoIcons.person,
                              Colors.blueGrey,
                              () {
                                _emailController.text = "test02@gmail.com";
                                _passwordController.text = "123456";
                                _login();
                              },
                            ),
                            _buildDebugBtn(
                              "User 4",
                              CupertinoIcons.person,
                              Colors.blueGrey,
                              () {
                                _emailController.text = "test03@gmail.com";
                                _passwordController.text = "123456";
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

  Widget _buildBgCircle(
    bool isDark, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    double opacityFactor = 1.0,
  }) {
    final baseOpacity = isDark ? 0.05 : 0.08;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(baseOpacity * opacityFactor),
          shape: BoxShape.circle,
        ),
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
          borderRadius: BorderRadius.circular(12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
