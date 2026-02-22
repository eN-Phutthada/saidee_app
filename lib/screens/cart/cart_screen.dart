import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import '../../widgets/guest_view.dart';
import '../store/store_profile_screen.dart';
import '../product/product_detail_screen.dart';
import '../../models/product_model.dart';

class CartScreen extends StatefulWidget {
  final bool showBackButton;
  const CartScreen({super.key, this.showBackButton = false});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Set<String> _selectedCartIds = {};
  bool _isEditing = false;

  void _toggleItemSelection(String docId) {
    setState(() {
      if (_selectedCartIds.contains(docId)) {
        _selectedCartIds.remove(docId);
      } else {
        _selectedCartIds.add(docId);
      }
    });
  }

  void _toggleShopSelection(
    List<QueryDocumentSnapshot> shopItems,
    bool isSelected,
  ) {
    setState(() {
      for (var doc in shopItems) {
        if (isSelected) {
          _selectedCartIds.add(doc.id);
        } else {
          _selectedCartIds.remove(doc.id);
        }
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedCartIds.isEmpty) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    for (String docId in _selectedCartIds) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(docId)
          .delete();
    }

    Get.back();

    setState(() {
      _selectedCartIds.clear();
      _isEditing = false;
    });
    Get.snackbar(
      "ลบสำเร็จ",
      "ลบสินค้าออกจากตะกร้าแล้ว",
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) return const GuestView();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final cartItems = snapshot.hasData ? snapshot.data!.docs : [];

        Map<String, List<QueryDocumentSnapshot>> groupedCart = {};
        for (var doc in cartItems) {
          String sellerId = doc['sellerId'] ?? 'unknown';
          if (groupedCart[sellerId] == null) groupedCart[sellerId] = [];
          groupedCart[sellerId]!.add(doc);
        }

        double totalPrice = 0;
        for (var doc in cartItems) {
          if (_selectedCartIds.contains(doc.id)) {
            totalPrice += (doc['price'] ?? 0).toDouble();
          }
        }

        bool isAllSelected =
            _selectedCartIds.length == cartItems.length && cartItems.isNotEmpty;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: true,
            leading: widget.showBackButton
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Get.back(),
                  )
                : null,
            title: Text(
              "ตะกร้าช้อปปิ้ง (${cartItems.length})",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (cartItems.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                  child: Text(
                    _isEditing ? "เสร็จสิ้น" : "แก้ไข",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),

          body: Column(
            children: [
              Expanded(
                child: cartItems.isEmpty
                    ? Center(
                        child: Text(
                          "ไม่มีสินค้าในตะกร้า",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: groupedCart.keys.length,
                        itemBuilder: (context, index) {
                          String sellerId = groupedCart.keys.elementAt(index);
                          List<QueryDocumentSnapshot> shopItems =
                              groupedCart[sellerId]!;

                          bool isShopSelected = shopItems.every(
                            (doc) => _selectedCartIds.contains(doc.id),
                          );
                          double shopTotal = 0;
                          for (var doc in shopItems) {
                            if (_selectedCartIds.contains(doc.id))
                              shopTotal += (doc['price'] ?? 0).toDouble();
                          }

                          return _buildShopGroup(
                            sellerId,
                            shopItems,
                            isShopSelected,
                            shopTotal,
                            theme,
                            isDark,
                          );
                        },
                      ),
              ),

              if (cartItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
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
                              "${_selectedCartIds.length} ชิ้น",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            if (!_isEditing)
                              RichText(
                                text: TextSpan(
                                  text: "ยอดชำระทั้งหมด ",
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                      text:
                                          "${totalPrice.toStringAsFixed(0)} ฿",
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                "เลือกสินค้าเพื่อลบ",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isAllSelected,
                                  activeColor: _isEditing
                                      ? Colors.red
                                      : AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedCartIds.addAll(
                                          cartItems.map((e) => e.id),
                                        );
                                      } else {
                                        _selectedCartIds.clear();
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  "เลือกทั้งหมด",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 150,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _selectedCartIds.isEmpty
                                    ? null
                                    : (_isEditing
                                          ? _deleteSelectedItems
                                          : () {
                                              // TODO: ไปหน้า Checkout
                                            }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isEditing
                                      ? Colors.red
                                      : AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  disabledBackgroundColor: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[400],
                                ),
                                child: Text(
                                  _isEditing ? "ลบสินค้า" : "ชำระตอนนี้",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildShopGroup(
    String sellerId,
    List<QueryDocumentSnapshot> items,
    bool isShopSelected,
    double shopTotal,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE8F5E9),
          child: Row(
            children: [
              Checkbox(
                value: isShopSelected,
                activeColor: _isEditing ? Colors.red : AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) => _toggleShopSelection(items, val ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      Get.to(() => StoreProfileScreen(sellerId: sellerId)),
                  child: Container(
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.house_alt, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(sellerId)
                                .get(),
                            builder: (context, snapshot) {
                              String shopName = "กำลังโหลด...";
                              if (snapshot.hasData && snapshot.data!.exists) {
                                shopName =
                                    snapshot.data!['name'] ?? 'ไม่ระบุชื่อร้าน';
                              }
                              return Text(
                                shopName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              );
                            },
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        ...items.map((doc) => _buildCartItem(doc, theme, isDark)),

        if (!_isEditing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ค่าจัดส่ง",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "จะถูกคำนวณในขั้นตอนต่อไป",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ยอดรวมสินค้า",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "${shopTotal.toStringAsFixed(0)} ฿",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        Divider(
          thickness: 8,
          color: isDark ? Colors.black : Colors.grey[200],
          height: 8,
        ),
      ],
    );
  }

  Widget _buildCartItem(
    QueryDocumentSnapshot doc,
    ThemeData theme,
    bool isDark,
  ) {
    bool isSelected = _selectedCartIds.contains(doc.id);
    var data = doc.data() as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 20, top: 15, bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: _isEditing ? Colors.red : AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (val) => _toggleItemSelection(doc.id),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                Get.dialog(
                  const Center(child: CircularProgressIndicator()),
                  barrierDismissible: false,
                );
                try {
                  var prodDoc = await FirebaseFirestore.instance
                      .collection('products')
                      .doc(data['productId'])
                      .get();
                  Get.back();

                  if (prodDoc.exists) {
                    ProductModel product = ProductModel.fromMap(
                      prodDoc.data() as Map<String, dynamic>,
                      prodDoc.id,
                    );
                    Get.to(() => ProductDetailScreen(product: product));
                  } else {
                    Get.snackbar(
                      "แจ้งเตือน",
                      "ขออภัย ไม่พบสินค้านี้ (อาจถูกลบไปแล้ว)",
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                } catch (e) {
                  Get.back();
                }
              },
              child: Container(
                color: Colors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 110,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        image: (data['image'] != null && data['image'] != '')
                            ? DecorationImage(
                                image: NetworkImage(data['image']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (data['image'] == null || data['image'] == '')
                          ? const Icon(CupertinoIcons.photo, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['brand']?.isNotEmpty == true
                                ? data['brand']
                                : 'ไม่ระบุแบรนด์',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['name'] ?? 'ไม่มีชื่อสินค้า',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['size'] ?? '-',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${data['price'] ?? 0} ฿",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
