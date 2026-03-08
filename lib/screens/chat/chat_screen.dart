import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String targetUserImage;

  const ChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  late String chatRoomId;

  @override
  void initState() {
    super.initState();
    chatRoomId = _getChatRoomId(currentUserId, widget.targetUserId);
    _markMessagesAsRead();
  }

  String _getChatRoomId(String a, String b) {
    if (a.compareTo(b) > 0) {
      return '${a}_$b';
    } else {
      return '${b}_$a';
    }
  }

  Future<void> _markMessagesAsRead() async {
    var unreadDocs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.targetUserId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadDocs.docs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      var chatRoomRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId);
      batch.update(chatRoomRef, {'lastMessageRead': true});

      await batch.commit();
    }
  }

  Future<void> _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    var chatRoomRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId);
    var messagesRef = chatRoomRef.collection('messages').doc();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.set(messagesRef, {
      'senderId': currentUserId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    batch.set(chatRoomRef, {
      'users': [currentUserId, widget.targetUserId],
      'lastMessage': text,
      'lastSenderId': currentUserId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageRead': false,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.scaffoldBackgroundColor
          : const Color(0xFFF5F6F8),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: theme.cardColor,
        leadingWidth: 40,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.targetUserImage.isNotEmpty
                  ? NetworkImage(widget.targetUserImage)
                  : null,
              child: widget.targetUserImage.isEmpty
                  ? const Icon(CupertinoIcons.person_fill, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.targetUserName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "เชื่อมต่อแล้ว",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
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
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "ทักทายเพื่อเริ่มต้นการสนทนา",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 20,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var data = messages[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == currentUserId;
                    bool isRead = data['isRead'] ?? false;

                    Timestamp? ts = data['createdAt'];
                    String timeStr = "";
                    if (ts != null) {
                      timeStr = DateFormat('HH:mm').format(ts.toDate());
                    }

                    bool isFirstInGroup = true;
                    if (index < messages.length - 1) {
                      var prevData =
                          messages[index + 1].data() as Map<String, dynamic>;
                      if (prevData['senderId'] == data['senderId']) {
                        isFirstInGroup = false;
                      }
                    }

                    return _buildMessageBubble(
                      data['text'],
                      timeStr,
                      isMe,
                      isRead,
                      isFirstInGroup,
                      isDark,
                      theme,
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: EdgeInsets.only(
              left: 15,
              right: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
              top: 10,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: "พิมพ์ข้อความที่นี่...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primaryColor,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    String text,
    String time,
    bool isMe,
    bool isRead,
    bool isFirstInGroup,
    bool isDark,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isFirstInGroup ? 12 : 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isRead)
                  const Text(
                    "อ่านแล้ว",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  time,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  if (!isDark && !isMe)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),

          if (!isMe) ...[
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
