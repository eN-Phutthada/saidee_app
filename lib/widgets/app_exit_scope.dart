import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class AppExitScope extends StatefulWidget {
  final Widget child;

  final bool Function()? onWillPopTab;

  final String exitMessage;

  final Duration exitInterval;

  final bool useDialogConfirmation;

  const AppExitScope({
    super.key,
    required this.child,
    this.onWillPopTab,
    this.exitMessage = 'กดอีกครั้งเพื่อออกจากแอป',
    this.exitInterval = const Duration(seconds: 2),
    this.useDialogConfirmation = false,
  });

  static DateTime? _lastBackPressTime;

  static bool handleDoubleBack({
    String message = 'กดอีกครั้งเพื่อออกจากแอป',
    Duration interval = const Duration(seconds: 2),
  }) {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > interval) {
      _lastBackPressTime = now;
      Get.closeCurrentSnackbar();
      Get.rawSnackbar(
        messageText: Center(
          child: Text(
            message,
            style: GoogleFonts.kanit(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        backgroundColor: Colors.black87,
        borderRadius: 25,
        margin: const EdgeInsets.only(bottom: 60, left: 70, right: 70),
        snackPosition: SnackPosition.BOTTOM,
        duration: interval,
        animationDuration: const Duration(milliseconds: 250),
      );
      return false;
    }
    return true;
  }

  static Future<bool> showExitDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool? result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.scaffoldBackgroundColor,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.square_arrow_right,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "ออกจากแอปพลิเคชัน",
              style: GoogleFonts.kanit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "คุณต้องการออกจากแอปพลิเคชัน SaiDee ใช่หรือไม่?",
          style: GoogleFonts.kanit(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              "ยกเลิก",
              style: GoogleFonts.kanit(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              "ออกจากแอป",
              style: GoogleFonts.kanit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  State<AppExitScope> createState() => _AppExitScopeState();
}

class _AppExitScopeState extends State<AppExitScope> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        if (widget.onWillPopTab != null && widget.onWillPopTab!()) {
          return;
        }

        if (widget.useDialogConfirmation) {
          final shouldExit = await AppExitScope.showExitDialog(context);
          if (shouldExit) {
            SystemNavigator.pop();
          }
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > widget.exitInterval) {
          _lastBackPressTime = now;
          Get.closeCurrentSnackbar();
          Get.rawSnackbar(
            messageText: Center(
              child: Text(
                widget.exitMessage,
                style: GoogleFonts.kanit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            backgroundColor: Colors.black87,
            borderRadius: 25,
            margin: const EdgeInsets.only(bottom: 60, left: 70, right: 70),
            snackPosition: SnackPosition.BOTTOM,
            duration: widget.exitInterval,
            animationDuration: const Duration(milliseconds: 250),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: widget.child,
    );
  }
}
