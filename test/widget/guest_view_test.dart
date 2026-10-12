import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/widgets/guest_view.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('GuestView should render welcome headers, benefits, and auth buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: GuestView(),
      ),
    );

    // Verify Welcome Title & Description
    expect(find.text('ยินดีต้อนรับสู่ SAIDEE'), findsOneWidget);
    expect(
      find.text('แหล่งรวมเสื้อผ้ามือสองคุณภาพดี\nเข้าสู่ระบบเพื่อเริ่มต้นประสบการณ์ที่ดีที่สุด'),
      findsOneWidget,
    );

    // Verify 3 Benefit Items
    expect(find.text('ติดตามสถานะคำสั่งซื้อได้ง่ายๆ'), findsOneWidget);
    expect(find.text('บันทึกสินค้าที่ชอบลงรายการโปรด'), findsOneWidget);
    expect(find.text('ลงขายสินค้าของคุณเอง'), findsOneWidget);

    // Verify Login and Register CTA buttons
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('สร้างบัญชีใหม่'), findsOneWidget);
  });
}
