import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/order/buyer_orders_screen.dart';
import 'package:saidee_app/screens/profile/add_address_screen.dart';
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
      Get.snackbar(
        "Error",
        "เกิดข้อผิดพลาดในการโหลดข้อมูล",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Get.back();
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
        Get.snackbar(
          "ไม่พบโค้ด",
          "โค้ดส่วนลดนี้ไม่มีในระบบ หรืออาจหมดอายุไปแล้ว",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      var couponData = snap.docs.first.data();
      double minOrder = (couponData['min_order'] ?? 0).toDouble();

      if (_itemsTotalAll < minOrder) {
        Get.snackbar(
          "ไม่สามารถใช้ได้",
          "โค้ดนี้ต้องมียอดซื้อสินค้าขั้นต่ำ $minOrder บาท",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      setState(() {
        _appliedCoupon = couponData;
        _calculateGrandTotal();
      });
      FocusScope.of(context).unfocus();
      Get.snackbar(
        "สำเร็จ",
        "ใช้โค้ดส่วนลดเรียบร้อยแล้ว",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        "Error",
        "เกิดข้อผิดพลาดในการตรวจสอบคูปอง",
        backgroundColor: Colors.red,
        colorText: Colors.white,
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

                      return ListTile(
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
                                  color: AppTheme.primaryColor.withOpacity(0.1),
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
                            ? AppTheme.primaryColor.withOpacity(0.05)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedAddress = Map<String, dynamic>.from(data);
                            _selectedAddress!['name'] = data['receiver_name'];
                            _selectedAddress!['address'] = fullAddress;
                          });
                          Get.back();
                        },
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
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณาเลือกที่อยู่สำหรับจัดส่ง",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    bool hasError = false;
    for (var group in _shopGroups) {
      if (group.selectedShipping == null) hasError = true;
    }
    if (hasError) {
      Get.snackbar(
        "แจ้งเตือน",
        "บางร้านค้าไม่รองรับการจัดส่งตามน้ำหนักนี้ กรุณาแก้ไขตะกร้าสินค้า",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (_walletBalance < _grandTotal) {
      Get.snackbar(
        "ยอดเงินไม่เพียงพอ",
        "กรุณาเติมเงินเข้าวอลเล็ทของคุณก่อนชำระเงิน",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    double remainingBalance = _walletBalance - _grandTotal;

    AppDialog.showCustomDialog(
      title: "ยืนยันการชำระเงิน",
      message:
          "ยอดที่ต้องชำระ: ${_grandTotal.toStringAsFixed(2)} ฿\nวอลเล็ทปัจจุบัน: ${_walletBalance.toStringAsFixed(2)} ฿\n\nยอดคงเหลือหลังชำระ: ${remainingBalance.toStringAsFixed(2)} ฿",
      icon: CupertinoIcons.checkmark_circle_fill,
      iconColor: AppTheme.primaryColor,
      confirmText: "ชำระเงิน",
      showCancel: true,
      onConfirm: () {
        Get.back();
        _executePayment();
      },
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
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถทำรายการได้",
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
                            color: Colors.black.withOpacity(
                              isDark ? 0.2 : 0.05,
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
                            color: Colors.black.withOpacity(
                              isDark ? 0.2 : 0.05,
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
                          ...group.items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey[800]
                                              : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                              )
                              .toList(),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                          ),
                          ListTile(
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
                        ],
                      ),
                    );
                  }).toList(),

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
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                        : ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
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
                  const SizedBox(height: 20),

                  const Text(
                    "วิธีการชำระเงิน",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _walletBalance >= _grandTotal
                            ? AppTheme.primaryColor
                            : Colors.red,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_walletBalance >= _grandTotal
                                      ? AppTheme.primaryColor
                                      : Colors.red)
                                  .withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Icon(
                        CupertinoIcons.creditcard_fill,
                        color: _walletBalance >= _grandTotal
                            ? AppTheme.primaryColor
                            : Colors.red,
                      ),
                      title: const Text(
                        "SAIDEE Wallet",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "ยอดเงินคงเหลือ: ${_walletBalance.toStringAsFixed(2)} ฿",
                        style: TextStyle(
                          color: _walletBalance >= _grandTotal
                              ? Colors.grey[600]
                              : Colors.red,
                        ),
                      ),
                      trailing: _walletBalance >= _grandTotal
                          ? const Icon(
                              CupertinoIcons.checkmark_alt_circle_fill,
                              color: AppTheme.primaryColor,
                            )
                          : const Text(
                              "เงินไม่พอ",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
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
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
