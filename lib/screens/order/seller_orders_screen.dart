import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/order/seller_order_detail_screen.dart';
import 'package:saidee_app/screens/chat/chat_screen.dart';
import 'package:saidee_app/services/notification_service.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndAutoCompleteOrders();
  }

  Future<void> _checkAndAutoCompleteOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      var shippingOrdersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'shipping')
          .get();

      final now = DateTime.now();

      for (var doc in shippingOrdersSnap.docs) {
        var data = doc.data();

        Timestamp? ts = data['updatedAt'] ?? data['createdAt'];

        if (ts != null) {
          DateTime shippedDate = ts.toDate();

          if (now.difference(shippedDate).inDays >= 7) {
            double totalAmount = (data['total'] ?? 0).toDouble();
            WriteBatch batch = FirebaseFirestore.instance.batch();

            batch.update(doc.reference, {
              'status': 'completed',
              'updatedAt': FieldValue.serverTimestamp(),
              'autoCompleted': true,
            });

            DocumentReference sellerRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid);
            batch.update(sellerRef, {
              'walletBalance': FieldValue.increment(totalAmount),
            });

            DocumentReference txRef = FirebaseFirestore.instance
                .collection('transactions')
                .doc();
            batch.set(txRef, {
              'uid': user.uid,
              'type': 'income',
              'amount': totalAmount,
              'order_id': doc.id,
              'status': 'success',
              'note': 'Auto-completed',
              'createdAt': FieldValue.serverTimestamp(),
            });

            await batch.commit();
            debugPrint("Auto-completed order: ${doc.id}");
          }
        }
      }
    } catch (e) {
      debugPrint("Error auto-completing orders: $e");
    }
  }

  void _confirmShipping(String orderId, String shippingMethod) {
    final trackingCtrl = TextEditingController();
    final theme = Theme.of(Get.context!);
    final isDark = theme.brightness == Brightness.dark;

    int currentStep = 1;
    String finalTracking = "";

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentStep == 1
                      ? Column(
                          key: const ValueKey('step1'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
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
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "ผ่าน: $shippingMethod",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              "กรุณากรอกเลขพัสดุ (Tracking No.)\nเพื่อยืนยันการจัดส่งให้ลูกค้า",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: trackingCtrl,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: "เลขพัสดุ (ไม่มีเว้นวรรค)",
                                hintText: "เช่น TH0123456789",
                                hintStyle: const TextStyle(fontSize: 12),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey[300]!,
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
                                    onPressed: () {
                                      finalTracking = trackingCtrl.text
                                          .trim()
                                          .toUpperCase();

                                      if (finalTracking.isEmpty) {
                                        _showErrorDialog("กรุณากรอกเลขพัสดุ");
                                        return;
                                      }
                                      if (finalTracking.length < 10 ||
                                          finalTracking.length > 18) {
                                        _showErrorDialog(
                                          "เลขพัสดุมักจะมีความยาวระหว่าง 10-18 ตัวอักษร",
                                        );
                                        return;
                                      }
                                      if (!finalTracking.contains(
                                        RegExp(r'[0-9]'),
                                      )) {
                                        _showErrorDialog(
                                          "เลขพัสดุที่ไม่ถูกต้อง (ต้องมีตัวเลขประกอบ)",
                                        );
                                        return;
                                      }
                                      if (RegExp(
                                        r'^(.)\1+$',
                                      ).hasMatch(finalTracking)) {
                                        _showErrorDialog(
                                          "ไม่อนุญาตให้ใช้ตัวอักษรซ้ำกันทั้งหมด",
                                        );
                                        return;
                                      }

                                      setStateDialog(() {
                                        currentStep = 2;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "ถัดไป",
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
                        )
                      : Column(
                          key: const ValueKey('step2'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: Colors.orange,
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "ตรวจสอบความถูกต้อง",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "กรุณาตรวจสอบเลขพัสดุอีกครั้ง\nหากยืนยันแล้วจะไม่สามารถแก้ไขได้",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.blue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                finalTracking,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setStateDialog(() => currentStep = 1),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey[300]!,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      "แก้ไข",
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
                                      Get.back();
                                      Get.dialog(
                                        const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        barrierDismissible: false,
                                      );
                                      try {
                                        var orderDoc = await FirebaseFirestore
                                            .instance
                                            .collection('orders')
                                            .doc(orderId)
                                            .get();
                                        String buyerId =
                                            orderDoc.data()?['buyerId'] ?? '';

                                        await FirebaseFirestore.instance
                                            .collection('orders')
                                            .doc(orderId)
                                            .update({
                                              'status': 'shipping',
                                              'trackingNumber': finalTracking,
                                              'updatedAt':
                                                  FieldValue.serverTimestamp(),
                                            });

                                        if (buyerId.isNotEmpty) {
                                          NotificationService.sendNotification(
                                            userId: buyerId,
                                            title:
                                                "สินค้าของคุณถูกจัดส่งแล้ว! 🚚",
                                            body: "เลขพัสดุ: $finalTracking",
                                            type: 'order',
                                            orderId: orderId,
                                          );
                                        }

                                        Get.back();
                                        AppDialog.showCustomDialog(
                                          title: "สำเร็จ",
                                          message:
                                              "อัปเดตสถานะออเดอร์เป็น 'กำลังจัดส่ง' พร้อมเลขพัสดุเรียบร้อยแล้ว",
                                          icon: CupertinoIcons
                                              .check_mark_circled_solid,
                                          iconColor: Colors.green,
                                          confirmText: "ตกลง",
                                          onConfirm: () => Get.back(),
                                        );
                                      } catch (e) {
                                        Get.back();
                                        _showErrorDialog(
                                          "ไม่สามารถอัปเดตข้อมูลได้ กรุณาลองใหม่",
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "ยืนยัน",
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
          },
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showErrorDialog(String message) {
    AppDialog.showCustomDialog(
      title: "ข้อมูลไม่ถูกต้อง",
      message: message,
      icon: CupertinoIcons.exclamationmark_circle_fill,
      iconColor: Colors.red,
      confirmText: "เข้าใจแล้ว",
      onConfirm: () => Get.back(),
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: StreamBuilder<QuerySnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                        .collection('orders')
                        .where('sellerId', isEqualTo: user.uid)
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
                  unselectedLabelColor: isDark
                      ? Colors.grey[500]
                      : Colors.grey[400],
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("ต้องจัดส่ง"),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 6),
                            Badge(
                              label: Text(pendingCount.toString()),
                              backgroundColor: Colors.orange,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("กำลังจัดส่ง"),
                          if (shippingCount > 0) ...[
                            const SizedBox(width: 6),
                            Badge(
                              label: Text(shippingCount.toString()),
                              backgroundColor: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: "ประวัติการขาย"),
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
            _buildHistoryTab(user?.uid ?? ''),
          ],
        ),
      ),
    );
  }

  void _showSellerCancelDialog(String orderId, Map<String, dynamic> orderData) {
    TextEditingController reasonCtrl = TextEditingController();
    String selectedReason = "สินค้าหมด / สต็อกไม่พอ";

    Get.dialog(
      StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red),
                SizedBox(width: 10),
                Text(
                  "ยกเลิกคำสั่งซื้อ",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ระบุสาเหตุที่ต้องการยกเลิก (ระบบจะคืนเงินผู้ซื้อ 100% ทันที):",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "สินค้าหมด / สต็อกไม่พอ",
                        child: Text("สินค้าหมด / สต็อกไม่พอ"),
                      ),
                      DropdownMenuItem(
                        value: "สินค้าชำรุดมีตำหนิก่อนจัดส่ง",
                        child: Text("สินค้าชำรุดมีตำหนิก่อนจัดส่ง"),
                      ),
                      DropdownMenuItem(
                        value: "ไม่สะดวกจัดส่งตามกำหนด",
                        child: Text("ไม่สะดวกจัดส่งตามกำหนด"),
                      ),
                      DropdownMenuItem(value: "อื่นๆ", child: Text("อื่นๆ")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedReason = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (selectedReason == "อื่นๆ")
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        hintText: "อธิบายเหตุผลเพิ่มเติม",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () {
                      Get.back();
                      var address = orderData['shippingAddress'] ?? {};
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            CupertinoIcons.chat_bubble_2_fill,
                            color: Colors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "ทักแชตกับผู้ซื้อเพื่อเปลี่ยนสินค้า",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blue,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "ลองคุยเจรจาขอเปลี่ยนสี/รุ่นทดแทนก่อนยกเลิก",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text("ปิด")),
              ElevatedButton(
                onPressed: () async {
                  Get.back();
                  String reasonText = selectedReason == "อื่นๆ"
                      ? reasonCtrl.text.trim()
                      : selectedReason;
                  _executeSellerCancel(
                    orderId,
                    orderData,
                    reasonText.isEmpty ? selectedReason : reasonText,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "ยืนยันยกเลิกคำสั่งซื้อ",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeSellerCancel(
    String orderId,
    Map<String, dynamic> orderData,
    String reason,
  ) async {
    String buyerId = orderData['buyerId'] ?? '';
    double totalAmount = (orderData['total'] ?? 0).toDouble();

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
        'cancelReason': reason,
        'cancelledBy': 'seller',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (buyerId.isNotEmpty && totalAmount > 0) {
        DocumentReference buyerRef = FirebaseFirestore.instance
            .collection('users')
            .doc(buyerId);
        batch.update(buyerRef, {
          'walletBalance': FieldValue.increment(totalAmount),
        });

        DocumentReference txRef = FirebaseFirestore.instance
            .collection('transactions')
            .doc();
        batch.set(txRef, {
          'uid': buyerId,
          'type': 'refund',
          'amount': totalAmount,
          'order_id': orderId,
          'status': 'success',
          'note': 'ผู้ขายยกเลิกคำสั่งซื้อก่อนจัดส่ง: $reason',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      List items = orderData['items'] ?? [];
      for (var item in items) {
        String productId = item['productId'];
        DocumentReference productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(productId);
        batch.update(productRef, {'status': 'active'});
      }

      await batch.commit();

      if (buyerId.isNotEmpty) {
        NotificationService.sendNotification(
          userId: buyerId,
          title: "คำสั่งซื้อถูกยกเลิกโดยผู้ขาย ❌",
          body:
              "คำสั่งซื้อถูกยกเลิก (สาเหตุ: $reason) ยอดเงิน ${totalAmount.toStringAsFixed(2)} ฿ ได้ถูกคืนเข้า SAIDEE Wallet เรียบร้อยแล้ว",
          type: 'order',
          orderId: orderId,
        );
      }

      Get.back();

      AppDialog.showCustomDialog(
        title: "ยกเลิกคำสั่งซื้อสำเร็จ",
        message:
            "ยกเลิกคำสั่งซื้อเรียบร้อยแล้ว ระบบได้โอนเงินคืนเข้าวอลเล็ทของผู้ซื้อทันที",
        icon: CupertinoIcons.check_mark_circled_solid,
        iconColor: Colors.green,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    } catch (e) {
      Get.back();
      AppDialog.showCustomDialog(
        title: "ข้อผิดพลาด",
        message: "ไม่สามารถยกเลิกคำสั่งซื้อได้: $e",
        icon: CupertinoIcons.xmark_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    }
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
            Color bgColor = AppTheme.primaryColor.withValues(alpha: 0.1);

            if (currentStatus == 'pending') {
              statusText = "ต้องจัดส่ง";
              statusColor = Colors.orange;
              bgColor = Colors.orange.withValues(alpha: 0.1);
            } else if (currentStatus == 'shipping') {
              statusText = "กำลังจัดส่ง";
              statusColor = Colors.blue;
              bgColor = Colors.blue.withValues(alpha: 0.1);
            } else if (currentStatus == 'completed') {
              statusText = "จัดส่งสำเร็จ";
              statusColor = Colors.green;
              bgColor = Colors.green.withValues(alpha: 0.1);
            } else if (currentStatus == 'cancelled') {
              statusText = "ยกเลิกแล้ว";
              statusColor = Colors.red;
              bgColor = Colors.red.withValues(alpha: 0.1);
            }

            return GestureDetector(
              onTap: () => Get.to(
                () => SellerOrderDetailScreen(orderId: doc.id, orderData: data),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.05,
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

                    if (currentStatus == 'pending' ||
                        currentStatus == 'shipping')
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

                    if (items.isNotEmpty)
                      Padding(
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
                                    (items[0]['image'] != null &&
                                        items[0]['image'] != '')
                                    ? DecorationImage(
                                        image: NetworkImage(items[0]['image']),
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
                                    items[0]['name'] ?? '',
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
                                    "ไซส์: ${items[0]['size'] ?? '-'} | นน: ${items[0]['weight'] ?? 0}g",
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
                                  "${items[0]['price']} ฿",
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

                    if (items.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          "และสินค้าอื่นๆ อีก ${items.length - 1} ชิ้น",
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
                                          : Colors.green,
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
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _showSellerCancelDialog(doc.id, data),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      "สินค้ามีปัญหา / ยกเลิก",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _confirmShipping(
                                      doc.id,
                                      data['shippingMethod'] ?? 'ไม่ระบุ',
                                    ),
                                    icon: const Icon(
                                      CupertinoIcons.cube_box,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    label: const Text(
                                      "จัดส่งสินค้า",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (currentStatus == 'shipping' ||
                              currentStatus == 'completed') ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(String sellerId) {
    final theme = Theme.of(Get.context!);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'completed' || data['status'] == 'cancelled';
        }).toList();

        double totalRevenue = 0;
        int successCount = 0;

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'completed') {
            totalRevenue += (data['total'] ?? 0).toDouble();
            successCount++;
          }
        }

        docs.sort((a, b) {
          Timestamp? tA = (a.data() as Map<String, dynamic>)['createdAt'];
          Timestamp? tB = (b.data() as Map<String, dynamic>)['createdAt'];
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          "ยอดขายรวม (สำเร็จ)",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${totalRevenue.toStringAsFixed(0)} ฿",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          "จำนวนออเดอร์",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$successCount รายการ",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: docs.isEmpty
                  ? const Center(child: Text("ไม่มีประวัติการขาย"))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        bool isCancelled = data['status'] == 'cancelled';
                        List items = data['items'] ?? [];
                        var address = data['shippingAddress'] ?? {};

                        String firstItemName = items.isNotEmpty
                            ? items.first['name']
                            : 'สินค้า';
                        if (items.length > 1) {
                          firstItemName += ' (+${items.length - 1} ชิ้น)';
                        }
                        String imgUrl =
                            (items.isNotEmpty && items.first['image'] != null)
                            ? items.first['image']
                            : '';
                        String buyerName =
                            address['name'] ??
                            address['receiver_name'] ??
                            'ไม่ระบุชื่อ';

                        Timestamp? ts = data['createdAt'];
                        String orderDate = "-";
                        if (ts != null) {
                          DateTime d = ts.toDate();
                          orderDate =
                              "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}";
                        }

                        return GestureDetector(
                          onTap: () => Get.to(
                            () => SellerOrderDetailScreen(
                              orderId: doc.id,
                              orderData: data,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.2 : 0.05,
                                  ),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "วันที่: $orderDate",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCancelled
                                              ? Colors.red.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.green.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          isCancelled
                                              ? "ยกเลิกแล้ว"
                                              : "จัดส่งสำเร็จ",
                                          style: TextStyle(
                                            color: isCancelled
                                                ? Colors.red
                                                : Colors.green,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                ),

                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey[800]
                                              : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          image: imgUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(imgUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: imgUrl.isEmpty
                                            ? const Icon(
                                                Icons.image,
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              firstItemName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                decoration: isCancelled
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  CupertinoIcons.person_solid,
                                                  size: 12,
                                                  color: Colors.grey[500],
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    buyerName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 12,
                                                    ),
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

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "ยอดรับสุทธิ",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        "${data['total']} ฿",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: isCancelled
                                              ? Colors.grey
                                              : Colors.green,
                                          decoration: isCancelled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
