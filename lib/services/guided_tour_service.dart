import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class GuidedTourService {
  static const String _prefKey = 'has_seen_guided_tour_v1';
  static const String _prefKeyAddProduct = 'has_seen_add_product_tour_v1';

  /// Check if the user has completed or skipped the guided tour
  static Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Mark the guided tour as seen
  static Future<void> markTourAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Reset the guided tour flag so the user can re-watch it
  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// Check if the user has completed or skipped the Add Product guided tour
  static Future<bool> hasSeenAddProductTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAddProduct) ?? false;
  }

  /// Mark the Add Product guided tour as seen
  static Future<void> markAddProductTourAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAddProduct, true);
  }

  /// Reset the Add Product guided tour flag
  static Future<void> resetAddProductTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAddProduct);
  }

  /// Show the interactive guided tour overlay
  static void showTour({
    required BuildContext context,
    required GlobalKey searchKey,
    required GlobalKey chatKey,
    required GlobalKey cartKey,
    required GlobalKey sellKey,
    required GlobalKey profileKey,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
  }) {
    List<TargetFocus> targets = [
      TargetFocus(
        identify: "TargetSearch",
        keyTarget: searchKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "ค้นหาสินค้ามือสอง 🔍",
                description:
                    "ค้นหาสินค้าที่คุณต้องการได้อย่างง่ายดาย พร้อมระบบกรองหมวดหมู่และราคาสินค้า",
                stepText: "1 จาก 5",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetChat",
        keyTarget: chatKey,
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "แชทติดต่อผู้ซื้อ-ผู้ขาย 💬",
                description:
                    "พูดคุยสอบถามรายละเอียดสินค้าเพิ่มเติม เจรจาราคา หรือส่งตำแหน่งสถานที่ได้อย่างปลอดภัย",
                stepText: "2 จาก 5",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetCart",
        keyTarget: cartKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "ตะกร้าสินค้าของคุณ 🛒",
                description:
                    "ตรวจสอบสินค้าที่คุณกดเลือกไว้ รวมยอดคำสั่งซื้อเพื่อดำเนินการชำระเงินได้สะดวก",
                stepText: "3 จาก 5",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetSell",
        keyTarget: sellKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "ลงขายสินค้ามือสอง ➕",
                description:
                    "เปลี่ยนของไม่ได้ใช้ให้เป็นรายได้! ลงประกาศขายสินค้าพร้อมรูปภาพและรายละเอียดได้ในไม่กี่ขั้นตอน",
                stepText: "4 จาก 5",
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetProfile",
        keyTarget: profileKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "โปรไฟล์และร้านค้าของคุณ 👤",
                description:
                    "จัดการข้อมูลส่วนตัว ติดตามสถานะคำสั่งซื้อ ตรวจสอบวอลเล็ท และจัดการรายการสินค้าที่คุณลงขาย",
                stepText: "5 จาก 5",
                isLast: true,
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
    ];

    TutorialCoachMark tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "ข้าม",
      paddingFocus: 8,
      opacityShadow: 0.8,
      onFinish: () {
        markTourAsSeen();
        onFinish?.call();
      },
      onSkip: () {
        markTourAsSeen();
        onSkip?.call();
        return true;
      },
    );

    tutorial.show(context: context);
  }

  /// Show the interactive guided tour for Add Product screen
  static void showAddProductTour({
    required BuildContext context,
    required GlobalKey imageKey,
    required GlobalKey categoryKey,
    required GlobalKey detailsKey,
    required GlobalKey priceWeightKey,
    required GlobalKey submitKey,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
  }) {
    Future<void> scrollToAndNext(
      GlobalKey? nextKey,
      TutorialCoachMarkController controller,
    ) async {
      if (nextKey?.currentContext != null) {
        await Scrollable.ensureVisible(
          nextKey!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
        await Future.delayed(const Duration(milliseconds: 150));
      }
      controller.next();
    }

    List<TargetFocus> targets = [
      TargetFocus(
        identify: "TargetImage",
        keyTarget: imageKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "รูปภาพ & วิดีโอสินค้า 📸",
                description:
                    "อัปโหลดรูปถ่ายสินค้า 3-5 รูป และคลิปสั้นไม่เกิน 15 วินาที แสดงสภาพสินค้าจริงเพื่อเพิ่มความน่าเชื่อถือให้ร้านค้า",
                stepText: "1 จาก 5",
                onNext: () => scrollToAndNext(categoryKey, controller),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetCategory",
        keyTarget: categoryKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "หมวดหมู่ & สภาพสินค้า 🏷️",
                description:
                    "เลือกหมวดหมู่ ประเภท ไซส์ สภาพสินค้า และระบุแบรนด์ให้ถูกต้อง ช่วยให้สินค้าถูกค้นพบได้ง่าย",
                stepText: "2 จาก 5",
                onNext: () => scrollToAndNext(detailsKey, controller),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetDetails",
        keyTarget: detailsKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "ชื่อ & รายละเอียดสินค้า ✍️",
                description:
                    "ระบุชื่อสินค้าที่ชัดเจน น่าดึงดูด พร้อมอธิบายจุดเด่น สภาพจริง หรือตำหนิให้ผู้ซื้อรับทราบ",
                stepText: "3 จาก 5",
                onNext: () => scrollToAndNext(priceWeightKey, controller),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetPriceWeight",
        keyTarget: priceWeightKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "ราคา & น้ำหนักพัสดุ 💰",
                description:
                    "กำหนดราคาสินค้า และระบุน้ำหนักรวมกล่องพัสดุ (กรัม) เพื่อให้ระบบคำนวณค่าส่งอัตโนมัติได้อย่างแม่นยำ",
                stepText: "4 จาก 5",
                onNext: () => scrollToAndNext(submitKey, controller),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TargetSubmit",
        keyTarget: submitKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTooltipCard(
                title: "ปุ่มลงขายสินค้า 🚀",
                description:
                    "เมื่อกรอกข้อมูลเรียบร้อยแล้ว กดปุ่มนี้เพื่อลงประกาศขายสินค้าและเริ่มรับคำสั่งซื้อได้ทันที!",
                stepText: "5 จาก 5",
                isLast: true,
                onNext: () => controller.next(),
                onSkip: () => controller.skip(),
              );
            },
          ),
        ],
      ),
    ];


    if (imageKey.currentContext != null) {
      Scrollable.ensureVisible(
        imageKey.currentContext!,
        duration: const Duration(milliseconds: 200),
        alignment: 0.1,
      );
    }

    TutorialCoachMark tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "ข้าม",
      paddingFocus: 8,
      opacityShadow: 0.8,
      onFinish: () {
        markAddProductTourAsSeen();
        onFinish?.call();
      },
      onSkip: () {
        markAddProductTourAsSeen();
        onSkip?.call();
        return true;
      },
    );

    tutorial.show(context: context);
  }


  static Widget _buildTooltipCard({
    required String title,
    required String description,
    required String stepText,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    bool isLast = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF28B431).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stepText,
                  style: GoogleFonts.kanit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF28B431),
                  ),
                ),
              ),
              InkWell(
                onTap: onSkip,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "ข้าม",
                    style: GoogleFonts.kanit(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.kanit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2F2F2F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.kanit(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B431),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: Text(
                isLast ? "เริ่มใช้งานเลย!" : "ถัดไป",
                style: GoogleFonts.kanit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
