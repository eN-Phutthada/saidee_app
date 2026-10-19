import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/widgets/permission_denied_view.dart';
import 'package:saidee_app/screens/error/permission_denied_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PermissionDenied Error Pattern Detection Tests', () {
    test('should identify Firestore permission denied string variations', () {
      expect(
        PermissionDeniedView.isPermissionDenied(
          '[cloud_firestore/permission-denied] PERMISSION_DENIED: Missing or insufficient permissions.',
        ),
        isTrue,
      );

      expect(
        PermissionDeniedView.isPermissionDenied(
          'FirebaseException: [cloud_firestore/permission-denied] The caller does not have permission',
        ),
        isTrue,
      );

      expect(
        PermissionDeniedView.isPermissionDenied(
          'Missing or insufficient permissions.',
        ),
        isTrue,
      );

      expect(
        PermissionDeniedView.isPermissionDenied('Network error occurred'),
        isFalse,
      );

      expect(
        PermissionDeniedView.isPermissionDenied(null),
        isFalse,
      );
    });
  });

  group('PermissionDeniedView Widget Tests', () {
    testWidgets('should render badge, title, message, and action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: PermissionDeniedView(
              title: "สิทธิ์การเข้าถึงไม่เพียงพอ",
              message: "คุณไม่มีสิทธิ์ในการเข้าถึงส่วนนี้",
              technicalDetails:
                  "[cloud_firestore/permission-denied] PERMISSION_DENIED",
            ),
          ),
        ),
      );

      expect(find.text('PERMISSION DENIED'), findsOneWidget);
      expect(find.text('สิทธิ์การเข้าถึงไม่เพียงพอ'), findsOneWidget);
      expect(find.text('คุณไม่มีสิทธิ์ในการเข้าถึงส่วนนี้'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบด้วยบัญชีผู้ดูแล'), findsOneWidget);
      expect(find.text('กลับสู่หน้าหลัก'), findsOneWidget);
    });
  });

  group('PermissionDeniedScreen Widget Tests', () {
    testWidgets('should render full screen with status card and technical details',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: PermissionDeniedScreen(
            title: "ปฏิเสธการเข้าถึง",
            message: "กรุณาเข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบ",
            technicalDetails:
                "[cloud_firestore/permission-denied] PERMISSION_DENIED: Missing or insufficient permissions.",
          ),
        ),
      );

      expect(find.text('PERMISSION DENIED (403)'), findsOneWidget);
      expect(find.text('ปฏิเสธการเข้าถึง'), findsAtLeastNWidgets(1));
      expect(find.text('ข้อมูลผู้ใช้งานปัจจุบัน'), findsOneWidget);
      expect(find.text('ดูรายละเอียดทางเทคนิค (Technical Error)'), findsOneWidget);

      // Tap to expand technical details
      await tester.tap(find.text('ดูรายละเอียดทางเทคนิค (Technical Error)'));
      await tester.pumpAndSettle();

      expect(find.text('ซ่อนรายละเอียดทางเทคนิค'), findsOneWidget);
      expect(find.text('FIRESTORE ERROR LOG'), findsOneWidget);
      expect(find.text('คัดลอก'), findsOneWidget);
    });
  });
}
