import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

/// A wrapper widget to prevent users from accidentally exiting the application.
///
/// Features:
/// 1. Tab back-navigation: If on a secondary tab (e.g. Cart, Profile), pressing back
///    smoothly returns to the Home tab first instead of quitting.
/// 2. Double-tap to exit: Pressing back at root shows a clean pill notification:
///    "กดอีกครั้งเพื่อออกจากแอป". Exits only when pressed again within [exitInterval].
/// 3. Optional dialog confirmation support.
class AppExitScope extends StatefulWidget {
  final Widget child;

  /// Optional callback to handle sub-navigation (e.g. bottom navigation tabs).
  /// If this returns `true`, the back press is considered handled and won't trigger exit.
  final bool Function()? onWillPopTab;

  /// Toast message shown when back is pressed once at root.
  final String exitMessage;

  /// Duration window during which a second back press will exit.
  final Duration exitInterval;

  /// If true, shows a confirmation dialog instead of double-tap toast.
  final bool useDialogConfirmation;

  const AppExitScope({
    super.key,
    required this.child,
    this.onWillPopTab,
    this.exitMessage = 'กดอีกครั้งเพื่อออกจากแอป',
    this.exitInterval = const Duration(seconds: 2),
    this.useDialogConfirmation = false,
  });

  /// Static helper for imperative double-back handling
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

  /// Shows a confirmation dialog asking if the user really wants to exit.
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

        // 1. If child navigator can pop, pop it
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // 2. If tab navigation handled it (e.g. index != 0 -> return to home tab)
        if (widget.onWillPopTab != null && widget.onWillPopTab!()) {
          return;
        }

        // 3. If dialog confirmation mode is requested
        if (widget.useDialogConfirmation) {
          final shouldExit = await AppExitScope.showExitDialog(context);
          if (shouldExit) {
            SystemNavigator.pop();
          }
          return;
        }

        // 4. Double-tap back check (Standard Android pattern)
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

        // Second press within interval -> Exit app
        SystemNavigator.pop();
      },
      child: widget.child,
    );
  }
}
