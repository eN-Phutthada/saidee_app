import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/order/seller_orders_screen.dart';
import 'package:saidee_app/screens/product/product_detail_screen.dart';
import 'package:saidee_app/screens/product/add_product_screen.dart';
import 'package:saidee_app/screens/store/seller_shipping_screen.dart';
import '../../models/product_model.dart';
import 'package:saidee_app/screens/chat/chat_screen.dart';

class StoreProfileScreen extends StatefulWidget {
  final String sellerId;

  const StoreProfileScreen({super.key, required this.sellerId});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool get isOwner => currentUserId == widget.sellerId;

  bool _isSellerBanned = false;
  bool _isLoadingSeller = true;

  String _filterStatus = 'all';
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _checkSellerStatus();
  }

  Future<void> _checkSellerStatus() async {
    try {
      var sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .get();
      if (sellerDoc.exists) {
        String status = sellerDoc.data()?['status'] ?? 'active';
        if (status == 'banned' || status == 'suspended') {
          setState(() => _isSellerBanned = true);
        }
      } else {
        setState(() => _isSellerBanned = true);
      }
    } catch (e) {
      debugPrint("Error checking seller status: $e");
    } finally {
      setState(() => _isLoadingSeller = false);
    }
  }

  Future<void> _shareStore() async {
    try {
      var sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .get();

      String storeName = "ร้านค้า";
      if (sellerDoc.exists) {
        storeName = sellerDoc.data()?['name'] ?? "ร้านค้า";
      }

      String shareText =
          "🛍️ แวะมาช้อปเสื้อผ้ามือสองสภาพดีที่ร้าน '$storeName' กันเถอะ!\n\n👉 เปิดแอป SAIDEE แล้วพิมพ์ชื่อร้านเพื่อเลือกซื้อสินค้าได้เลย!";

      await Share.share(shareText);
    } catch (e) {
      debugPrint("Error sharing store: $e");
      Get.snackbar("เกิดข้อผิดพลาด", "ไม่สามารถแชร์ร้านค้าได้ในขณะนี้");
    }
  }

  void _showStoreSettings() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String tempFilterStatus = _filterStatus;
    String tempSortBy = _sortBy;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 15,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ตั้งค่าการแสดงผล",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.tag_fill,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "สถานะสินค้า",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildCustomChip('ทั้งหมด', 'all', tempFilterStatus, (
                          val,
                        ) {
                          setModalState(() => tempFilterStatus = val);
                        }, isDark),
                        const SizedBox(width: 12),
                        _buildCustomChip(
                          'กำลังขาย',
                          'active',
                          tempFilterStatus,
                          (val) {
                            setModalState(() => tempFilterStatus = val);
                          },
                          isDark,
                        ),
                        const SizedBox(width: 12),
                        _buildCustomChip('ขายแล้ว', 'sold', tempFilterStatus, (
                          val,
                        ) {
                          setModalState(() => tempFilterStatus = val);
                        }, isDark),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1),
                  ),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up_arrow_down,
                          size: 16,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "เรียงลำดับตาม",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildCustomChip('อัปเดตล่าสุด', 'newest', tempSortBy, (
                        val,
                      ) {
                        setModalState(() => tempSortBy = val);
                      }, isDark),
                      _buildCustomChip('เก่าสุด', 'oldest', tempSortBy, (val) {
                        setModalState(() => tempSortBy = val);
                      }, isDark),
                      _buildCustomChip(
                        'ราคาสูง - ต่ำ',
                        'price_high',
                        tempSortBy,
                        (val) {
                          setModalState(() => tempSortBy = val);
                        },
                        isDark,
                      ),
                      _buildCustomChip(
                        'ราคาต่ำ - สูง',
                        'price_low',
                        tempSortBy,
                        (val) {
                          setModalState(() => tempSortBy = val);
                        },
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterStatus = tempFilterStatus;
                          _sortBy = tempSortBy;
                        });
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      child: const Text(
                        "แสดงผล",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  Widget _buildCustomChip(
    String label,
    String value,
    String groupValue,
    Function(String) onSelect,
    bool isDark,
  ) {
    bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingSeller) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Get.back(),
          ),
          title: Text(
            isOwner ? "การขาย" : "ร้านค้า",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (!_isSellerBanned)
              IconButton(
                icon: Icon(
                  CupertinoIcons.share,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: _shareStore,
              ),
            if (isOwner && !_isSellerBanned)
              IconButton(
                icon: Icon(
                  CupertinoIcons.slider_horizontal_3,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: _showStoreSettings,
              ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProfileCard(theme, isDark),
                    if (!_isSellerBanned) _buildActionButtons(theme, isDark),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  tabBar: TabBar(
                    labelColor: theme.colorScheme.onSurface,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: theme.colorScheme.onSurface,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    labelStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: "รายการสินค้า"),
                      Tab(text: "รีวิว"),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: _isSellerBanned
              ? _buildBannedMessage()
              : TabBarView(
                  children: [
                    _buildProductGrid(theme, isDark),
                    _buildReviews(theme, isDark),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBannedMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.nosign,
            size: 80,
            color: Colors.red.withOpacity(0.5),
          ),
          const SizedBox(height: 15),
          const Text(
            "ร้านค้านี้ถูกระงับการใช้งาน",
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "ไม่สามารถดูสินค้าหรือรีวิวของร้านค้านี้ได้",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ThemeData theme, bool isDark) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        String name = "ไม่ระบุชื่อ";
        String bio = "ส่งต่อเสื้อผ้าคุณภาพ";
        String profileImage = "";

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? name;
          bio = data['bio'] ?? bio;
          profileImage = data['profileImage'] ?? "";

          if (_isSellerBanned) {
            name = "ร้านค้านี้ถูกระงับการใช้งาน";
            bio = "-";
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                backgroundImage: (profileImage.isNotEmpty && !_isSellerBanned)
                    ? NetworkImage(profileImage)
                    : null,
                child: (profileImage.isEmpty || _isSellerBanned)
                    ? Icon(
                        _isSellerBanned ? CupertinoIcons.nosign : Icons.person,
                        size: 35,
                        color: _isSellerBanned ? Colors.red : Colors.grey,
                      )
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isSellerBanned ? Colors.red : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),

                    if (!_isSellerBanned) ...[
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('reviews')
                            .where('sellerId', isEqualTo: widget.sellerId)
                            .snapshots(),
                        builder: (context, reviewSnap) {
                          double avgRating = 5.0;
                          int reviewCount = 0;

                          if (reviewSnap.hasData &&
                              reviewSnap.data!.docs.isNotEmpty) {
                            reviewCount = reviewSnap.data!.docs.length;
                            double totalRating = 0;
                            for (var doc in reviewSnap.data!.docs) {
                              totalRating +=
                                  (doc.data()
                                      as Map<String, dynamic>)['rating'] ??
                                  5.0;
                            }
                            avgRating = totalRating / reviewCount;
                          }

                          return Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                reviewCount > 0
                                    ? "${avgRating.toStringAsFixed(1)} / 5 ($reviewCount รีวิว)"
                                    : "ยังไม่มีคะแนนรีวิว",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 6),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('products')
                            .where('sellerId', isEqualTo: widget.sellerId)
                            .snapshots(),
                        builder: (context, prodSnapshot) {
                          int count = prodSnapshot.hasData
                              ? prodSnapshot.data!.docs.length
                              : 0;
                          return Row(
                            children: [
                              const Icon(
                                CupertinoIcons.cube_box,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "สินค้าทั้งหมด $count รายการ",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          );
                        },
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
  }

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    if (!isOwner) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: _buildButtonContainer(
            "แชทกับร้านค้า",
            CupertinoIcons.chat_bubble_2,
            theme,
            isDark,
            () async {
              var sellerDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.sellerId)
                  .get();
              String sName = "ร้านค้า";
              String sImg = "";
              if (sellerDoc.exists) {
                sName = sellerDoc.data()?['name'] ?? "ร้านค้า";
                sImg = sellerDoc.data()?['profileImage'] ?? "";
              }
              Get.to(
                () => ChatScreen(
                  targetUserId: widget.sellerId,
                  targetUserName: sName,
                  targetUserImage: sImg,
                ),
              );
            },
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildButtonContainer(
              "เลือกขนส่ง",
              Icons.local_shipping_rounded,
              theme,
              isDark,
              () =>
                  Get.to(() => SellerShippingScreen(sellerId: widget.sellerId)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildButtonContainer(
              "สถานะการขาย",
              Icons.receipt_long_rounded,
              theme,
              isDark,
              () => Get.to(() => const SellerOrdersScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonContainer(
    String title,
    IconData icon,
    ThemeData theme,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.white,
                blurRadius: 10,
                offset: const Offset(-2, -2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(ThemeData theme, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: widget.sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("ยังไม่มีสินค้า", style: TextStyle(color: Colors.grey)),
          );
        }

        var products = snapshot.data!.docs.toList();

        if (_filterStatus != 'all') {
          products = products.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String pStatus = data['status'] ?? 'active';
            return pStatus == _filterStatus;
          }).toList();
        }

        if (products.isEmpty) {
          return Center(
            child: Text(
              _filterStatus == 'active'
                  ? "ไม่มีสินค้าที่กำลังขาย"
                  : "ไม่มีสินค้าที่ขายแล้ว",
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        products.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;

          if (_sortBy == 'newest' || _sortBy == 'oldest') {
            Timestamp? timeA = dataA['createdAt'];
            Timestamp? timeB = dataB['createdAt'];
            if (timeA == null || timeB == null) return 0;
            return _sortBy == 'newest'
                ? timeB.compareTo(timeA)
                : timeA.compareTo(timeB);
          } else {
            double priceA = (dataA['price'] ?? 0).toDouble();
            double priceB = (dataB['price'] ?? 0).toDouble();
            return _sortBy == 'price_high'
                ? priceB.compareTo(priceA)
                : priceA.compareTo(priceB);
          }
        });

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.55,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            var doc = products[index];
            var data = doc.data() as Map<String, dynamic>;
            ProductModel product = ProductModel.fromMap(data, doc.id);
            String imgUrl = product.images.isNotEmpty ? product.images[0] : '';

            int views = data['views'] ?? 0;
            bool isSold = data['status'] == 'sold';

            return GestureDetector(
              onTap: () => Get.to(() => ProductDetailScreen(product: product)),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                            child: imgUrl.isNotEmpty
                                ? Image.network(
                                    imgUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  )
                                : Container(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.image),
                                    ),
                                  ),
                          ),
                          if (isSold)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "ขายแล้ว",
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
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name.isNotEmpty
                                ? product.name
                                : product.brand,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${product.price.toStringAsFixed(0)} ฿",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.eye,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    views.toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              if (isOwner)
                                GestureDetector(
                                  onTap: () => Get.to(
                                    () => AddProductScreen(product: product),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.square_pencil_fill,
                                    size: 24,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey,
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

  Widget _buildReviews(ThemeData theme, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('sellerId', isEqualTo: widget.sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.star_circle,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 10),
                Text(
                  "ยังไม่มีรีวิว",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        var reviewDocs = snapshot.data!.docs;
        reviewDocs.sort((a, b) {
          Timestamp? tA = (a.data() as Map<String, dynamic>)['createdAt'];
          Timestamp? tB = (b.data() as Map<String, dynamic>)['createdAt'];
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          itemCount: reviewDocs.length,
          itemBuilder: (context, index) {
            var data = reviewDocs[index].data() as Map<String, dynamic>;
            int rating = data['rating'] ?? 5;
            String buyerId = data['buyerId'] ?? '';
            String orderId = data['orderId'] ?? '';
            String comment = data['comment'] ?? 'ไม่มีความคิดเห็น';

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(buyerId)
                        .get(),
                    builder: (context, userSnap) {
                      String buyerName = "ผู้ใช้ทั่วไป";
                      String buyerImg = "";

                      if (userSnap.hasData && userSnap.data!.exists) {
                        var uData =
                            userSnap.data!.data() as Map<String, dynamic>;
                        buyerName = uData['name'] ?? buyerName;
                        buyerImg = uData['profileImage'] ?? "";
                      }

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: buyerImg.isNotEmpty
                                ? NetworkImage(buyerImg)
                                : null,
                            child: buyerImg.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 15,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              buyerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (starIndex) => Icon(
                                starIndex < rating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    comment,
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (orderId.isNotEmpty)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderId)
                          .get(),
                      builder: (context, orderSnap) {
                        if (!orderSnap.hasData || !orderSnap.data!.exists)
                          return const SizedBox();
                        var oData =
                            orderSnap.data!.data() as Map<String, dynamic>;
                        List items = oData['items'] ?? [];
                        if (items.isEmpty) return const SizedBox();
                        var firstItem = items.first;

                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(5),
                                  image:
                                      (firstItem['image'] != null &&
                                          firstItem['image'] != '')
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            firstItem['image'],
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child:
                                    (firstItem['image'] == null ||
                                        firstItem['image'] == '')
                                    ? const Icon(
                                        Icons.image,
                                        size: 20,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      firstItem['name'] ?? 'ไม่มีชื่อสินค้า',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "ตัวเลือก: ${firstItem['size'] ?? '-'}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverAppBarDelegate({required this.tabBar, required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
