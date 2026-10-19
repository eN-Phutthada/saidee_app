import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/screens/admin/admin_store_view_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AdminStoreViewScreen Widget Tests', () {
    testWidgets('should render store header, admin banner, analytics card, and tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockSellerData = {
        'name': 'ร้านสายดี แฟชั่นมือสอง',
        'email': 'seller@example.com',
        'phone': '0812345678',
        'bio': 'เสื้อผ้าแบรนด์เนมมือสอง สภาพนางฟ้า',
        'status': 'active',
        'strikeCount': 1,
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: AdminStoreViewScreen(
            sellerId: 'test_seller_123',
            sellerData: mockSellerData,
          ),
        ),
      );

      // Verify Admin Mode Banner
      expect(find.text('หน้าร้านค้า (Admin View)'), findsOneWidget);
      expect(
        find.textContaining('โหมดผู้ดูแลระบบ: แสดงข้อมูลเชิงลึก'),
        findsOneWidget,
      );

      // Verify Store Identity & Badges
      expect(find.text('ร้านสายดี แฟชั่นมือสอง'), findsOneWidget);
      expect(find.text('เปิดบริการปกติ'), findsOneWidget);
      expect(find.text('Strike: 1 ครั้ง'), findsOneWidget);
      expect(find.textContaining('UID: test_sel...'), findsOneWidget);

      // Verify Financial & Sales Performance Card
      expect(find.text('ข้อมูลร้านค้า & ยอดขาย (Real-time Analytics)'), findsOneWidget);
      expect(find.text('ยอดขายรวมสำเร็จ (GMV)'), findsOneWidget);
      expect(find.text('สรุปคำสั่งซื้อทั้งหมด:'), findsOneWidget);
      expect(find.text('สต็อกสินค้าในระบบ:'), findsOneWidget);

      // Verify Navigation Tabs
      expect(find.text('สินค้าทั้งหมด'), findsOneWidget);
      expect(find.text('คำสั่งซื้อ'), findsOneWidget);
      expect(find.text('รีวิวของร้าน'), findsOneWidget);

      // Verify Bottom Moderation Bar
      expect(find.text('ระงับร้านค้านี้'), findsOneWidget);
      expect(find.text('ดูรายงาน'), findsOneWidget);
    });

    testWidgets('should display ban details without blocking admin inspection when store is banned',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockBannedSellerData = {
        'name': 'ร้านมีปัญหา ปลอมแปลงสินค้า',
        'email': 'banned@example.com',
        'phone': '0899999999',
        'bio': 'เสื้อผ้าแฟชั่น',
        'status': 'banned',
        'banReason': 'ส่งสินค้าละเมิดลิขสิทธิ์และไม่ตรงปก',
        'strikeCount': 3,
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: AdminStoreViewScreen(
            sellerId: 'banned_seller_999',
            sellerData: mockBannedSellerData,
          ),
        ),
      );

      // Verify Banned Store Badge & Details
      expect(find.text('ร้านค้าถูกระงับ'), findsOneWidget);
      expect(find.text('รายละเอียดการระงับร้านค้า'), findsOneWidget);
      expect(find.text('เหตุผล: ส่งสินค้าละเมิดลิขสิทธิ์และไม่ตรงปก'), findsOneWidget);

      // Admin MUST still see the tabs and NOT be blocked by user-facing banned roadblock
      expect(find.text('สินค้าทั้งหมด'), findsOneWidget);
      expect(find.text('คำสั่งซื้อ'), findsOneWidget);
      expect(find.text('รีวิวของร้าน'), findsOneWidget);

      // Verify Moderation Bar displays 'ปลดการระงับร้าน'
      expect(find.text('ปลดการระงับร้าน'), findsOneWidget);
    });
  });
}
