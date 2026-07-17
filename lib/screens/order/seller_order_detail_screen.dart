import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/chat/chat_screen.dart';

class SellerOrderDetailScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const SellerOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty || text == '-') return;
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      "คัดลอกแล้ว",
      "คัดลอก $label เรียบร้อยแล้ว",
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    List items = orderData['items'] ?? [];
    var address = orderData['shippingAddress'] ?? {};
    String status = orderData['status'] ?? 'pending';

    String statusTitle = "ต้องจัดส่ง";
    String statusDesc = "กรุณาจัดส่งสินค้าให้ลูกค้าโดยเร็วที่สุด";
    Color headerColor = Colors.orange;
    IconData headerIcon = CupertinoIcons.time;

    if (status == 'shipping') {
      statusTitle = "กำลังจัดส่ง";
      statusDesc = "พัสดุกำลังเดินทางไปหาลูกค้า";
      headerColor = Colors.blue;
      headerIcon = CupertinoIcons.cube_box;
    } else if (status == 'completed') {
      statusTitle = "จัดส่งสำเร็จ";
      statusDesc = "ลูกค้าได้รับสินค้าเรียบร้อยแล้ว";
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
          "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} น.";
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(color: headerColor),
              child: Row(
                children: [
                  Icon(headerIcon, color: Colors.white, size: 50),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          statusDesc,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.person_solid,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "ข้อมูลผู้ซื้อ",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "${address['name'] ?? address['receiver_name']} | ${address['phone']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _copyToClipboard(
                                "${address['name']} ${address['phone']}",
                                "ข้อมูลติดต่อ",
                              ),
                              child: const Icon(
                                Icons.copy,
                                size: 18,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                "${address['address_detail']} ${address['sub_district']} ${address['district']} ${address['province']} ${address['postcode']}",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _copyToClipboard(
                                "${address['address_detail']} ${address['sub_district']} ${address['district']} ${address['province']} ${address['postcode']}",
                                "ที่อยู่",
                              ),
                              child: const Icon(
                                Icons.copy,
                                size: 18,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Divider(height: 1),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Get.to(
                                () => ChatScreen(
                                  targetUserId: orderData['buyerId'] ?? '',
                                  targetUserName:
                                      address['name'] ??
                                      address['receiver_name'] ??
                                      'ผู้ซื้อ',
                                  targetUserImage: '',
                                ),
                              );
                            },
                            icon: const Icon(
                              CupertinoIcons.chat_bubble_2_fill,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              "ทักแชตกับผู้ซื้อ (เจรจาเปลี่ยนสินค้า/สอบถาม)",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "จัดส่งผ่าน: ${orderData['shippingMethod']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        if (status == 'shipping' || status == 'completed') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text("เลขพัสดุ: "),
                              Text(
                                "${orderData['trackingNumber']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Text(
                            "สินค้าที่ต้องจัดส่ง (${items.length} ชิ้น)",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                        ),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                    image:
                                        (item['image'] != null &&
                                            item['image'] != '')
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "ไซส์: ${item['size'] ?? '-'}",
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${item['price']} ฿",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "x1",
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "รายละเอียดรายรับ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildSummaryRow(
                          "ค่าสินค้า",
                          "${orderData['subtotal']} ฿",
                          theme,
                          isDark,
                        ),
                        _buildSummaryRow(
                          "ค่าจัดส่งที่ได้รับ",
                          "${orderData['shippingFee']} ฿",
                          theme,
                          isDark,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "ยอดสุทธิที่จะได้รับ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "${orderData['total']} ฿",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 30),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          "หมายเลขคำสั่งซื้อ",
                          orderId,
                          theme,
                          isDark,
                        ),
                        _buildSummaryRow(
                          "เวลาสั่งซื้อ",
                          orderDate,
                          theme,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String value,
    ThemeData theme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
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
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
