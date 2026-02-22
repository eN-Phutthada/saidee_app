import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/wallet/wallet_topup_screen.dart';
import 'package:saidee_app/widgets/guest_view.dart';
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("บัญชีของฉัน")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("ไม่พบข้อมูลผู้ใช้ หรือเกิดข้อผิดพลาด"),
                  const SizedBox(height: 20),
                  TextButton.icon(
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

        Map<String, dynamic> userData =
            snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              "บัญชีของฉัน",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon_stars,
                ),
                onPressed: () {
                  Get.changeThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  CupertinoIcons.settings,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () {
                  Get.to(() => EditProfileScreen(userData: userData));
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Get.to(() => EditProfileScreen(userData: userData)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: isDark
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            backgroundImage:
                                (userData['profileImage'] != null &&
                                    userData['profileImage'] != '')
                                ? NetworkImage(userData['profileImage'])
                                : null,
                            child:
                                (userData['profileImage'] == null ||
                                    userData['profileImage'] == '')
                                ? Icon(
                                    CupertinoIcons.person_fill,
                                    size: 35,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['name'] ?? 'ไม่มีชื่อ',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  userData['bio'] ?? 'ส่งต่อเสื้อผ้าคุณภาพ',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.pencil,
                            color: isDark ? Colors.grey[400] : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  Row(
                    children: [
                      Expanded(
                        child: _buildBigButton(
                          context,
                          CupertinoIcons.cube_box,
                          "การสั่งซื้อ\nของฉัน",
                          onTap: () {
                            // TODO: ไปหน้าการสั่งซื้อ
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildBigButton(
                          context,
                          CupertinoIcons.bag,
                          "การขาย\nของฉัน",
                          onTap: () {
                            Get.to(
                              () => StoreProfileScreen(sellerId: user.uid),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  _buildMenuTile(
                    context,
                    title: "เติมวอลเล็ท",
                    isBold: true,
                    onTap: () => Get.to(() => const WalletTopUpScreen()),
                  ),
                  const SizedBox(height: 25),

                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildMenuTile(
                          context,
                          title: "การสั่งซื้อและการขาย",
                          hasBorder: true,
                          useContainer: false,
                        ),
                        _buildMenuTile(
                          context,
                          title: "ที่อยู่ของฉัน",
                          hasBorder: true,
                          useContainer: false,
                        ),
                        _buildMenuTile(
                          context,
                          title: "ฟีดแบค/แนะนำฟีเจอร์ใหม่",
                          hasBorder: false,
                          useContainer: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();

                        Get.snackbar(
                          "สำเร็จ",
                          "ออกจากระบบเรียบร้อยแล้ว",
                          icon: const Icon(
                            CupertinoIcons.checkmark_alt_circle_fill,
                            color: Colors.white,
                            size: 28,
                          ),
                          snackPosition: SnackPosition.TOP,
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.9,
                          ),
                          colorText: Colors.white,
                          borderRadius: 16,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          duration: const Duration(seconds: 3),
                          isDismissible: true,
                          dismissDirection: DismissDirection.horizontal,
                          forwardAnimationCurve: Curves.easeOutBack,
                          barBlur: 20,
                          boxShadows: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        );

                        Get.offAll(() => const HomeScreen());
                      },
                      child: const Text(
                        "ออกจากระบบ",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBigButton(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme.iconTheme.color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required String title,
    bool isBold = false,
    bool hasBorder = false,
    bool useContainer = true,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget listTile = ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: theme.iconTheme.color?.withOpacity(0.5),
      ),
      onTap: onTap ?? () {},
    );

    if (!useContainer) {
      if (hasBorder) {
        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.1),
              ),
            ),
          ),
          child: listTile,
        );
      }
      return listTile;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isBold
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: listTile,
    );
  }
}
