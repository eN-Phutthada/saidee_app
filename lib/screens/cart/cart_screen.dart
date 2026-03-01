import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/checkout/checkout_screen.dart';
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
  final Set<String> _selectedCartIds = {};
  bool _isEditing = false;

  Stream<QuerySnapshot>? _cartStream;
  final Map<String, Stream<DocumentSnapshot>> _productStreams = {};
  final Map<String, Stream<DocumentSnapshot>> _sellerStreams = {};
  final Map<String, bool> _availabilityCache = {};

  @override
  void initState() {
    super.initState();
    _initCartStream();
  }

  void _initCartStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _cartStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .orderBy('addedAt', descending: true)
          .snapshots();
    }
  }

  void _toggleItemSelection(String docId) {
    setState(() {
      if (_selectedCartIds.contains(docId)) {
        _selectedCartIds.remove(docId);
      } else {
        _selectedCartIds.add(docId);
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
    if (_cartStream == null) _initCartStream();

    return StreamBuilder<QuerySnapshot>(
      stream: _cartStream,
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

        int selectableCount = cartItems
            .where((doc) => _isEditing || _availabilityCache[doc.id] == true)
            .length;
        bool isAllSelected =
            selectableCount > 0 && _selectedCartIds.length == selectableCount;

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

                          var selectableShopItems = shopItems
                              .where(
                                (doc) =>
                                    _isEditing ||
                                    _availabilityCache[doc.id] == true,
                              )
                              .toList();
                          bool isShopSelected =
                              selectableShopItems.isNotEmpty &&
                              selectableShopItems.every(
                                (doc) => _selectedCartIds.contains(doc.id),
                              );

                          double shopTotal = 0;
                          for (var doc in shopItems) {
                            if (_selectedCartIds.contains(doc.id)) {
                              shopTotal += (doc['price'] ?? 0).toDouble();
                            }
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
                                        for (var e in cartItems) {
                                          if (_isEditing ||
                                              _availabilityCache[e.id] ==
                                                  true) {
                                            _selectedCartIds.add(e.id);
                                          }
                                        }
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
                                              Get.to(
                                                () => CheckoutScreen(
                                                  selectedCartIds:
                                                      _selectedCartIds.toList(),
                                                ),
                                              );
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
                onChanged: (val) {
                  setState(() {
                    for (var doc in items) {
                      if (val == true) {
                        if (_isEditing || _availabilityCache[doc.id] == true) {
                          _selectedCartIds.add(doc.id);
                        }
                      } else {
                        _selectedCartIds.remove(doc.id);
                      }
                    }
                  });
                },
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
    var data = doc.data() as Map<String, dynamic>;
    String productId = data['productId'] ?? '';
    String sellerId = data['sellerId'] ?? '';

    _productStreams[productId] ??= FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .snapshots();
    _sellerStreams[sellerId] ??= FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: _sellerStreams[sellerId],
      builder: (context, sellerSnap) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _productStreams[productId],
          builder: (context, prodSnapshot) {
            bool isAvailable = true;
            String unavailableReason = "";

            if (prodSnapshot.hasData) {
              if (!prodSnapshot.data!.exists) {
                isAvailable = false;
                unavailableReason = "สินค้านี้ถูกลบออกจากระบบแล้ว";
              } else {
                var pData = prodSnapshot.data!.data() as Map<String, dynamic>;
                if (pData['status'] != 'active') {
                  isAvailable = false;
                  unavailableReason = "สินค้าถูกขายไปแล้ว หรือหมดสต็อก";
                }
              }
            }

            if (isAvailable && sellerSnap.hasData) {
              if (!sellerSnap.data!.exists) {
                isAvailable = false;
                unavailableReason = "ไม่พบร้านค้านี้ในระบบ";
              } else {
                var sData = sellerSnap.data!.data() as Map<String, dynamic>;
                String sellerStatus = sData['status'] ?? 'active';
                if (sellerStatus == 'suspended' || sellerStatus == 'banned') {
                  isAvailable = false;
                  unavailableReason = "ร้านค้านี้ถูกระงับการใช้งาน";
                }
              }
            }

            _availabilityCache[doc.id] = isAvailable;
            bool isSelected = _selectedCartIds.contains(doc.id);

            if (!isAvailable && isSelected && !_isEditing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedCartIds.remove(doc.id);
                  });
                }
              });
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: DottedBorder(
                color: isAvailable
                    ? Colors.transparent
                    : Colors.orange.withOpacity(0.5),
                strokeWidth: 1.2,
                dashPattern: const [5, 4],
                borderType: BorderType.RRect,
                radius: const Radius.circular(15),
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 5,
                    right: 15,
                    top: 12,
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: isSelected,
                        activeColor: _isEditing
                            ? Colors.red
                            : AppTheme.primaryColor,
                        onChanged: (!isAvailable && !_isEditing)
                            ? null
                            : (val) => _toggleItemSelection(doc.id),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isAvailable && !_isEditing) {
                              _showCustomDialog(
                                title: "สินค้าไม่พร้อมจำหน่าย",
                                message:
                                    "$unavailableReason\nคุณต้องการลบออกจากตะกร้าหรือไม่?",
                                icon: CupertinoIcons.info_circle_fill,
                                iconColor: Colors.orange,
                                confirmText: "ลบออก",
                                isDestructive: true,
                                showCancel: true,
                                cancelText: "ปิด",
                                onConfirm: () async {
                                  Get.back();
                                  _selectedCartIds.add(doc.id);
                                  await _deleteSelectedItems();
                                },
                              );
                            } else {
                              _navigateToProductDetail(productId);
                            }
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                      image:
                                          (data['image'] != null &&
                                              data['image'] != '')
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                data['image'],
                                              ),
                                              fit: BoxFit.cover,
                                              colorFilter: !isAvailable
                                                  ? const ColorFilter.mode(
                                                      Colors.grey,
                                                      BlendMode.saturation,
                                                    )
                                                  : null,
                                            )
                                          : null,
                                    ),
                                    child:
                                        (data['image'] == null ||
                                            data['image'] == '')
                                        ? const Icon(
                                            CupertinoIcons.photo,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  if (!isAvailable)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: const Text(
                                              "ไม่พร้อมขาย",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['brand'] ?? 'ไม่ระบุแบรนด์',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data['name'] ?? '',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                (!isAvailable && !_isEditing)
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "ไซส์: ${data['size'] ?? '-'}",
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "${data['price'] ?? 0} ฿",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: (!isAvailable && !_isEditing)
                                            ? Colors.grey
                                            : null,
                                      ),
                                    ),
                                    if (!isAvailable && !_isEditing)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          unavailableReason,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _navigateToProductDetail(String productId) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      var prodDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      Get.back();
      if (prodDoc.exists) {
        ProductModel product = ProductModel.fromMap(
          prodDoc.data() as Map<String, dynamic>,
          prodDoc.id,
        );
        Get.to(() => ProductDetailScreen(product: product));
      }
    } catch (e) {
      Get.back();
    }
  }

  void _showCustomDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String confirmText,
    required VoidCallback onConfirm,
    bool showCancel = false,
    String cancelText = "ยกเลิก",
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
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
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 60),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  if (showCancel) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                          cancelText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDestructive
                            ? Colors.red
                            : AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
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
      barrierDismissible: true,
    );
  }
}
