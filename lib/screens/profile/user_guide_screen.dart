import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 320.0,
                floating: false,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                leading: IconButton(
                  icon: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  onPressed: () => Get.back(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                              AppTheme.primaryColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -50,
                        top: -50,
                        child: CircleAvatar(
                          radius: 100,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "SAIDEE Guarantee",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "ซื้อขายปลอดภัย เงินไม่หาย ได้ของชัวร์",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: TabBar(
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      labelStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      unselectedLabelStyle: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.bag_fill, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "สำหรับผู้ซื้อ",
                                style: TextStyle(
                                  fontFamily:
                                      theme.textTheme.titleMedium?.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.cube_box_fill,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "สำหรับผู้ขาย",
                                style: TextStyle(
                                  fontFamily:
                                      theme.textTheme.titleMedium?.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildBuyerGuide(theme, isDark),
              _buildSellerGuide(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerGuide(ThemeData theme, bool isDark) {
    final List<Map<String, dynamic>> steps = [
      {
        'icon': CupertinoIcons.search,
        'title': 'ค้นหาสินค้าที่ถูกใจ',
        'desc':
            'เลือกดูสินค้ามือสองคุณภาพดีจากหมวดหมู่ หรือพิมพ์ค้นหาในช่องค้นหา',
      },
      {
        'icon': CupertinoIcons.cart_fill,
        'title': 'เพิ่มลงตะกร้า & ชำระเงิน',
        'desc':
            'กดเพิ่มสินค้าลงตะกร้า และชำระเงินผ่าน SAIDEE Wallet อย่างปลอดภัย (เติมเงินได้ด้วย QR ยืนยันสลิป)',
      },
      {
        'icon': CupertinoIcons.cube_box_fill,
        'title': 'รอรับสินค้า',
        'desc':
            'ผู้ขายจะทำการจัดส่งและอัปเดตเลขพัสดุให้คุณ สามารถเช็คสถานะได้ที่เมนู "บัญชี > การซื้อของฉัน"',
      },
      {
        'icon': CupertinoIcons.checkmark_seal_fill,
        'title': 'กดยืนยันรับสินค้า',
        'desc':
            'เมื่อได้รับของและตรวจสอบความเรียบร้อยแล้ว ให้กดยืนยันรับสินค้า ระบบจึงจะโอนเงินให้ผู้ขาย',
      },
      {
        'icon': CupertinoIcons.star_fill,
        'title': 'ให้คะแนนรีวิว',
        'desc':
            'ให้คะแนนและรีวิวสินค้า เพื่อเป็นกำลังใจให้ผู้ขาย (หากพบปัญหาสามารถกดปุ่มรายงานได้ทันที)',
      },
    ];

    return _buildStepList(
      steps,
      theme,
      isDark,
      Colors.blueAccent,
      "เริ่มช้อปปิ้งเลย",
      () {
        Get.back();
      },
    );
  }

  Widget _buildSellerGuide(ThemeData theme, bool isDark) {
    final List<Map<String, dynamic>> steps = [
      {
        'icon': CupertinoIcons.camera_fill,
        'title': 'ถ่ายรูปและลงขายสินค้า',
        'desc':
            'ไปที่เมนู "ขาย" กรอกรายละเอียดสินค้า สภาพ และราคาให้ชัดเจน พร้อมอัปโหลดรูปภาพและวิดีโอประกอบ เพื่อดึงดูดผู้ซื้อ',
      },
      {
        'icon': CupertinoIcons.bell_solid,
        'title': 'รอรับคำสั่งซื้อ',
        'desc':
            'เมื่อมีลูกค้าสั่งซื้อ ระบบจะแจ้งเตือนและเงินจะถูกพักไว้ที่ระบบส่วนกลาง (Escrow) อย่างปลอดภัย',
      },
      {
        'icon': CupertinoIcons.car_detailed,
        'title': 'แพ็คของและจัดส่ง',
        'desc':
            'ไปที่เมนู "สถานะการขาย" ที่อยู่ในเมนู "ร้านค้าของฉัน" นำสินค้าไปส่งที่บริษัทขนส่ง และนำเลขพัสดุ (Tracking) มากดยืนยันในแอป',
      },
      {
        'icon': CupertinoIcons.money_dollar_circle_fill,
        'title': 'รับเงินเข้าวอลเล็ท',
        'desc':
            'เมื่อลูกค้ารับของและกดยืนยัน (หรือระบบยืนยันอัตโนมัติใน 7 วัน) เงินจะถูกโอนเข้า SAIDEE Wallet ของคุณทันที',
      },
    ];

    return _buildStepList(
      steps,
      theme,
      isDark,
      Colors.green,
      "ลงขายสินค้าชิ้นแรก",
      () {
        Get.back();
      },
    );
  }

  Widget _buildStepList(
    List<Map<String, dynamic>> steps,
    ThemeData theme,
    bool isDark,
    Color accentColor,
    String btnText,
    VoidCallback onBtnPressed,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
      physics: const BouncingScrollPhysics(),
      itemCount: steps.length + 1,
      itemBuilder: (context, index) {
        if (index == steps.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: onBtnPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  shadowColor: accentColor.withValues(alpha: 0.4),
                ),
                child: Text(
                  btnText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }

        final step = steps[index];
        final int stepNumber = index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.transparent,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -10,
                bottom: -20,
                child: Text(
                  stepNumber.toString(),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 100,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(step['icon'], color: accentColor, size: 26),
                    ),
                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ขั้นตอนที่ $stepNumber",
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step['title'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step['desc'],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
