import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'buyer_order_detail_screen.dart';

class BuyerOrdersScreen extends StatelessWidget {
  const BuyerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            "การสั่งซื้อของฉัน",
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: StreamBuilder<QuerySnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                      .collection('orders')
                      .where('buyerId', isEqualTo: user.uid)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                int pendingCount = 0;
                int shippingCount = 0;

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    String status = doc.get('status') ?? '';
                    if (status == 'pending') pendingCount++;
                    if (status == 'shipping') shippingCount++;
                  }
                }

                return TabBar(
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  labelColor: AppTheme.primaryColor,
                  indicatorColor: AppTheme.primaryColor,
                  unselectedLabelColor:
                      isDark ? Colors.grey[500] : Colors.grey[400],
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
                  tabs: [
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("รอจัดส่ง"),
                            if (pendingCount > 0) ...[
                              const SizedBox(width: 4),
                              Badge(
                                label: Text(pendingCount.toString()),
                                backgroundColor: Colors.orange,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("กำลังจัดส่ง"),
                            if (shippingCount > 0) ...[
                              const SizedBox(width: 4),
                              Badge(
                                label: Text(shippingCount.toString()),
                                backgroundColor: Colors.blue,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("สำเร็จ"),
                      ),
                    ),
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("ยกเลิกแล้ว"),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(user?.uid ?? '', 'pending'),
            _buildOrderList(user?.uid ?? '', 'shipping'),
            _buildOrderList(user?.uid ?? '', 'completed'),
            _buildOrderList(user?.uid ?? '', 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(String buyerId, String status) {
    final theme = Theme.of(Get.context!);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('buyerId', isEqualTo: buyerId)
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
          return data['status'] == status;
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

            var firstItem = items.isNotEmpty ? items.first : {};

            String statusText = "";
            Color statusColor = AppTheme.primaryColor;
            Color bgColor = AppTheme.primaryColor.withOpacity(0.1);

            if (status == 'pending') {
              statusText = "ที่ต้องจัดส่ง";
              statusColor = Colors.orange;
              bgColor = Colors.orange.withOpacity(0.1);
            } else if (status == 'shipping') {
              statusText = "กำลังจัดส่ง";
              statusColor = Colors.blue;
              bgColor = Colors.blue.withOpacity(0.1);
            } else if (status == 'completed') {
              statusText = "จัดส่งสำเร็จ";
              statusColor = Colors.green;
              bgColor = Colors.green.withOpacity(0.1);
            } else if (status == 'cancelled') {
              statusText = "ยกเลิกแล้ว";
              statusColor = Colors.red;
              bgColor = Colors.red.withOpacity(0.1);
            }

            return GestureDetector(
              onTap: () {
                Get.to(
                  () =>
                      BuyerOrderDetailScreen(orderId: doc.id, orderData: data),
                );
              },
              child: Container(
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
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.house_alt,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${data['sellerName'] ?? 'ไม่ระบุ'}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
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

                    Padding(
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
                                  (firstItem['image'] != null &&
                                      firstItem['image'] != '')
                                  ? DecorationImage(
                                      image: NetworkImage(firstItem['image']),
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
                                  firstItem['name'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "ไซส์: ${firstItem['size'] ?? '-'}",
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
                                "${firstItem['price'] ?? 0} ฿",
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

                    if (items.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          "ดูสินค้าอีก ${items.length - 1} ชิ้น...",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    if (items.length > 1) const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${items.length} ชิ้น",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                "ยอดสุทธิ: ",
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                "${data['total']} ฿",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: AppTheme.primaryColor,
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
  }
}
