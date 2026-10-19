import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class OtpPasswordResetScreen extends StatefulWidget {
  final String? initialEmail;
  const OtpPasswordResetScreen({super.key, this.initialEmail});

  @override
  State<OtpPasswordResetScreen> createState() => _OtpPasswordResetScreenState();
}

class _OtpPasswordResetScreenState extends State<OtpPasswordResetScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  Timer? _countdownTimer;
  int _secondsRemaining = 300;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    _newPasswordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordChanged);
    _countdownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _secondsRemaining = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณากรอกอีเมลของคุณ",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email)) {
      Get.snackbar(
        "ข้อผิดพลาด",
        "รูปแบบอีเมลไม่ถูกต้อง",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('sendPasswordResetOtp');

      await callable.call({'email': email});

      _startTimer();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });
      }

      AppDialog.showCustomDialog(
        title: "ส่งรหัส OTP สำเร็จ ✉️",
        message:
            "ระบบได้ส่งรหัสยืนยัน OTP ไปยังอีเมล:\n$email\n\n(รหัสมีอายุการใช้งาน 5 นาที หากไม่พบกรุณาตรวจสอบในโฟลเดอร์อีเมลขยะ/Spam)",
        icon: CupertinoIcons.mail_solid,
        iconColor: AppTheme.primaryColor,
        confirmText: "กรอกรหัส OTP",
        onConfirm: () => Get.back(),
      );
    } on FirebaseFunctionsException catch (funcError) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint(
        "Cloud Functions sendPasswordResetOtp error: ${funcError.code} - ${funcError.message}",
      );

      String errorTitle = "ไม่สามารถส่งรหัส OTP ได้";
      String errorMessage = funcError.message ?? "กรุณาลองใหม่อีกครั้ง";

      if (funcError.code == 'not-found') {
        errorTitle = "ไม่พบบัญชีผู้ใช้";
        errorMessage =
            "ไม่พบอีเมลนี้ในระบบ Saidee App กรุณาตรวจสอบอีเมลอีกครั้ง";
      } else if (funcError.code == 'resource-exhausted') {
        errorTitle = "ขอรหัสบ่อยเกินไป";
      } else if (funcError.code == 'invalid-argument') {
        errorTitle = "ข้อมูลไม่ถูกต้อง";
      }

      AppDialog.showCustomDialog(
        title: errorTitle,
        message: errorMessage,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.orange,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error sending OTP: $e");
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถเชื่อมต่อระบบส่งรหัส OTP ได้ กรุณาลองใหม่อีกครั้ง หรือเลือกรับลิงก์รีเซ็ตแทน",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final enteredOtp = _otpController.text.trim();

    if (enteredOtp.length != 6) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณากรอกรหัส OTP ให้ครบ 6 หลัก",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('verifyPasswordResetOtp');

      final response = await callable.call({'email': email, 'otp': enteredOtp});

      final data = response.data;
      if (data != null && data['success'] == true) {
        _resetToken = data['resetToken']?.toString();
        _countdownTimer?.cancel();

        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = 2;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        Get.snackbar(
          "รหัสไม่ถูกต้อง",
          "รหัส OTP ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } on FirebaseFunctionsException catch (funcError) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint(
        "verifyPasswordResetOtp error: ${funcError.code} - ${funcError.message}",
      );

      String errorTitle = "ยืนยันรหัสไม่สำเร็จ";
      String errorMessage = funcError.message ?? "กรุณาลองใหม่อีกครั้ง";

      if (funcError.code == 'not-found') {
        errorTitle = "ไม่พบคำขอ OTP";
        errorMessage = "ไม่พบคำขอรีเซ็ตรหัสผ่าน กรุณากดขอรหัสใหม่";
      } else if (funcError.code == 'deadline-exceeded') {
        errorTitle = "รหัส OTP หมดอายุ";
        errorMessage =
            "รหัส OTP นี้หมดอายุแล้ว (เกิน 5 นาที) กรุณากดขอรหัสใหม่";
      } else if (funcError.code == 'permission-denied') {
        errorTitle = "รหัส OTP ไม่ถูกต้อง";
      }

      AppDialog.showCustomDialog(
        title: errorTitle,
        message: errorMessage,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.orange,
        confirmText: "ตกลง",
        onConfirm: () {
          Get.back();
          if (funcError.code == 'deadline-exceeded' ||
              (funcError.message != null &&
                  funcError.message!.contains("ผิดเกิน 5 ครั้ง"))) {
            if (mounted) {
              setState(() {
                _currentStep = 0;
                _otpController.clear();
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error verifying OTP: $e");
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถยืนยันรหัส OTP ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _submitNewPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final enteredOtp = _otpController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณากรอกรหัสผ่านใหม่ให้ครบทั้งสองช่อง",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (newPassword.length < 8) {
      Get.snackbar(
        "รหัสผ่านสั้นเกินไป",
        "รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(newPassword)) {
      Get.snackbar(
        "ความปลอดภัยรหัสผ่าน",
        "รหัสผ่านต้องมีทั้งตัวอักษรภาษาอังกฤษและตัวเลข",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      Get.snackbar(
        "รหัสผ่านไม่ตรงกัน",
        "รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน กรุณาตรวจสอบ",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('verifyOtpAndResetPassword');

      final response = await callable.call({
        'email': email,
        'resetToken': _resetToken,
        'otp': enteredOtp,
        'newPassword': newPassword,
      });

      debugPrint(
        "Cloud Functions verifyOtpAndResetPassword success: ${response.data}",
      );

      if (mounted) setState(() => _isLoading = false);

      AppDialog.showCustomDialog(
        title: "ตั้งรหัสผ่านใหม่สำเร็จ 🎉",
        message:
            "รหัสผ่านของคุณได้รับการอัปเดตเรียบร้อยแล้ว กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่ของคุณ",
        icon: CupertinoIcons.checkmark_seal_fill,
        iconColor: Colors.green,
        confirmText: "เข้าสู่ระบบ",
        onConfirm: () {
          Get.back();
          Get.back();
        },
      );
    } on FirebaseFunctionsException catch (funcError) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint(
        "verifyOtpAndResetPassword error: ${funcError.code} - ${funcError.message}",
      );

      String errorTitle = "ตั้งรหัสผ่านไม่สำเร็จ";
      String errorMessage =
          funcError.message ?? "เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน";

      if (funcError.code == 'permission-denied' ||
          funcError.code == 'not-found') {
        errorTitle = "เซสชันหมดอายุ";
        errorMessage =
            "เซสชันการรีเซ็ตรหัสผ่านหมดอายุแล้ว กรุณาเริ่มทำรายการใหม่";
      }

      AppDialog.showCustomDialog(
        title: errorTitle,
        message: errorMessage,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () {
          Get.back();
          if (funcError.code == 'permission-denied' ||
              funcError.code == 'not-found') {
            if (mounted) {
              setState(() {
                _currentStep = 0;
                _otpController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();
                _resetToken = null;
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error setting new password: $e");
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถตั้งรหัสผ่านใหม่ได้ กรุณาลองอีกครั้ง",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _sendPasswordResetEmailDirect() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณากรอกอีเมลของคุณเพื่อรับลิงก์",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email)) {
      Get.snackbar(
        "ข้อผิดพลาด",
        "รูปแบบอีเมลไม่ถูกต้อง",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _isLoading = false);

      AppDialog.showCustomDialog(
        title: "ส่งลิงก์สำเร็จ",
        message:
            "ระบบได้ส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปยังอีเมล:\n$email\n\nกรุณาตรวจสอบกล่องจดหมาย (หรือโฟลเดอร์สแปม) เพื่อดำเนินการต่อ",
        icon: CupertinoIcons.check_mark_circled_solid,
        iconColor: Colors.green,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      Get.snackbar(
        "ข้อผิดพลาด",
        "เกิดข้อผิดพลาด: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "กู้คืนรหัสผ่านด้วย OTP",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Get.back();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildStepIndicator(isDark),
              const SizedBox(height: 30),
              if (_currentStep == 0) _buildStep0EmailInput(theme, isDark),
              if (_currentStep == 1) _buildStep1OtpVerification(theme, isDark),
              if (_currentStep == 2) _buildStep2NewPassword(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepBadge(0, "อีเมล", isDark),
        _buildStepDivider(0, isDark),
        _buildStepBadge(1, "ยืนยัน OTP", isDark),
        _buildStepDivider(1, isDark),
        _buildStepBadge(2, "รหัสใหม่", isDark),
      ],
    );
  }

  Widget _buildStepBadge(int stepIndex, String title, bool isDark) {
    final isPassed = _currentStep > stepIndex;
    final isCurrent = _currentStep == stepIndex;

    Color badgeColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    Color textColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    if (isCurrent || isPassed) {
      badgeColor = AppTheme.primaryColor;
      textColor = Colors.white;
    }

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isPassed
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    "${stepIndex + 1}",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent
                ? AppTheme.primaryColor
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int stepIndex, bool isDark) {
    final isPassed = _currentStep > stepIndex;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
      color: isPassed
          ? AppTheme.primaryColor
          : (isDark ? Colors.grey[800] : Colors.grey[300]),
    );
  }

  Widget _buildStep0EmailInput(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.mail,
            color: AppTheme.primaryColor,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "ระบุอีเมลของคุณ",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          "ระบบจะส่งรหัสยืนยัน OTP 6 หลักไปยังอีเมลที่ลงทะเบียนไว้\nเพื่อใช้สำหรับตั้งรหัสผ่านใหม่",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: "อีเมลของคุณ",
            prefixIcon: const Icon(
              CupertinoIcons.mail,
              color: AppTheme.primaryColor,
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text(
                    "ส่งรหัส OTP",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "หรือเลือกวิธีอื่น",
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _sendPasswordResetEmailDirect,
            icon: const Icon(CupertinoIcons.mail, size: 18),
            label: const Text(
              "รับลิงก์รีเซ็ตรหัสผ่านทางอีเมล",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1OtpVerification(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.lock_shield_fill,
            color: Colors.blue,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "ยืนยันรหัส OTP",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          "กรุณากรอกรหัสยืนยัน 6 หลักที่ได้รับทางอีเมล\n${_emailController.text.trim()}",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 25),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 10,
          ),
          decoration: InputDecoration(
            counterText: "",
            hintText: "••••••",
            hintStyle: TextStyle(
              letterSpacing: 10,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _secondsRemaining > 0
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.timer,
                size: 16,
                color: _secondsRemaining > 0 ? Colors.blue : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                _secondsRemaining > 0
                    ? "รหัสหมดอายุใน ${_formatTimer(_secondsRemaining)}"
                    : "รหัส OTP หมดอายุแล้ว",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _secondsRemaining > 0 ? Colors.blue : Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text(
                    "ยืนยันรหัส OTP",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _secondsRemaining <= 240 ? _sendOtp : null,
          child: Text(
            "ขอรหัส OTP ใหม่",
            style: TextStyle(
              color: _secondsRemaining <= 240
                  ? AppTheme.primaryColor
                  : Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isLoading ? null : _sendPasswordResetEmailDirect,
          icon: const Icon(CupertinoIcons.mail, size: 16),
          label: const Text(
            "ไม่ได้รับ OTP? ส่งลิงก์รีเซ็ตรหัสผ่านทางอีเมลแทน",
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2NewPassword(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.lock_rotation,
            color: Colors.green,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "ตั้งรหัสผ่านใหม่",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          "กรุณาระบุรหัสผ่านใหม่ของคุณ (ความยาวอย่างน้อย 8 ตัวอักษร\nประกอบด้วยตัวอักษรภาษาอังกฤษและตัวเลข)",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 25),
        TextField(
          controller: _newPasswordController,
          obscureText: _hideNewPassword,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: "รหัสผ่านใหม่",
            prefixIcon: const Icon(
              CupertinoIcons.lock,
              color: AppTheme.primaryColor,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _hideNewPassword
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                color: Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _hideNewPassword = !_hideNewPassword),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        _buildPasswordStrengthIndicator(isDark),
        _buildPasswordRequirements(isDark),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _hideConfirmPassword,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: "ยืนยันรหัสผ่านใหม่",
            prefixIcon: const Icon(
              CupertinoIcons.lock_shield,
              color: AppTheme.primaryColor,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _hideConfirmPassword
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                color: Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _hideConfirmPassword = !_hideConfirmPassword),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitNewPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text(
                    "บันทึกรหัสผ่านใหม่",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator(bool isDark) {
    final password = _newPasswordController.text;
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = _calculatePasswordStrength(password);
    final text = _getPasswordStrengthText(strength);
    final color = _getPasswordStrengthColor(strength);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ความแข็งแกร่งรหัสผ่าน:",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: strength,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double strength = 0.0;
    if (password.length >= 8) strength += 0.35;
    if (password.length >= 10) strength += 0.15;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      strength += 0.2;
    }
    if (RegExp(r'\d').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;
    return strength.clamp(0.0, 1.0);
  }

  String _getPasswordStrengthText(double strength) {
    if (strength < 0.4) return 'อ่อน (Weak)';
    if (strength < 0.75) return 'ปานกลาง (Medium)';
    return 'แข็งแกร่ง (Strong)';
  }

  Color _getPasswordStrengthColor(double strength) {
    if (strength < 0.4) return Colors.red;
    if (strength < 0.75) return Colors.orange;
    return Colors.green;
  }

  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password)) return false;
    return true;
  }

  Widget _buildPasswordRequirements(bool isDark) {
    final password = _newPasswordController.text;
    if (password.isEmpty || _isPasswordValid(password)) {
      return const SizedBox.shrink();
    }

    final hasMinLength = password.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                CupertinoIcons.shield_fill,
                color: AppTheme.primaryColor,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                "เงื่อนไขการตั้งรหัสผ่าน:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRequirementItem(
            "ความยาวอย่างน้อย 8 ตัวอักษรขึ้นไป",
            hasMinLength,
            isDark,
          ),
          const SizedBox(height: 4),
          _buildRequirementItem(
            "ต้องมีตัวอักษรภาษาอังกฤษ (A-Z, a-z)",
            hasLetter,
            isDark,
          ),
          const SizedBox(height: 4),
          _buildRequirementItem("ต้องมีตัวเลข (0-9)", hasNumber, isDark),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 6),
                child: Icon(
                  CupertinoIcons.info_circle,
                  size: 12,
                  color: Colors.grey,
                ),
              ),
              Expanded(
                child: Text(
                  "หลีกเลี่ยงเบอร์โทรศัพท์ วันเกิด หรือรหัสผ่านเดาง่าย",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet, bool isDark) {
    return Row(
      children: [
        Icon(
          isMet
              ? CupertinoIcons.checkmark_alt_circle_fill
              : CupertinoIcons.circle,
          size: 14,
          color: isMet ? AppTheme.primaryColor : Colors.grey[400],
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            color: isMet
                ? (isDark ? Colors.green[300] : Colors.green[800])
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}
