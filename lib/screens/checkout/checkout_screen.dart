import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/order/buyer_orders_screen.dart';
import 'package:saidee_app/screens/profile/add_address_screen.dart';
import 'package:saidee_app/screens/checkout/promptpay_checkout_payment_screen.dart';
import 'package:saidee_app/services/notification_service.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class CheckoutShopGroup {
  final String sellerId;
  final String sellerName;
  final List<Map<String, dynamic>> items;
  final List<String> cartDocIds;
  final double totalWeight;
  final double itemsTotal;
  final List<Map<String, dynamic>> availableShippings;
  Map<String, dynamic>? selectedShipping;

  CheckoutShopGroup({
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.cartDocIds,
    required this.totalWeight,
    required this.itemsTotal,
    required this.availableShippings,
    this.selectedShipping,
  });
}

class CheckoutScreen extends StatefulWidget {
  final List<String> selectedCartIds;
  const CheckoutScreen({super.key, required this.selectedCartIds});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;

  String _selectedPaymentMethod = 'wallet';

  double _walletBalance = 0.0;
  List<CheckoutShopGroup> _shopGroups = [];
  Map<String, dynamic>? _selectedAddress;

  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  double _discountAmount = 0.0;

  double _itemsTotalAll = 0.0;
  double _shippingTotalAll = 0.0;
  double _grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  Future<void> _loadCheckoutData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        var uData = userDoc.data()!;
        _walletBalance =
            (uData['walletBalance'] ?? uData['wallet_balance'] ?? 0).toDouble();
      }

      var addressSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .orderBy('is_default', descending: true)
          .limit(1)
          .get();

      if (addressSnap.docs.isNotEmpty) {
        var data = addressSnap.docs.first.data();
        String fullAddress =
            "${data['address_detail']} ${data['sub_district']} ${data['district']} ${data['province']} ${data['postcode']}";

        data['name'] = data['receiver_name'];
        data['address'] = fullAddress;
        _selectedAddress = data;
      }

      var cartSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .get();
      var selectedCartDocs = cartSnap.docs
          .where((doc) => widget.selectedCartIds.contains(doc.id))
          .toList();

      Map<String, List<DocumentSnapshot>> tempGroups = {};
      for (var doc in selectedCartDocs) {
        String sId = doc['sellerId'] ?? 'unknown';
        if (tempGroups[sId] == null) tempGroups[sId] = [];
        tempGroups[sId]!.add(doc);
      }

      var shippingSnap = await FirebaseFirestore.instance
          .collection('shipping')
          .where('status', isEqualTo: 'active')
          .get();
      List<Map<String, dynamic>> allShippings = shippingSnap.docs
          .map((e) => {'id': e.id, ...e.data()})
          .toList();

      List<CheckoutShopGroup> loadedGroups = [];
      double tempItemsTotalAll = 0;

      for (var sellerId in tempGroups.keys) {
        var cartDocs = tempGroups[sellerId]!;
        var sellerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .get();
        String sellerName = "ไม่ระบุชื่อร้าน";
        List<String> enabledShipping = [];

        if (sellerDoc.exists) {
          sellerName = sellerDoc.data()!['name'] ?? sellerName;
          if (sellerDoc.data()!['enabled_shipping'] != null) {
            enabledShipping = List<String>.from(
              sellerDoc.data()!['enabled_shipping'],
            );
          }
        }

        double shopWeight = 0;
        double shopItemsTotal = 0;
        List<Map<String, dynamic>> shopItems = [];
        List<String> shopCartIds = [];

        for (var cDoc in cartDocs) {
          var cData = cDoc.data() as Map<String, dynamic>;
          shopWeight += (cData['weight'] ?? 0).toDouble();
          shopItemsTotal += (cData['price'] ?? 0).toDouble();
          shopItems.add(cData);
          shopCartIds.add(cDoc.id);
        }

        tempItemsTotalAll += shopItemsTotal;

        List<Map<String, dynamic>> validShippings = allShippings.where((s) {
          double wMin = (s['weight_min'] ?? 0).toDouble();
          double wMax = (s['weight_max'] ?? 0).toDouble();
          return enabledShipping.contains(s['name']) &&
              shopWeight >= wMin &&
              shopWeight <= wMax;
        }).toList();

        validShippings.sort(
          (a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0),
        );

        loadedGroups.add(
          CheckoutShopGroup(
            sellerId: sellerId,
            sellerName: sellerName,
            items: shopItems,
            cartDocIds: shopCartIds,
            totalWeight: shopWeight,
            itemsTotal: shopItemsTotal,
            availableShippings: validShippings,
            selectedShipping: validShippings.isNotEmpty
                ? validShippings.first
                : null,
          ),
        );
      }

      setState(() {
        _shopGroups = loadedGroups;
        _itemsTotalAll = tempItemsTotalAll;
        _calculateGrandTotal();
        _isLoading = false;
      });
    } catch (e) {
      Get.back();
      AppDialog.showCustomDialog(
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถโหลดข้อมูลตะกร้าสินค้าได้ กรุณาลองใหม่อีกครั้ง",
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    }
  }

  void _calculateGrandTotal() {
    _shippingTotalAll = 0.0;
    for (var group in _shopGroups) {
      if (group.selectedShipping != null) {
        _shippingTotalAll += (group.selectedShipping!['price'] ?? 0).toDouble();
      }
    }

    _discountAmount = 0.0;
    if (_appliedCoupon != null) {
      double value = (_appliedCoupon!['value'] ?? 0).toDouble();
      if (_appliedCoupon!['type'] == 'percent') {
        _discountAmount = _itemsTotalAll * (value / 100);
      } else {
        _discountAmount = value;
      }
    }

    _grandTotal = _itemsTotalAll + _shippingTotalAll - _discountAmount;
    if (_grandTotal < 0) _grandTotal = 0;
  }

  Future<void> _applyCoupon() async {
    String code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      var snap = await FirebaseFirestore.instance
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      Get.back();

      if (snap.docs.isEmpty) {
        AppDialog.showCustomDialog(
          title: "ไม่พบโค้ดส่วนลด",
          message: "โค้ดส่วนลดนี้ไม่มีในระบบ หรืออาจหมดอายุไปแล้ว",
          icon: CupertinoIcons.ticket_fill,
          iconColor: Colors.red,
          confirmText: "ตกลง",
          onConfirm: () => Get.back(),
        );
        return;
      }

      var couponData = snap.docs.first.data();
      double minOrder = (couponData['min_order'] ?? 0).toDouble();

      if (couponData['end_date'] != null) {
        DateTime endDate = (couponData['end_date'] as Timestamp).toDate();
        // ให้คูปองหมดอายุในเวลา 23:59:59 ของวันที่กำหนด
        endDate = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        if (DateTime.now().isAfter(endDate)) {
          AppDialog.showCustomDialog(
            title: "ไม่สามารถใช้โค้ดได้",
            message: "โค้ดส่วนลดนี้หมดอายุแล้ว",
            icon: CupertinoIcons.exclamationmark_circle_fill,
            iconColor: Colors.red,
            confirmText: "ตกลง",
            onConfirm: () => Get.back(),
          );
          return;
        }
      }

      if (couponData['start_date'] != null) {
        DateTime startDate = (couponData['start_date'] as Timestamp).toDate();
        startDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          0,
          0,
          0,
        );
        if (DateTime.now().isBefore(startDate)) {
          AppDialog.showCustomDialog(
            title: "ไม่สามารถใช้โค้ดได้",
            message: "โค้ดส่วนลดนี้ยังไม่ถึงเวลาเริ่มใช้งาน",
            icon: CupertinoIcons.exclamationmark_circle_fill,
            iconColor: Colors.orange,
            confirmText: "ตกลง",
            onConfirm: () => Get.back(),
          );
          return;
        }
      }

      if (_itemsTotalAll < minOrder) {
        AppDialog.showCustomDialog(
          title: "ไม่สามารถใช้โค้ดได้",
          message: "โค้ดส่วนลดนี้ต้องมียอดสั่งซื้อสินค้าขั้นต่ำ $minOrder บาท",
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: Colors.orange,
          confirmText: "ตกลง",
          onConfirm: () => Get.back(),
        );
        return;
      }

      setState(() {
        _appliedCoupon = couponData;
        _calculateGrandTotal();
      });
      FocusScope.of(context).unfocus();

      AppDialog.showCustomDialog(
        title: "ใช้โค้ดสำเร็จ",
        message: "คุณได้รับส่วนลดเรียบร้อยแล้ว",
        icon: CupertinoIcons.checkmark_seal_fill,
        iconColor: Colors.green,
        confirmText: "เยี่ยมเลย",
        onConfirm: () => Get.back(),
      );
    } catch (e) {
      Get.back();
      AppDialog.showCustomDialog(
        title: "ข้อผิดพลาด",
        message: "เกิดข้อผิดพลาดในการตรวจสอบคูปอง กรุณาลองใหม่",
        icon: CupertinoIcons.xmark_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
      _calculateGrandTotal();
    });
  }

  void _showAddressManager() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "เลือกที่อยู่จัดส่ง",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(CupertinoIcons.add, size: 16),
                    label: const Text("เพิ่มที่อยู่ใหม่"),
                    onPressed: () {
                      Get.back();
                      Get.to(() => const AddAddressScreen());
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('addresses')
                    .orderBy('is_default', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "คุณยังไม่มีที่อยู่จัดส่ง กรุณาเพิ่มที่อยู่ใหม่",
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var data =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                      bool isSelected =
                          _selectedAddress?['address_detail'] ==
                          data['address_detail'];

                      String fullAddress =
                          "${data['address_detail']} ${data['sub_district']} ${data['district']} ${data['province']} ${data['postcode']}";

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            CupertinoIcons.location_solid,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey,
                          ),
                          title: Text(
                            "${data['receiver_name']} | ${data['phone']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (data['is_default'] == true)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "ค่าเริ่มต้น",
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryColor,
                                )
                              : null,
                          tileColor: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.05)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedAddress = Map<String, dynamic>.from(
                                data,
                              );
                              _selectedAddress!['name'] = data['receiver_name'];
                              _selectedAddress!['address'] = fullAddress;
                            });
                            Get.back();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showConfirmationDialog() {
    if (_selectedAddress == null) {
      AppDialog.showCustomDialog(
        title: "กรุณาเลือกที่อยู่",
        message: "คุณจำเป็นต้องระบุที่อยู่สำหรับจัดส่งสินค้าก่อนทำการชำระเงิน",
        icon: CupertinoIcons.location_solid,
        iconColor: Colors.orange,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    bool hasError = false;
    for (var group in _shopGroups) {
      if (group.selectedShipping == null) hasError = true;
    }
    if (hasError) {
      AppDialog.showCustomDialog(
        title: "ไม่สามารถจัดส่งได้",
        message:
            "บางร้านค้าในตะกร้าของคุณไม่รองรับการจัดส่งน้ำหนักนี้ กรุณาแก้ไขตะกร้าสินค้าก่อนทำรายการ",
        icon: CupertinoIcons.cube_box_fill,
        iconColor: Colors.orange,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    if (_selectedPaymentMethod == 'promptpay_qr') {
      Get.to(
        () => PromptPayCheckoutPaymentScreen(
          grandTotal: _grandTotal,
          shopGroups: _shopGroups,
          selectedAddress: _selectedAddress,
          discountAmount: _discountAmount,
          appliedCoupon: _appliedCoupon,
          itemsTotalAll: _itemsTotalAll,
        ),
      );
      return;
    }

    if (_walletBalance < _grandTotal) {
      AppDialog.showCustomDialog(
        title: "ยอดเงินไม่เพียงพอ",
        message: "กรุณาเติมเงินเข้า SAIDEE Wallet ของคุณก่อนทำการชำระเงิน",
        icon: CupertinoIcons.money_dollar_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    double remainingBalance = _walletBalance - _grandTotal;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.shield_fill,
                  color: AppTheme.primaryColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 15),

              const Text(
                "ยืนยันการชำระเงิน",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                "กรุณาตรวจสอบยอดชำระก่อนยืนยันทำรายการ",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),

              Text(
                "${_grandTotal.toStringAsFixed(2)} ฿",
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow(
                      "ยอดเงินในวอลเล็ท",
                      "${_walletBalance.toStringAsFixed(2)} ฿",
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildReceiptRow(
                      "ยอดที่ต้องชำระ",
                      "-${_grandTotal.toStringAsFixed(2)} ฿",
                      isDark,
                      valueColor: Colors.red,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(height: 1),
                    ),
                    _buildReceiptRow(
                      "ยอดคงเหลือหลังชำระ",
                      "${remainingBalance.toStringAsFixed(2)} ฿",
                      isDark,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        "ยกเลิก",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _executePayment();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        shadowColor: AppTheme.primaryColor.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      child: const Text(
                        "ชำระเงิน",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
      isScrollControlled: true,
    );
  }

  Widget _buildReceiptRow(
    String title,
    String value,
    bool isDark, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isBold
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isDark ? Colors.white : Colors.black),
            fontSize: isBold ? 18 : 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _executePayment() async {
    setState(() => _isProcessing = true);
    final user = FirebaseAuth.instance.currentUser;
    final db = FirebaseFirestore.instance;

    try {
      WriteBatch batch = db.batch();

      DocumentReference userRef = db.collection('users').doc(user!.uid);
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(-_grandTotal),
      });

      DocumentReference txRef = db.collection('transactions').doc();
      batch.set(txRef, {
        'uid': user.uid,
        'type': 'purchase',
        'amount': _grandTotal,
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (var group in _shopGroups) {
        double shopTotal =
            group.itemsTotal +
            (group.selectedShipping!['price'] ?? 0).toDouble();

        double shopDiscount = 0.0;
        if (_discountAmount > 0 && _itemsTotalAll > 0) {
          shopDiscount = _discountAmount * (group.itemsTotal / _itemsTotalAll);
        }
        double finalShopTotal = shopTotal - shopDiscount;

        DocumentReference orderRef = db.collection('orders').doc();
        batch.set(orderRef, {
          'buyerId': user.uid,
          'sellerId': group.sellerId,
          'sellerName': group.sellerName,
          'shippingAddress': _selectedAddress,
          'items': group.items,
          'subtotal': group.itemsTotal,
          'shippingFee': group.selectedShipping!['price'],
          'shippingMethod': group.selectedShipping!['name'],
          'discount': shopDiscount,
          'couponCode': _appliedCoupon?['code'] ?? '',
          'total': finalShopTotal,
          'status': 'pending',
          'trackingNumber': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (var item in group.items) {
          DocumentReference prodRef = db
              .collection('products')
              .doc(item['productId']);
          batch.update(prodRef, {'status': 'sold'});
        }

        for (var cartId in group.cartDocIds) {
          DocumentReference cartRef = db
              .collection('users')
              .doc(user.uid)
              .collection('cart')
              .doc(cartId);
          batch.delete(cartRef);
        }
      }

      await batch.commit();

      NotificationService.sendNotification(
        userId: user.uid,
        title: "ชำระเงินสำเร็จแล้ว 💳",
        body:
            "คำสั่งซื้อยอด ${_grandTotal.toStringAsFixed(2)} ฿ ชำระผ่าน SAIDEE Wallet เรียบร้อยแล้ว",
        type: 'order',
      );

      for (var group in _shopGroups) {
        NotificationService.sendNotification(
          userId: group.sellerId,
          title: "มีคำสั่งซื้อใหม่เข้ามา! 📦",
          body:
              "ร้าน ${group.sellerName} มีคำสั่งซื้อใหม่ชำระเงินเรียบร้อยแล้ว กรุณาจัดเตรียมและจัดส่งสินค้า",
          type: 'order',
        );
      }

      AppDialog.showCustomDialog(
        title: "สั่งซื้อสำเร็จ!",
        message:
            "คำสั่งซื้อถูกส่งไปยังผู้ขายแล้ว\nระบบได้ทำการหักเงินจากวอลเล็ทของคุณเรียบร้อย",
        icon: CupertinoIcons.checkmark_alt_circle_fill,
        iconColor: Colors.green,
        confirmText: "ดูรายการคำสั่งซื้อ",
        onConfirm: () {
          Get.offAll(() => const HomeScreen());
          Get.to(() => const BuyerOrdersScreen());
        },
      );
    } catch (e) {
      AppDialog.showCustomDialog(
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถทำรายการสั่งซื้อได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง",
        icon: CupertinoIcons.xmark_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "ทำการสั่งซื้อ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showAddressManager,
                    child: Container(
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
                          Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue,
                                  Colors.red,
                                  Colors.blue,
                                  Colors.red,
                                  Colors.blue,
                                ],
                                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  CupertinoIcons.location_solid,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _selectedAddress == null
                                      ? const Text(
                                          "กรุณาเพิ่ม/เลือกที่อยู่จัดส่ง",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "ที่อยู่สำหรับจัดส่ง",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              "${_selectedAddress!['receiver_name'] ?? _selectedAddress!['name']} | ${_selectedAddress!['phone']}",
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedAddress!['address'] ??
                                                  "",
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[700],
                                                fontSize: 13,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ..._shopGroups.map((group) {
                    bool hasShipping = group.selectedShipping != null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A2F)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.house_alt,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  group.sellerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...group.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                      image:
                                          (item['image'] != null &&
                                              item['image'] != '')
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                item['image'],
                                              ),
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "ไซส์: ${item['size'] ?? '-'} | นน: ${item['weight'] ?? 0}g",
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${item['price'] ?? 0} ฿",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                          ),
                          Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: const Icon(
                                CupertinoIcons.cube_box,
                                color: Colors.blue,
                              ),
                              title: const Text(
                                "ตัวเลือกการจัดส่ง",
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: hasShipping
                                  ? Text(
                                      "${group.selectedShipping!['name']} (${group.totalWeight}g)",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    )
                                  : const Text(
                                      "ไม่รองรับน้ำหนัก",
                                      style: TextStyle(color: Colors.red),
                                    ),
                              trailing: Text(
                                hasShipping
                                    ? "${group.selectedShipping!['price']} ฿"
                                    : "-",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Text(
                    "โค้ดส่วนลด",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
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
                    child: _appliedCoupon == null
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _couponController,
                                  decoration: InputDecoration(
                                    hintText: "กรอกโค้ดส่วนลด",
                                    prefixIcon: const Icon(
                                      CupertinoIcons.ticket,
                                      color: Colors.orange,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _applyCoupon,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  "ใช้โค้ด",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.checkmark_seal_fill,
                                  color: Colors.green,
                                ),
                              ),
                              title: Text(
                                "ใช้โค้ด: ${_appliedCoupon!['code']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              subtitle: Text(
                                "ได้รับส่วนลด ${_discountAmount.toStringAsFixed(0)} บาท",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: _removeCoupon,
                                child: const Text(
                                  "นำออก",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "วิธีการชำระเงิน",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: SAIDEE Wallet
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedPaymentMethod = 'wallet');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'wallet'
                              ? AppTheme.primaryColor
                              : (isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!),
                          width: _selectedPaymentMethod == 'wallet' ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_selectedPaymentMethod == 'wallet'
                                        ? AppTheme.primaryColor
                                        : Colors.black)
                                    .withValues(alpha: isDark ? 0.2 : 0.05),
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
                          leading: Icon(
                            CupertinoIcons.creditcard_fill,
                            color: _selectedPaymentMethod == 'wallet'
                                ? AppTheme.primaryColor
                                : Colors.grey[500],
                          ),
                          title: const Text(
                            "SAIDEE Wallet",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "ยอดเงินคงเหลือ: ${_walletBalance.toStringAsFixed(2)} ฿",
                            style: TextStyle(
                              color: _walletBalance >= _grandTotal
                                  ? (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600])
                                  : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            _selectedPaymentMethod == 'wallet'
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            color: _selectedPaymentMethod == 'wallet'
                                ? AppTheme.primaryColor
                                : Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Option 2: PromptPay Dynamic QR
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedPaymentMethod = 'promptpay_qr');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'promptpay_qr'
                              ? AppTheme.primaryColor
                              : (isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!),
                          width: _selectedPaymentMethod == 'promptpay_qr'
                              ? 2
                              : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_selectedPaymentMethod == 'promptpay_qr'
                                        ? AppTheme.primaryColor
                                        : Colors.black)
                                    .withValues(alpha: isDark ? 0.2 : 0.05),
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
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF113566),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                "P",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          title: const Text(
                            "PromptPay Dynamic QR",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "สแกน QR Code ชำระตรง (ระบบคนกลาง Escrow ถือเงินปลอดภัย 100%)",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          trailing: Icon(
                            _selectedPaymentMethod == 'promptpay_qr'
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            color: _selectedPaymentMethod == 'promptpay_qr'
                                ? AppTheme.primaryColor
                                : Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ยอดรวมสินค้า",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        "${_itemsTotalAll.toStringAsFixed(0)} ฿",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ค่าจัดส่งรวม",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        "${_shippingTotalAll.toStringAsFixed(0)} ฿",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  if (_discountAmount > 0) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "ส่วนลดคูปอง",
                          style: TextStyle(color: Colors.red),
                        ),
                        Text(
                          "-${_discountAmount.toStringAsFixed(0)} ฿",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ยอดชำระสุทธิ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${_grandTotal.toStringAsFixed(0)} ฿",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed:
                          (_isProcessing ||
                              _walletBalance < _grandTotal ||
                              _selectedAddress == null)
                          ? null
                          : _showConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _walletBalance < _grandTotal
                                  ? "ยอดเงินไม่พอ"
                                  : "ยืนยันสั่งซื้อ",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
