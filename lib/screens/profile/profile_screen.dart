import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/order/buyer_orders_screen.dart';
import 'package:saidee_app/screens/profile/account_security_screen.dart';
import 'package:saidee_app/screens/profile/user_guide_screen.dart';
import 'package:saidee_app/screens/wallet/wallet_topup_screen.dart';
import 'package:saidee_app/widgets/guest_view.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';
import 'edit_profile_screen.dart';
import 'package:saidee_app/screens/store/store_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return const GuestView();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorState(theme);
        }

        Map<String, dynamic> userData =
            snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : const Color(0xFFF5F5F5),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(
                      isDark
                          ? CupertinoIcons.sun_max
                          : CupertinoIcons.moon_stars,
                      color: Colors.white,
                    ),
                    onPressed: () => Get.changeThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.pencil_ellipsis_rectangle,
                      color: Colors.white,
                    ),
                    tooltip: "แก้ไขโปรไฟล์",
                    onPressed: () =>
                        Get.to(() => EditProfileScreen(userData: userData)),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      top: 60,
                    ),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white24,
                          backgroundImage:
                              (userData['profileImage'] != null &&
                                  userData['profileImage'] != '')
                              ? NetworkImage(userData['profileImage'])
                              : null,
                          child:
                              (userData['profileImage'] == null ||
                                  userData['profileImage'] == '')
                              ? const Icon(
                                  CupertinoIcons.person_fill,
                                  size: 35,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData['name'] ?? 'ไม่มีชื่อ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userData['email'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWalletCard(context, userData, isDark),
                      const SizedBox(height: 25),

                      Row(
                        children: [
                          Expanded(
                            child: _buildBigButton(
                              context,
                              CupertinoIcons.cube_box,
                              "การสั่งซื้อของฉัน",
                              onTap: () =>
                                  Get.to(() => const BuyerOrdersScreen()),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildBigButton(
                              context,
                              CupertinoIcons.bag,
                              "ร้านค้าของฉัน",
                              onTap: () => Get.to(
                                () => StoreProfileScreen(sellerId: user.uid),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      _buildSectionHeader("การตั้งค่าบัญชี"),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            _buildMenuTile(
                              context,
                              icon: CupertinoIcons.location,
                              title: "ที่อยู่ของฉัน",
                              hasBorder: true,
                              onTap: () => Get.to(
                                () => EditProfileScreen(userData: userData),
                              ),
                            ),
                            _buildMenuTile(
                              context,
                              icon: CupertinoIcons.shield,
                              title: "ความปลอดภัยบัญชี",
                              hasBorder: false,
                              onTap: () => Get.to(
                                () => AccountSecurityScreen(
                                  email: userData['email'] ?? '',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      _buildSectionHeader("ช่วยเหลือและอื่นๆ"),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            _buildMenuTile(
                              context,
                              icon: CupertinoIcons.book_solid,
                              title: "คู่มือการใช้งาน",
                              hasBorder: true,
                              onTap: () => Get.to(() => UserGuideScreen()),
                            ),
                            _buildMenuTile(
                              context,
                              icon: CupertinoIcons.chat_bubble_text,
                              title: "ฟีดแบค / แนะนำฟีเจอร์",
                              hasBorder: true,
                              onTap: () =>
                                  _showFeedbackDialog(context, user.uid),
                            ),
                            _buildMenuTile(
                              context,
                              icon: CupertinoIcons.info_circle,
                              title: "เกี่ยวกับ Saidee App",
                              hasBorder: false,
                              onTap: () => _showAboutApp(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmLogout(context),
                          icon: const Icon(CupertinoIcons.power, size: 20),
                          label: const Text(
                            "ออกจากระบบ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalletCard(BuildContext context, Map userData, bool isDark) {
    double balance = (userData['walletBalance'] ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.creditcard,
                    color: Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "วอลเล็ทของฉัน",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${balance.toStringAsFixed(2)} ฿",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => Get.to(() => const WalletTopUpScreen()),
            icon: const Icon(CupertinoIcons.add_circled, size: 18),
            label: const Text(
              "เติมเงิน",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigButton(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool hasBorder,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: hasBorder
            ? Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade100,
                ),
              )
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
          size: 22,
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(title: const Text("โปรไฟล์")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 50,
              color: Colors.orange,
            ),
            const SizedBox(height: 15),
            const Text("ไม่พบข้อมูลผู้ใช้ หรือเกิดข้อผิดพลาด"),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Get.offAll(() => const HomeScreen());
              },
              icon: const Icon(CupertinoIcons.square_arrow_right),
              label: const Text("ออกจากระบบ"),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    AppDialog.showCustomDialog(
      title: "ออกจากระบบ",
      message: "คุณแน่ใจหรือไม่ที่จะออกจากระบบ Saidee App?",
      icon: CupertinoIcons.power,
      iconColor: Colors.redAccent,
      confirmText: "ออกจากระบบ",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();

        Get.dialog(
          PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.waving_hand_rounded,
                              color: AppTheme.primaryColor,
                              size: 55,
                            ),
                          ),
                          const SizedBox(height: 25),
                          const Text(
                            "ออกจากระบบสำเร็จ",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "แล้วพบกันใหม่โอกาสหน้านะครับ...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 25),
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                              strokeWidth: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barrierDismissible: false,
        );

        await FirebaseAuth.instance.signOut();

        Future.delayed(const Duration(milliseconds: 1500), () {
          Get.offAll(() => const HomeScreen());
        });
      },
    );
  }

  void _showFeedbackDialog(BuildContext context, String uid) {
    final TextEditingController feedbackCtrl = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.chat_bubble_2_fill,
                color: AppTheme.primaryColor,
                size: 40,
              ),
              const SizedBox(height: 15),
              const Text(
                "ส่งฟีดแบค / เสนอแนะ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: feedbackCtrl,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText:
                      "แอปใช้งานยากตรงไหน หรืออยากให้มีฟีเจอร์อะไรเพิ่ม พิมพ์บอกเราได้เลยครับ...",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(15),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "ยกเลิก",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (feedbackCtrl.text.trim().isEmpty) return;
                        Get.back();
                        try {
                          await FirebaseFirestore.instance
                              .collection('feedbacks')
                              .add({
                                'uid': uid,
                                'message': feedbackCtrl.text.trim(),
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                          AppDialog.showCustomDialog(
                            title: "ขอบคุณครับ! 🎉",
                            message: "เราได้รับข้อเสนอแนะของคุณเรียบร้อยแล้ว",
                            icon: CupertinoIcons.heart_fill,
                            iconColor: Colors.green,
                            confirmText: "ตกลง",
                            onConfirm: () => Get.back(),
                          );
                        } catch (e) {
                          AppDialog.showCustomDialog(
                            title: "ผิดพลาด",
                            message:
                                "ไม่สามารถส่งข้อมูลได้ กรุณาลองใหม่อีกครั้ง",
                            icon: CupertinoIcons.xmark_circle_fill,
                            iconColor: Colors.red,
                            confirmText: "ตกลง",
                            onConfirm: () => Get.back(),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "ส่งข้อมูล",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutApp(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 60,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    CupertinoIcons.tag_fill,
                    color: AppTheme.primaryColor,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Saidee App",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Version 1.1.0 (Beta)",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "แพลตฟอร์มสำหรับซื้อ-ขาย เสื้อผ้ามือสองคุณภาพดี\nส่งต่อความสวยงามและลดขยะแฟชั่นไปด้วยกัน ♻️",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "พัฒนาโดย: ทีมงาน Saidee",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Get.back(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "ปิด",
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
