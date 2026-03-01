import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class BuyerOrderDetailScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const BuyerOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  Future<void> _cancelOrder(BuildContext context, double totalAmount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    AppDialog.showCustomDialog(
      title: "ยกเลิกคำสั่งซื้อ",
      message:
          "คุณแน่ใจหรือไม่ที่จะยกเลิกคำสั่งซื้อนี้?\nเงินจะถูกคืนเข้าวอลเล็ททันที",
      icon: CupertinoIcons.xmark_circle_fill,
      iconColor: Colors.red,
      confirmText: "ยืนยัน",
      cancelText: "ปิด",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();
        _performCancel(user.uid, totalAmount);
      },
    );
  }

  Future<void> _performCancel(String uid, double totalAmount) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);
      batch.update(orderRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(totalAmount),
      });

      DocumentReference txRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc();
      batch.set(txRef, {
        'uid': uid,
        'type': 'refund',
        'amount': totalAmount,
        'order_id': orderId,
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      List items = orderData['items'] ?? [];
      for (var item in items) {
        String productId = item['productId'];
        DocumentReference productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(productId);
        batch.update(productRef, {'status': 'active'});
      }

      await batch.commit();

      Get.back();
      Get.back();
      Get.snackbar(
        "สำเร็จ",
        "ยกเลิกคำสั่งซื้อและคืนเงินเรียบร้อย",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถยกเลิกได้ กรุณาลองใหม่",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    List items = orderData['items'] ?? [];
    var address = orderData['shippingAddress'] ?? {};
    String status = orderData['status'] ?? 'pending';

    String statusTitle = "กำลังดำเนินการ";
    String statusDesc = "รอผู้ขายจัดเตรียมและส่งสินค้า";
    Color headerColor = Colors.orange;
    IconData headerIcon = CupertinoIcons.time;

    if (status == 'shipping') {
      statusTitle = "กำลังจัดส่ง";
      statusDesc = "ผู้ขายได้จัดส่งสินค้าให้คุณแล้ว";
      headerColor = Colors.blue;
      headerIcon = CupertinoIcons.cube_box;
    } else if (status == 'completed') {
      statusTitle = "จัดส่งสำเร็จ";
      statusDesc = "คำสั่งซื้อเสร็จสมบูรณ์";
      headerColor = Colors.green;
      headerIcon = CupertinoIcons.checkmark_seal_fill;
    } else if (status == 'cancelled') {
      statusTitle = "ยกเลิกแล้ว";
      statusDesc = "คำสั่งซื้อถูกยกเลิกแล้ว";
      headerColor = Colors.red;
      headerIcon = CupertinoIcons.xmark_circle;
    }

    Timestamp? ts = orderData['createdAt'];
    String orderDate = "-";
    if (ts != null) {
      DateTime d = ts.toDate();
      orderDate =
          "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "รายละเอียดคำสั่งซื้อ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(
              statusTitle,
              statusDesc,
              headerColor,
              headerIcon,
            ),

            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  if (status == 'shipping' || status == 'completed')
                    _buildTrackingCard(theme, isDark, orderData),

                  _buildAddressCard(theme, isDark, address),

                  _buildItemsCard(theme, isDark, items),

                  _buildPaymentSummaryCard(theme, isDark, orderData),

                  _buildOrderInfoCard(theme, isDark, orderDate),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: (status == 'pending')
          ? _buildBottomAction(context, theme, isDark)
          : null,
    );
  }

  Widget _buildStatusHeader(
    String title,
    String desc,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(color: color),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 50),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingCard(ThemeData theme, bool isDark, Map data) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.car_detailed, color: Colors.blue),
              SizedBox(width: 10),
              Text(
                "ข้อมูลการจัดส่ง",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "จัดส่งโดย: ${data['shippingMethod'] ?? 'ไม่ระบุ'}",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                "เลขพัสดุ: ",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              SelectableText(
                "${data['trackingNumber'] ?? '-'}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(ThemeData theme, bool isDark, Map address) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.location_solid, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text(
                "ที่อยู่จัดส่ง",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "${address['name'] ?? address['receiver_name'] ?? 'ไม่ระบุชื่อ'} | ${address['phone'] ?? ''}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            "${address['address_detail']} ${address['sub_district']} ${address['district']} ${address['province']} ${address['postcode']}",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(ThemeData theme, bool isDark, List items) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.house_alt,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  "ร้าน: ${orderData['sellerName'] ?? 'ไม่ระบุ'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      image: (item['image'] != null && item['image'] != '')
                          ? DecorationImage(
                              image: NetworkImage(item['image']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "ไซส์: ${item['size'] ?? '-'}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${item['price']} ฿",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(ThemeData theme, bool isDark, Map data) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            "ยอดรวมสินค้า",
            "${data['subtotal']} ฿",
            theme,
            isDark,
          ),
          _buildSummaryRow(
            "ค่าจัดส่ง",
            "${data['shippingFee']} ฿",
            theme,
            isDark,
          ),
          if ((data['discount'] ?? 0) > 0)
            _buildSummaryRow(
              "ส่วนลด",
              "-${data['discount']} ฿",
              theme,
              isDark,
              color: Colors.red,
            ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ยอดชำระสุทธิ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "${data['total']} ฿",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(ThemeData theme, bool isDark, String date) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow("หมายเลขคำสั่งซื้อ", orderId, theme, isDark),
          _buildSummaryRow("เวลาที่สั่งซื้อ", date, theme, isDark),
          _buildSummaryRow("ช่องทางชำระเงิน", "SAIDEE Wallet", theme, isDark),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () =>
                _cancelOrder(context, (orderData['total'] ?? 0).toDouble()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "ยกเลิกคำสั่งซื้อ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String value,
    ThemeData theme,
    bool isDark, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
