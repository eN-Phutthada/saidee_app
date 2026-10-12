import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/widgets/app_exit_scope.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() async {
    Get.closeAllSnackbars();
  });

  group('AppExitScope Widget & Double Back Tests', () {
    testWidgets('should render child widget correctly within AppExitScope',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: AppExitScope(
              child: Center(
                child: Text('Saidee Home Screen Body'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Saidee Home Screen Body'), findsOneWidget);
    });

    testWidgets('handleDoubleBack should return false on first tap and true on immediate second tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // First tap -> false (triggers snackbar)
      final firstTap = AppExitScope.handleDoubleBack();
      expect(firstTap, isFalse);
      await tester.pump();

      // Immediate second tap within interval -> true
      final secondTap = AppExitScope.handleDoubleBack();
      expect(secondTap, isTrue);

      // Settle all snackbar animations and pending timers to allow clean test tearDown
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });
  });
}
