import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/login_screen.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

import 'manage_master_data.dart';
import 'manage_shipping.dart';
import 'manage_coupon.dart';
import 'manage_report.dart';
import 'manage_announcement.dart';
import 'admin_transaction.dart';
import 'admin_shop_search.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminDashboardContent(),
    const AdminTransactionScreen(isBottomNav: true),
  ];

  void _onBottomNavTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.scaffoldBackgroundColor
          : const Color(0xFFF7F9FC),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: theme.cardColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.creditcard),
            activeIcon: Icon(CupertinoIcons.creditcard_fill),
            label: 'ธุรกรรมการเงิน',
          ),
        ],
      ),
    );
  }
}

class AdminDashboardContent extends StatelessWidget {
  const AdminDashboardContent({super.key});

  void _handleLogout(BuildContext context) {
    AppDialog.showCustomDialog(
      title: "ออกจากระบบ",
      message: "คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?",
      icon: CupertinoIcons.power,
      iconColor: Colors.redAccent,
      confirmText: "ออกจากระบบ",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();
        await FirebaseAuth.instance.signOut();
        Get.offAll(() => const LoginScreen());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Stack(
                  children: [
                    Text(
                      'ADMIN',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.staatliches(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.pinkAccent,
                        shadows: const [
                          Shadow(
                            color: Colors.pinkAccent,
                            offset: Offset(6, 2.5),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'ADMIN',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.staatliches(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 2.5
                          ..color = Colors.black,
                      ),
                    ),
                    Text(
                      'ADMIN',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.staatliches(
                        fontSize: 52,
                        letterSpacing: 1.2,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48, height: 48),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isDark
                                ? CupertinoIcons.sun_max
                                : CupertinoIcons.moon,
                          ),
                          onPressed: () {
                            Get.changeThemeMode(
                              isDark ? ThemeMode.light : ThemeMode.dark,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.square_arrow_right,
                            color: Colors.red,
                          ),
                          tooltip: 'ออกจากระบบ',
                          onPressed: () => _handleLogout(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.4,
                    children: [
                      _AnimatedDashboardCard(
                        title: "หมวดหมู่",
                        icon: CupertinoIcons.square_grid_2x2,
                        collection: 'categories',
                        onTap: () => Get.to(
                          () => const ManageMasterDataScreen(
                            collection: 'categories',
                            title: 'หมวดหมู่สินค้า',
                          ),
                        ),
                      ),
                      _AnimatedDashboardCard(
                        title: "ประเภท",
                        icon: CupertinoIcons.tag,
                        collection: 'types',
                        onTap: () => Get.to(
                          () => const ManageMasterDataScreen(
                            collection: 'types',
                            title: 'ประเภทสินค้า',
                          ),
                        ),
                      ),
                      _AnimatedDashboardCard(
                        title: "ขนส่ง",
                        icon: CupertinoIcons.cube_box,
                        collection: 'shipping',
                        onTap: () => Get.to(() => const ManageShippingScreen()),
                      ),
                      _AnimatedDashboardCard(
                        title: "คูปอง",
                        icon: CupertinoIcons.ticket,
                        collection: 'coupons',
                        onTap: () => Get.to(() => const ManageCouponScreen()),
                      ),
                      _AnimatedDashboardCard(
                        title: "ประกาศ",
                        icon: CupertinoIcons.news,
                        collection: 'announcements',
                        onTap: () =>
                            Get.to(() => const ManageAnnouncementScreen()),
                      ),
                      _AnimatedDashboardCard(
                        title: "รายงานผู้ใช้",
                        icon: CupertinoIcons.exclamationmark_bubble,
                        collection: 'reports',
                        isReport: true,
                        onTap: () => Get.to(() => const ManageReportScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ผู้ใช้ล่าสุด",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Get.to(() => const AdminShopSearchScreen()),
                        child: const Text(
                          "ดูทั้งหมด >",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text("โหลดข้อมูลผิดพลาด");
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = snapshot.data!.docs;
                      if (users.isEmpty) {
                        return const Center(child: Text("ยังไม่มีผู้ใช้งาน"));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          var data =
                              users[index].data() as Map<String, dynamic>;
                          return _buildUserCard(context, data);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isActive = (data['status'] ?? 'active') == 'active';

    double balance = 0.0;
    if (data['walletBalance'] != null) {
      balance = data['walletBalance'].toDouble();
    } else if (data['wallet_balance'] != null) {
      balance = data['wallet_balance'].toDouble();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
            backgroundImage:
                (data['profileImage'] != null && data['profileImage'] != '')
                ? NetworkImage(data['profileImage'])
                : null,
            child: (data['profileImage'] == null || data['profileImage'] == '')
                ? Icon(
                    CupertinoIcons.person_fill,
                    color: isDark ? Colors.grey[400] : Colors.grey,
                  )
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unknown User',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      data['email'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isActive ? "ใช้งาน" : "ระงับ",
                style: TextStyle(
                  color: isActive ? Colors.blue : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "ยอดเงินคงเหลือ",
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                "${balance.toStringAsFixed(2)} ฿",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedDashboardCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String collection;
  final VoidCallback onTap;
  final bool isReport;

  const _AnimatedDashboardCard({
    required this.title,
    required this.icon,
    required this.collection,
    required this.onTap,
    this.isReport = false,
  });

  @override
  State<_AnimatedDashboardCard> createState() => _AnimatedDashboardCardState();
}

class _AnimatedDashboardCardState extends State<_AnimatedDashboardCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = widget.isReport
        ? (isDark ? const Color(0xFF3E2723) : const Color(0xFFFFE0B2))
        : (isDark ? const Color(0xFF1B5E20) : const Color(0xFFC1F7C3));

    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark
                    ? baseColor.withOpacity(0.8)
                    : Colors.white.withOpacity(0.9),
                baseColor,
              ],
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.6)
                          : Colors.black.withOpacity(0.15),
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                    BoxShadow(
                      color: isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.white,
                      offset: const Offset(-1, -1),
                      blurRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.6)
                          : Colors.black.withOpacity(0.15),
                      offset: const Offset(5, 5),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      offset: const Offset(-5, -5),
                      blurRadius: 10,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 24, color: textColor),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(widget.collection)
                    .snapshots(),
                builder: (context, snapshot) {
                  String count = "-";
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.length.toString();
                  }
                  return Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      count,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                            offset: const Offset(1, 2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
