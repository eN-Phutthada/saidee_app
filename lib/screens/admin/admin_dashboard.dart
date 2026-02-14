import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/login_screen.dart';

import 'manage_master_data.dart';
import 'manage_shipping.dart';
import 'manage_coupon.dart';
import 'manage_report.dart';
import 'manage_announcement.dart';
import 'admin_transaction.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  void _handleLogout() {
    Get.defaultDialog(
      title: "ออกจากระบบ",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: "คุณต้องการออกจากระบบผู้ดูแลหรือไม่?",
      textConfirm: "ใช่, ออกจากระบบ",
      textCancel: "ยกเลิก",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: Colors.black,
      onConfirm: () async {
        await FirebaseAuth.instance.signOut();
        Get.offAll(() => const LoginScreen());
      },
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      Get.to(() => const AdminTransactionScreen());
      setState(() => _selectedIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 48, height: 48),

                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
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
                  ),

                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      tooltip: 'ออกจากระบบ',
                      onPressed: _handleLogout,
                    ),
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
                        _buildDashboardCard(
                          title: "หมวดหมู่",
                          icon: Icons.category,
                          collection: 'categories',
                          onTap: () => Get.to(
                            () => const ManageMasterDataScreen(
                              collection: 'categories',
                              title: 'หมวดหมู่สินค้า',
                            ),
                          ),
                        ),
                        _buildDashboardCard(
                          title: "ประเภท",
                          icon: Icons.style,
                          collection: 'types',
                          onTap: () => Get.to(
                            () => const ManageMasterDataScreen(
                              collection: 'types',
                              title: 'ประเภทสินค้า',
                            ),
                          ),
                        ),
                        _buildDashboardCard(
                          title: "ขนส่ง",
                          icon: Icons.local_shipping_outlined,
                          collection: 'shipping',
                          onTap: () =>
                              Get.to(() => const ManageShippingScreen()),
                        ),
                        _buildDashboardCard(
                          title: "คูปอง",
                          icon: Icons.local_offer_outlined,
                          collection: 'coupons',
                          onTap: () => Get.to(() => const ManageCouponScreen()),
                        ),
                        _buildDashboardCard(
                          title: "ประกาศ",
                          icon: Icons.campaign_outlined,
                          collection: 'announcements',
                          onTap: () =>
                              Get.to(() => const ManageAnnouncementScreen()),
                        ),
                        _buildDashboardCard(
                          title: "รายงาน\nผู้ใช้",
                          icon: Icons.person_search,
                          collection: 'reports',
                          isReport: true,
                          onTap: () => Get.to(() => const ManageReportScreen()),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ผู้ใช้ล่าสุด",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "ดูทั้งหมด >",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
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
                          return const Text("เกิดข้อผิดพลาดในการโหลดข้อมูล");
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                            return _buildUserCard(data);
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
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'ธุรกรรมการเงิน',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required String collection,
    required VoidCallback onTap,
    bool isReport = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFC1F7C3),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
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
                Icon(icon, size: 35, color: Colors.black87),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collection)
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
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data) {
    bool isActive = (data['status'] ?? 'active') == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            backgroundImage:
                (data['profileImage'] != null && data['profileImage'] != '')
                ? NetworkImage(data['profileImage'])
                : null,
            child: (data['profileImage'] == null || data['profileImage'] == '')
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                const Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    SizedBox(width: 5),
                    Text(
                      "5.0/5 Rating",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                "${data['wallet_balance'] ?? 0} ฿",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
