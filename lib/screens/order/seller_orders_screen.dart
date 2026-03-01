import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';

class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  void _confirmShipping(String orderId) {
    final trackingCtrl = TextEditingController();
    final theme = Theme.of(Get.context!);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.cube_box_fill,
                  color: Colors.blue,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "จัดส่งสินค้า",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "กรุณากรอกเลขพัสดุ (Tracking No.)\nเพื่อยืนยันการจัดส่งให้ลูกค้า",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: trackingCtrl,
                decoration: InputDecoration(
                  labelText: "เลขพัสดุ",
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "ปิด",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (trackingCtrl.text.isEmpty) {
                          Get.snackbar(
                            "แจ้งเตือน",
                            "กรุณากรอกเลขพัสดุ",
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                          );
                          return;
                        }
                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId)
                            .update({
                              'status': 'shipping',
                              'trackingNumber': trackingCtrl.text.trim(),
                            });
                        Get.back();
                        Get.snackbar(
                          "สำเร็จ",
                          "อัปเดตสถานะเป็นกำลังจัดส่งแล้ว",
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ยืนยันจัดส่ง",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            "สถานะการขาย",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Get.back(),
          ),
          bottom: TabBar(
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            labelColor: AppTheme.primaryColor,
            indicatorColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[400],
            labelStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.normal,
              fontSize: 15,
            ),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: "ต้องจัดส่ง"),
              Tab(text: "กำลังจัดส่ง"),
              Tab(text: "ประวัติการขาย"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(user?.uid ?? '', 'pending'),
            _buildOrderList(user?.uid ?? '', 'shipping'),
            _buildOrderList(user?.uid ?? '', 'history'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(String sellerId, String tabType) {
    final theme = Theme.of(Get.context!);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? '';
          if (tabType == 'history') {
            return status == 'completed' || status == 'cancelled';
          }
          return status == tabType;
        }).toList();

        docs.sort((a, b) {
          Timestamp? tA = (a.data() as Map<String, dynamic>)['createdAt'];
          Timestamp? tB = (b.data() as Map<String, dynamic>)['createdAt'];
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.doc_text_search,
                  size: 80,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
                const SizedBox(height: 15),
                Text(
                  "ไม่มีรายการคำสั่งซื้อ",
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            List items = data['items'] ?? [];
            var address = data['shippingAddress'] ?? {};
            String currentStatus = data['status'] ?? '';

            String statusText = "";
            Color statusColor = AppTheme.primaryColor;
            Color bgColor = AppTheme.primaryColor.withOpacity(0.1);

            if (currentStatus == 'pending') {
              statusText = "ต้องจัดส่ง";
              statusColor = Colors.orange;
              bgColor = Colors.orange.withOpacity(0.1);
            } else if (currentStatus == 'shipping') {
              statusText = "กำลังจัดส่ง";
              statusColor = Colors.blue;
              bgColor = Colors.blue.withOpacity(0.1);
            } else if (currentStatus == 'completed') {
              statusText = "จัดส่งสำเร็จ";
              statusColor = Colors.green;
              bgColor = Colors.green.withOpacity(0.1);
            } else if (currentStatus == 'cancelled') {
              statusText = "ยกเลิกแล้ว";
              statusColor = Colors.red;
              bgColor = Colors.red.withOpacity(0.1);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.person_solid,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${address['name'] ?? address['receiver_name'] ?? 'ไม่ระบุชื่อ'} | ${address['phone'] ?? ''}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),

                  if (currentStatus == 'pending' || currentStatus == 'shipping')
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            CupertinoIcons.location_solid,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${address['address_detail']} ${address['sub_district']} ${address['district']} ${address['province']} ${address['postcode']}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "โทร: ${address['phone'] ?? '-'}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              image:
                                  (item['image'] != null && item['image'] != '')
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    decoration: currentStatus == 'cancelled'
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "ไซส์: ${item['size'] ?? '-'} | นน: ${item['weight'] ?? 0}g",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
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
                                  fontSize: 14,
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

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "จัดส่งโดย: ${data['shippingMethod']}",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                const Text(
                                  "ยอดรับสุทธิ: ",
                                  style: TextStyle(fontSize: 13),
                                ),
                                Text(
                                  "${data['total']} ฿",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: currentStatus == 'cancelled'
                                        ? Colors.grey
                                        : AppTheme.primaryColor,
                                    decoration: currentStatus == 'cancelled'
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (currentStatus == 'pending') ...[
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmShipping(doc.id),
                              icon: const Icon(
                                CupertinoIcons.cube_box,
                                color: Colors.white,
                                size: 18,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              label: const Text(
                                "จัดส่งสินค้า (กรอกเลขพัสดุ)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (currentStatus == 'shipping' ||
                            currentStatus == 'completed') ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.car_detailed,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "เลขพัสดุ: ${data['trackingNumber']}",
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
