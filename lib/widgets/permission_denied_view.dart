import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/login_screen.dart';
import 'package:saidee_app/screens/home/home_screen.dart';

class PermissionDeniedView extends StatefulWidget {
  final String title;
  final String message;
  final String? technicalDetails;
  final VoidCallback? onRetry;
  final bool isScaffold;
  final bool showHomeButton;
  final bool showLoginButton;

  const PermissionDeniedView({
    super.key,
    this.title = "สิทธิ์การเข้าถึงไม่เพียงพอ",
    this.message =
        "คุณไม่มีสิทธิ์ในการเข้าถึงหรือดูข้อมูลในส่วนนี้ (Admin Only)\nกรุณาเข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบ หรือติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์การใช้งาน",
    this.technicalDetails,
    this.onRetry,
    this.isScaffold = false,
    this.showHomeButton = true,
    this.showLoginButton = true,
  });

  static bool isPermissionDenied(dynamic error) {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission-denied') ||
        errorStr.contains('permission_denied') ||
        errorStr.contains('insufficient permissions') ||
        errorStr.contains('missing or insufficient permissions');
  }

  @override
  State<PermissionDeniedView> createState() => _PermissionDeniedViewState();
}

class _PermissionDeniedViewState extends State<PermissionDeniedView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: isDark ? 0.12 : 0.08),
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
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
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.lock_shield_fill,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                    "PERMISSION DENIED",
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (widget.technicalDetails != null &&
                widget.technicalDetails!.isNotEmpty) ...[
              GestureDetector(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showDetails
                          ? "ซ่อนรายละเอียดทางเทคนิค"
                          : "ดูรายละเอียดทางเทคนิคสำหรับนักพัฒนา",
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
              if (_showDetails) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
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
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.technicalDetails!),
                              );
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
                                icon: const Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: Colors.greenAccent,
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.doc_on_doc,
                                  size: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "คัดลอก",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      SelectableText(
                        widget.technicalDetails!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.redAccent,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
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
                      child: OutlinedButton.icon(
                        onPressed: () => Get.to(() => const LoginScreen()),
                        icon: const Icon(CupertinoIcons.person_crop_circle_badge_checkmark, size: 18),
                        label: const Text(
                          "เข้าสู่ระบบด้วยบัญชีผู้ดูแล",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (widget.showHomeButton) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton.icon(
                        onPressed: () => Get.offAll(() => const HomeScreen()),
                        icon: const Icon(CupertinoIcons.house_fill, size: 16),
                        label: const Text("กลับสู่หน้าหลัก"),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isScaffold) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Get.back(),
          ),
        ),
        body: content,
      );
    }

    return content;
  }
}
