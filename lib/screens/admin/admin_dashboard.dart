import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'manage_master_data.dart';
import 'manage_shipping.dart';
import 'manage_coupon.dart';
import 'manage_announcement.dart';
import 'manage_report.dart';
import 'admin_transaction.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ผู้ดูแลระบบ (Admin)",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _buildMenuCard(
            context,
            "จัดการหมวดหมู่",
            Icons.category,
            Colors.orange,
            () => Get.to(
              () => const ManageMasterDataScreen(
                collection: 'categories',
                title: 'หมวดหมู่',
              ),
            ),
          ),

          _buildMenuCard(
            context,
            "จัดการประเภทสินค้า",
            Icons.style,
            Colors.purple,
            () => Get.to(
              () => const ManageMasterDataScreen(
                collection: 'types',
                title: 'ประเภทสินค้า',
              ),
            ),
          ),

          _buildMenuCard(
            context,
            "จัดการขนส่ง",
            Icons.local_shipping,
            Colors.blue,
            () => Get.to(() => const ManageShippingScreen()),
          ),

          _buildMenuCard(
            context,
            "จัดการคูปอง",
            Icons.local_offer,
            Colors.red,
            () => Get.to(() => const ManageCouponScreen()),
          ),

          _buildMenuCard(
            context,
            "จัดการประกาศ",
            Icons.campaign,
            Colors.teal,
            () => Get.to(() => const ManageAnnouncementScreen()),
          ),

          _buildMenuCard(
            context,
            "รายงาน & ผู้ใช้",
            Icons.report_problem,
            Colors.brown,
            () => Get.to(() => const ManageReportScreen()),
          ),

          _buildMenuCard(
            context,
            "ธุรกรรมการเงิน",
            Icons.account_balance_wallet,
            Colors.green,
            () => Get.to(() => const AdminTransactionScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
