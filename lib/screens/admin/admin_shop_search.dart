import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
// import 'package:saidee_app/screens/store/store_profile_screen.dart';

class AdminShopSearchScreen extends StatefulWidget {
  const AdminShopSearchScreen({super.key});

  @override
  State<AdminShopSearchScreen> createState() => _AdminShopSearchScreenState();
}

class _AdminShopSearchScreenState extends State<AdminShopSearchScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.scaffoldBackgroundColor
          : const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: isDark
            ? theme.scaffoldBackgroundColor
            : const Color(0xFFF7F9FC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.transparent : Colors.grey[300]!,
            ),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อร้านค้า หรือ ชื่อผู้ใช้...',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey,
              ),
              prefixIcon: Icon(
                CupertinoIcons.search,
                color: isDark ? Colors.grey[400] : Colors.grey,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(color: theme.colorScheme.onSurface),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var users = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String name = (data['name'] ?? '').toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

          if (users.isEmpty) {
            return Center(
              child: Text(
                "ไม่พบข้อมูลผู้ใช้งาน/ร้านค้า",
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              var data = users[index].data() as Map<String, dynamic>;
              return _buildUserCard(data, isDark, theme, users[index].id);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> data,
    bool isDark,
    ThemeData theme,
    String userId,
  ) {
    bool isActive = (data['status'] ?? 'active') == 'active';

    return GestureDetector(
      onTap: () {
        // Get.to(() => StoreProfileScreen(sellerId: userId));
      },
      child: Container(
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
              child:
                  (data['profileImage'] == null || data['profileImage'] == '')
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
                      const Icon(
                        CupertinoIcons.star_fill,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "5.0/5 Rating",
                        style: TextStyle(
                          fontSize: 12,
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
                  "${data['walletBalance'] ?? data['wallet_balance'] ?? 0} ฿",
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
      ),
    );
  }
}
