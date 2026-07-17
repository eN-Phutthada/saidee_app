import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  void _showBannedPopup() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.nosign,
                  color: Colors.red,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "บัญชีถูกระงับการใช้งาน",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "บัญชีของคุณถูกระงับการใช้งานเนื่องจากละเมิดนโยบายของระบบ หรือถูกรายงานจากผู้ใช้อื่น\n\nหากมีข้อสงสัยกรุณาติดต่อผู้ดูแลระบบ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "ตกลง",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailCtrl = TextEditingController(
      text: _emailController.text,
    );
    bool isSending = false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.lock_rotation,
                      color: AppTheme.primaryColor,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "ลืมรหัสผ่านใช่หรือไม่?",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "กรุณากรอกอีเมลที่ลงทะเบียนไว้\nระบบจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้คุณ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: "อีเมล",
                      prefixIcon: const Icon(
                        CupertinoIcons.mail,
                        color: AppTheme.primaryColor,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "ยกเลิก",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  String email = resetEmailCtrl.text.trim();
                                  if (email.isEmpty) {
                                    Get.snackbar(
                                      "แจ้งเตือน",
                                      "กรุณากรอกอีเมลของคุณ",
                                      backgroundColor: Colors.orange,
                                      colorText: Colors.white,
                                      snackPosition: SnackPosition.TOP,
                                    );
                                    return;
                                  }

                                  setStateDialog(() => isSending = true);

                                  try {
                                    await FirebaseAuth.instance
                                        .sendPasswordResetEmail(email: email);

                                    Get.back();
                                    _showCustomSnackbar(
                                      title: "ส่งลิงก์สำเร็จ",
                                      message:
                                          "กรุณาตรวจสอบกล่องจดหมาย (หรือโฟลเดอร์สแปม) ของคุณเพื่อตั้งรหัสผ่านใหม่",
                                      icon: CupertinoIcons
                                          .check_mark_circled_solid,
                                      backgroundColor: Colors.green,
                                    );
                                  } on FirebaseAuthException catch (e) {
                                    String msg = "เกิดข้อผิดพลาด กรุณาลองใหม่";
                                    if (e.code == 'user-not-found') {
                                      msg = "ไม่พบอีเมลนี้ในระบบ";
                                    } else if (e.code == 'invalid-email') {
                                      msg = "รูปแบบอีเมลไม่ถูกต้อง";
                                    }
                                    Get.snackbar(
                                      "ข้อผิดพลาด",
                                      msg,
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                      snackPosition: SnackPosition.TOP,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setStateDialog(() => isSending = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "ส่งลิงก์",
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
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  void _showSuccessWelcomeDialog({required bool isAdmin}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: (isAdmin ? Colors.blue : Colors.green)
                            .withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAdmin
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.checkmark_seal_fill,
                          color: isAdmin ? Colors.blue : Colors.green,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        isAdmin ? "ยินดีต้อนรับแอดมิน!" : "เข้าสู่ระบบสำเร็จ!",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isAdmin ? Colors.blue : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "กำลังพาท่านเข้าสู่ระบบ กรุณารอสักครู่...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          color: isAdmin ? Colors.blue : Colors.green,
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (isAdmin) {
        Get.offAll(() => const AdminDashboard());
      } else {
        Get.offAll(() => const HomeScreen());
      }
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

        bool isAdmin = adminDoc.exists;

        if (!isAdmin) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            var userData = userDoc.data() as Map<String, dynamic>;
            String status = userData['status'] ?? 'active';

            if (status == 'suspended' || status == 'banned') {
              await FirebaseAuth.instance.signOut();
              setState(() => _isLoading = false);
              _showBannedPopup();
              return;
            }
          }
        }

        try {
          await FirebaseMessaging.instance.requestPermission();
          String? fcmToken = await FirebaseMessaging.instance.getToken();

          if (fcmToken != null) {
            String collectionPath = isAdmin ? 'admins' : 'users';

            await FirebaseFirestore.instance
                .collection(collectionPath)
                .doc(user.uid)
                .set({
                  'fcmToken': fcmToken,
                  'lastLogin': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            debugPrint("FCM Token Saved to $collectionPath: $fcmToken");
          }
        } catch (tokenError) {
          debugPrint("Failed to fetch or save FCM Token: $tokenError");
        }

        try {
          await FirebaseFirestore.instance.collection('login_history').add({
            'uid': user.uid,
            'email': user.email,
            'timestamp': FieldValue.serverTimestamp(),
            'method': 'email_password',
          });
        } catch (e) {
          debugPrint("Failed to save login history: $e");
        }

        if (mounted) setState(() => _isLoading = false);

        _showSuccessWelcomeDialog(isAdmin: isAdmin);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      if (mounted) setState(() => _isLoading = false);
      _showCustomSnackbar(
        title: "Error",
        message: e.toString(),
        icon: CupertinoIcons.xmark_circle_fill,
        backgroundColor: Colors.red[800]!,
      );
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
      backgroundColor: backgroundColor.withValues(alpha: 0.9),
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
          color: backgroundColor.withValues(alpha: 0.4),
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
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.05,
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
                                  onPressed: _showForgotPasswordDialog,
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
                                        .withValues(alpha: 0.4),
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
                        // const Divider(),
                        // const Text(
                        //   "DEBUG MODE (Login ด่วน)",
                        //   style: TextStyle(color: Colors.grey, fontSize: 12),
                        // ),
                        // const SizedBox(height: 10),
                        // Wrap(
                        //   spacing: 10,
                        //   runSpacing: 10,
                        //   alignment: WrapAlignment.center,
                        //   children: [
                        //     _buildDebugBtn(
                        //       "Admin",
                        //       CupertinoIcons.at_badge_minus,
                        //       Colors.black87,
                        //       () {
                        //         _emailController.text = "admin@saidee.com";
                        //         _passwordController.text = "password1234";
                        //         _login();
                        //       },
                        //     ),
                        //     _buildDebugBtn(
                        //       "User 1",
                        //       CupertinoIcons.person,
                        //       Colors.blueGrey,
                        //       () {
                        //         _emailController.text = "saidee@gmail.com";
                        //         _passwordController.text = "123456";
                        //         _login();
                        //       },
                        //     ),
                        //     _buildDebugBtn(
                        //       "User 2",
                        //       CupertinoIcons.person,
                        //       Colors.blueGrey,
                        //       () {
                        //         _emailController.text = "saidee2@gmail.com";
                        //         _passwordController.text = "12345678";
                        //         _login();
                        //       },
                        //     ),
                        //     _buildDebugBtn(
                        //       "User 3",
                        //       CupertinoIcons.person,
                        //       Colors.blueGrey,
                        //       () {
                        //         _emailController.text = "test02@gmail.com";
                        //         _passwordController.text = "123456";
                        //         _login();
                        //       },
                        //     ),
                        //     _buildDebugBtn(
                        //       "User 4",
                        //       CupertinoIcons.person,
                        //       Colors.blueGrey,
                        //       () {
                        //         _emailController.text = "test03@gmail.com";
                        //         _passwordController.text = "123456";
                        //         _login();
                        //       },
                        //     ),
                        //   ],
                        // ),
                        // const SizedBox(height: 20),
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
          color: AppTheme.primaryColor.withValues(
            alpha: baseOpacity * opacityFactor,
          ),
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

  // Widget _buildDebugBtn(
  //   String label,
  //   IconData icon,
  //   Color color,
  //   VoidCallback onTap,
  // ) {
  //   return ElevatedButton.icon(
  //     onPressed: onTap,
  //     icon: Icon(icon, size: 16),
  //     label: Text(label),
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: color,
  //       foregroundColor: Colors.white,
  //       padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     ),
  //   );
  // }
}
