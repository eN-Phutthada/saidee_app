import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/services/notification_service.dart';
import 'package:saidee_app/screens/order/buyer_order_detail_screen.dart';
import 'package:saidee_app/screens/order/seller_order_detail_screen.dart';
import 'package:saidee_app/screens/wallet/wallet_history_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "เมื่อสักครู่";
    DateTime date = (timestamp as Timestamp).toDate();
    DateTime now = DateTime.now();

    Duration diff = now.difference(date);
    if (diff.inSeconds < 60) return "เมื่อสักครู่";
    if (diff.inMinutes < 60) return "${diff.inMinutes} นาทีที่แล้ว";
    if (diff.inHours < 24) return "${diff.inHours} ชั่วโมงที่แล้ว";
    if (diff.inDays < 7) return "${diff.inDays} วันที่แล้ว";

    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  void _onNotificationTap(BuildContext context, String currentUserId, String notifId, Map<String, dynamic> data) async {
    NotificationService.markAsRead(currentUserId, notifId);

    String type = data['type'] ?? '';
    String orderId = data['orderId'] ?? '';

    if (type == 'wallet') {
      Get.to(() => const WalletHistoryScreen());
      return;
    }

    if (orderId.isNotEmpty) {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      try {
        var doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
        Get.back();

        if (doc.exists) {
          var orderData = doc.data() as Map<String, dynamic>;
          String buyerId = orderData['buyerId'] ?? '';

          if (currentUserId == buyerId) {
            Get.to(() => BuyerOrderDetailScreen(orderId: orderId, orderData: orderData));
          } else {
            Get.to(() => SellerOrderDetailScreen(orderId: orderId, orderData: orderData));
          }
        }
      } catch (e) {
        Get.back();
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'order':
        return CupertinoIcons.cube_box_fill;
      case 'wallet':
        return CupertinoIcons.money_dollar_circle_fill;
      case 'dispute':
        return CupertinoIcons.exclamationmark_shield_fill;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'order':
        return Colors.blue;
      case 'wallet':
        return Colors.green;
      case 'dispute':
        return Colors.red;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("การแจ้งเตือน")),
        body: const Center(child: Text("กรุณาเข้าสู่ระบบก่อนดูการแจ้งเตือน")),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "การแจ้งเตือน",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: () => NotificationService.markAllAsRead(user.uid),
            child: const Text(
              "อ่านทั้งหมด",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationService.getUserNotifications(user.uid),
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
                    CupertinoIcons.bell_slash,
                    size: 80,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "ไม่มีรายการแจ้งเตือน",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isRead = data['isRead'] ?? false;
              String type = data['type'] ?? 'system';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isRead
                      ? theme.cardColor
                      : (isDark
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : AppTheme.primaryColor.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(16),
                  border: isRead
                      ? null
                      : Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => _onNotificationTap(context, user.uid, doc.id, data),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getColorForType(type).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForType(type),
                        color: _getColorForType(type),
                        size: 22,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data['title'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          data['body'] ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTimestamp(data['createdAt']),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
