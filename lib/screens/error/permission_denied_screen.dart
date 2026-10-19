import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/login_screen.dart';
import 'package:saidee_app/screens/home/home_screen.dart';

class PermissionDeniedScreen extends StatefulWidget {
  final String title;
  final String message;
  final String? technicalDetails;
  final VoidCallback? onRetry;
  final bool showHomeButton;
  final bool showLoginButton;

  const PermissionDeniedScreen({
    super.key,
    this.title = "สิทธิ์การเข้าถึงไม่เพียงพอ",
    this.message =
        "คุณไม่มีสิทธิ์ในการเข้าถึงหรือดูข้อมูลในส่วนนี้ (Missing or insufficient permissions)\nกรุณาเข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบ หรือติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์การใช้งาน",
    this.technicalDetails =
        "[cloud_firestore/permission-denied] PERMISSION_DENIED: Missing or insufficient permissions.",
    this.onRetry,
    this.showHomeButton = true,
    this.showLoginButton = true,
  });

  static Future<void> show({
    String? title,
    String? message,
    String? technicalDetails,
    VoidCallback? onRetry,
  }) async {
    await Get.to(
      () => PermissionDeniedScreen(
        title: title ?? "สิทธิ์การเข้าถึงไม่เพียงพอ",
        message: message ??
            "คุณไม่มีสิทธิ์ในการเข้าถึงหรือดูข้อมูลในส่วนนี้ (Missing or insufficient permissions)\nกรุณาเข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบ หรือติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์การใช้งาน",
        technicalDetails: technicalDetails ??
            "[cloud_firestore/permission-denied] PERMISSION_DENIED: Missing or insufficient permissions.",
        onRetry: onRetry,
      ),
      transition: Transition.fadeIn,
    );
  }

  static bool isPermissionDenied(dynamic error) {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission-denied') ||
        errorStr.contains('permission_denied') ||
        errorStr.contains('insufficient permissions') ||
        errorStr.contains('missing or insufficient permissions');
  }

  @override
  State<PermissionDeniedScreen> createState() => _PermissionDeniedScreenState();
}

class _PermissionDeniedScreenState extends State<PermissionDeniedScreen> {
  bool _showDetails = false;

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.rawSnackbar(
      messageText: const Text(
        "คัดลอกรายละเอียดข้อผิดพลาดแล้ว",
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
      backgroundColor: Colors.black87,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 10,
      icon: const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.greenAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    User? currentUser;
    try {
      currentUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      currentUser = null;
    }

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Get.back();
            } else {
              Get.offAll(() => const HomeScreen());
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withValues(alpha: isDark ? 0.15 : 0.08),
                        ),
                      ),
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFFF5252)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.lock_shield_fill,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "PERMISSION DENIED (403)",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kanit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.person_crop_circle,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "ข้อมูลผู้ใช้งานปัจจุบัน",
                              style: GoogleFonts.kanit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          label: "อีเมล:",
                          value: currentUser?.email ?? "ยังไม่ได้เข้าสู่ระบบ (Guest)",
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          label: "UID:",
                          value: currentUser != null
                              ? "${currentUser.uid.substring(0, 8)}..."
                              : "-",
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          label: "สถานะสิทธิ์:",
                          value: "ไม่มีสิทธิ์ระดับผู้ดูแลระบบ (Non-Admin)",
                          isDark: isDark,
                          valueColor: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (widget.technicalDetails != null &&
                      widget.technicalDetails!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => setState(() => _showDetails = !_showDetails),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[900]?.withValues(alpha: 0.5)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showDetails
                                  ? "ซ่อนรายละเอียดทางเทคนิค"
                                  : "ดูรายละเอียดทางเทคนิค (Technical Error)",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showDetails
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showDetails) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141414) : const Color(0xFF263238),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "FIRESTORE ERROR LOG",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _copyToClipboard(widget.technicalDetails!),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        CupertinoIcons.doc_on_doc,
                                        size: 12,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "คัดลอก",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 14),
                            SelectableText(
                              widget.technicalDetails!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFFFF8A80),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ] else ...[
                    const SizedBox(height: 14),
                  ],

                  Column(
                    children: [
                      if (widget.onRetry != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: widget.onRetry,
                            icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18),
                            label: const Text(
                              "ลองใหม่อีกครั้ง",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (widget.showLoginButton) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => Get.to(() => const LoginScreen()),
                            icon: const Icon(
                              CupertinoIcons.person_crop_circle_badge_checkmark,
                              size: 18,
                            ),
                            label: const Text(
                              "เข้าสู่ระบบด้วยบัญชีผู้ดูแล",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (widget.showHomeButton) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () => Get.offAll(() => const HomeScreen()),
                            icon: const Icon(CupertinoIcons.house_fill, size: 16),
                            label: const Text(
                              "กลับสู่หน้าหลัก",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                              side: BorderSide(
                                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
