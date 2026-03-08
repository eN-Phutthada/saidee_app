import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("ข้อความ")),
        body: const Center(child: Text("กรุณาเข้าสู่ระบบ")),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "ข้อความ",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "เกิดข้อผิดพลาด",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.chat_bubble_text,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "ยังไม่มีการสนทนา",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            Timestamp? tA =
                (a.data() as Map<String, dynamic>)['lastMessageTime'];
            Timestamp? tB =
                (b.data() as Map<String, dynamic>)['lastMessageTime'];
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              indent: 80,
            ),
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;

              List users = data['users'] ?? [];
              String targetUserId = users.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => '',
              );

              String lastMessage = data['lastMessage'] ?? '';
              String lastSenderId = data['lastSenderId'] ?? '';
              bool isMeLast = lastSenderId == currentUser.uid;

              bool isRead = data['lastMessageRead'] ?? true;
              bool hasUnread = !isMeLast && !isRead;

              Timestamp? time = data['lastMessageTime'];
              String timeStr = _formatTime(time);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(targetUserId)
                    .get(),
                builder: (context, userSnap) {
                  String name = "กำลังโหลด...";
                  String img = "";

                  if (userSnap.hasData && userSnap.data!.exists) {
                    var uData = userSnap.data!.data() as Map<String, dynamic>;
                    name = uData['name'] ?? "ผู้ใช้งาน";
                    img = uData['profileImage'] ?? "";
                  }

                  return InkWell(
                    onTap: () {
                      Get.to(
                        () => ChatScreen(
                          targetUserId: targetUserId,
                          targetUserName: name,
                          targetUserImage: img,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            backgroundImage: img.isNotEmpty
                                ? NetworkImage(img)
                                : null,
                            child: img.isEmpty
                                ? const Icon(
                                    CupertinoIcons.person_fill,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: hasUnread
                                              ? FontWeight.w900
                                              : FontWeight.bold,
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: hasUnread
                                            ? AppTheme.primaryColor
                                            : Colors.grey[500],
                                        fontSize: 12,
                                        fontWeight: hasUnread
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isMeLast
                                            ? "คุณ: $lastMessage"
                                            : lastMessage,
                                        style: TextStyle(
                                          color: hasUnread
                                              ? theme.colorScheme.onSurface
                                              : (isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600]),
                                          fontSize: 14,
                                          fontWeight: hasUnread
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasUnread)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'เมื่อวาน';
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }
}
