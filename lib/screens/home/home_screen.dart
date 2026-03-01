import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/login_screen.dart';
import 'package:saidee_app/screens/profile/profile_screen.dart';
import 'package:saidee_app/screens/cart/cart_screen.dart';
import 'package:saidee_app/screens/product/add_product_screen.dart';
import 'package:saidee_app/screens/product/product_detail_screen.dart';
import 'package:saidee_app/models/product_model.dart';
import 'search_screen.dart';
import 'search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const CartScreen(),
    const AddProductScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          if (userData['status'] == 'suspended' ||
              userData['status'] == 'banned') {
            await FirebaseAuth.instance.signOut();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Get.offAll(() => const LoginScreen());
              Get.snackbar(
                "บัญชีถูกระงับ",
                "บัญชีของคุณถูกระงับการใช้งาน กรุณาติดต่อผู้ดูแลระบบ",
                backgroundColor: Colors.red[800]!,
                colorText: Colors.white,
                icon: const Icon(CupertinoIcons.nosign, color: Colors.white),
                snackPosition: SnackPosition.TOP,
                duration: const Duration(seconds: 5),
              );
            });
          }
        }
      } catch (e) {
        debugPrint("Error checking user status: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              toolbarHeight: 80,
              leadingWidth: 70,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.search,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                  ),
                  onPressed: () => Get.to(() => const SearchScreen()),
                ),
              ),
              title: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'SAIDEE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.staatliches(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 3
                        ..color = Colors.pinkAccent,
                      shadows: const [
                        Shadow(
                          color: Colors.pinkAccent,
                          offset: Offset(6, 2.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'SAIDEE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.staatliches(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2.5
                        ..color = Colors.black,
                    ),
                  ),
                  Text(
                    'SAIDEE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.staatliches(
                      fontSize: 52,
                      letterSpacing: 1.2,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (user == null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilledButton.tonal(
                      onPressed: () => Get.to(() => const LoginScreen()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(60, 36),
                      ),
                      child: const Text(
                        "เข้าสู่ระบบ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.heart,
                          color: AppTheme.primaryColor,
                          size: 26,
                        ),
                      ),
                      onPressed: () {},
                    ),
                  ),
              ],
            )
          : null,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cart_fill),
            label: 'ตะกร้า',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.plus_circle),
            label: 'ขาย',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_fill),
            label: 'บัญชี',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final GlobalKey _productsSectionKey = GlobalKey();

  bool _isLoadingFilters = true;
  List<String> _displayTypes = [];
  List<String> _displayCategories = [];

  final Map<String, bool> _sellerStatusCache = {};

  @override
  void initState() {
    super.initState();
    _fetchDynamicFilters();
  }

  Future<void> _fetchDynamicFilters() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'active')
          .get();

      Set<String> typesSet = {};
      Set<String> categoriesSet = {};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data['type'] != null && data['type'].toString().isNotEmpty) {
          typesSet.add(data['type']);
        }
        if (data['category'] != null &&
            data['category'].toString().isNotEmpty) {
          categoriesSet.add(data['category']);
        }
      }

      List<String> types = typesSet.toList()..shuffle();
      List<String> categories = categoriesSet.toList()..shuffle();

      List<String> mockTypes = [
        'เสื้อยืด',
        'กางเกง',
        'รองเท้า',
        'หมวก',
        'กระเป๋า',
        'เครื่องประดับ',
      ];
      List<String> mockCategories = ['ผู้ชาย', 'ผู้หญิง', 'เด็ก', 'Unisex'];

      _displayTypes = types.take(4).toList();
      mockTypes.shuffle();
      for (var mock in mockTypes) {
        if (_displayTypes.length >= 4) break;
        if (!_displayTypes.contains(mock)) _displayTypes.add(mock);
      }

      _displayCategories = categories.take(2).toList();
      mockCategories.shuffle();
      for (var mock in mockCategories) {
        if (_displayCategories.length >= 2) break;
        if (!_displayCategories.contains(mock)) _displayCategories.add(mock);
      }

      if (mounted) setState(() => _isLoadingFilters = false);
    } catch (e) {
      _displayTypes = ['เสื้อยืด', 'กางเกง', 'รองเท้า', 'หมวก'];
      _displayCategories = ['ผู้ชาย', 'ผู้หญิง'];
      if (mounted) setState(() => _isLoadingFilters = false);
    }
  }

  void _scrollToProducts() {
    if (_productsSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _productsSectionKey.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<List<QueryDocumentSnapshot>> _filterValidProducts(
    List<QueryDocumentSnapshot> rawProducts,
  ) async {
    List<QueryDocumentSnapshot> validProducts = [];
    Set<String> sellersToFetch = {};

    for (var p in rawProducts) {
      String sId = (p.data() as Map<String, dynamic>)['sellerId'] ?? '';
      if (sId.isNotEmpty && !_sellerStatusCache.containsKey(sId)) {
        sellersToFetch.add(sId);
      }
    }

    for (String sId in sellersToFetch) {
      try {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sId)
            .get();
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          String status = userData['status'] ?? 'active';
          _sellerStatusCache[sId] =
              (status != 'suspended' && status != 'banned');
        } else {
          _sellerStatusCache[sId] = false;
        }
      } catch (e) {
        _sellerStatusCache[sId] = false;
      }
    }

    for (var p in rawProducts) {
      String sId = (p.data() as Map<String, dynamic>)['sellerId'] ?? '';
      if (_sellerStatusCache[sId] == true) {
        validProducts.add(p);
      }
    }

    return validProducts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }

              return MarqueeAnnouncement(
                announcements: snapshot.data!.docs,
                backgroundColor: isDark
                    ? Colors.grey[850]!
                    : const Color(0xFF4A4A4A),
              );
            },
          ),

          Stack(
            alignment: Alignment.center,
            children: [
              Image.network(
                'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=1000',
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(height: 220, color: Colors.black.withOpacity(0.3)),
              Column(
                children: [
                  const Text(
                    "เสื้อผ้ามือสอง สภาพมือหนึ่ง",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _scrollToProducts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      "ช็อปเลยตอนนี้",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_isLoadingFilters)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
              ),
              itemCount: _displayTypes.length,
              itemBuilder: (context, index) {
                return _CategoryTypeCard(
                  title: _displayTypes[index],
                  isCategory: false,
                );
              },
            ),

          const SizedBox(height: 25),

          if (!_isLoadingFilters) ...[
            const Text(
              "หมวดหมู่",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E5B3D),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                children: _displayCategories.map((catName) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: catName == _displayCategories.first ? 10 : 0,
                        left: catName == _displayCategories.last ? 10 : 0,
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.75,
                        child: _CategoryTypeCard(
                          title: catName,
                          isCategory: true,
                          showButton: false,
                          borderRadius: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 30),

          Text(
            "สินค้าแนะนำสำหรับคุณ",
            key: _productsSectionKey,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5B3D),
            ),
          ),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "ยังไม่มีสินค้าลงขาย",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              var rawProducts = snapshot.data!.docs;

              return FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _filterValidProducts(rawProducts),
                builder: (context, filterSnapshot) {
                  if (filterSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var validProducts = filterSnapshot.data ?? [];

                  if (validProducts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "ยังไม่มีสินค้าลงขาย",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  validProducts.sort((a, b) {
                    Timestamp? aTime =
                        (a.data() as Map<String, dynamic>)['createdAt'];
                    Timestamp? bTime =
                        (b.data() as Map<String, dynamic>)['createdAt'];
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  var topProducts = validProducts.take(10).toList();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                    itemCount: topProducts.length,
                    itemBuilder: (context, index) {
                      var doc = topProducts[index];
                      var data = doc.data() as Map<String, dynamic>;
                      return _buildProductCard(context, data, doc.id, isDark);
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    String? imageUrl =
        (data['images'] != null && (data['images'] as List).isNotEmpty)
        ? data['images'][0]
        : null;

    return GestureDetector(
      onTap: () {
        ProductModel product = ProductModel.fromMap(data, docId);
        Get.to(() => ProductDetailScreen(product: product));
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageUrl == null
                        ? const Center(
                            child: Icon(
                              CupertinoIcons.photo,
                              color: Colors.grey,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 14,
                      child: Icon(
                        CupertinoIcons.heart_fill,
                        size: 16,
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          data['name']?.isNotEmpty == true
                              ? data['name']
                              : (data['brand'] ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        "${data['price']}฿",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data['size'] ?? '-',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(data['sellerId'])
                        .get(),
                    builder: (context, snapshot) {
                      String sellerName = "ไม่ระบุ";
                      String sellerImg = "";
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        sellerName = userData['name'] ?? sellerName;
                        sellerImg = userData['profileImage'] ?? "";
                      }
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: sellerImg.isNotEmpty
                                ? NetworkImage(sellerImg)
                                : null,
                            backgroundColor: Colors.grey[300],
                            child: sellerImg.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 12,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTypeCard extends StatefulWidget {
  final String title;
  final bool isCategory;
  final bool showButton;
  final double borderRadius;

  const _CategoryTypeCard({
    required this.title,
    required this.isCategory,
    this.showButton = true,
    this.borderRadius = 0,
  });

  @override
  State<_CategoryTypeCard> createState() => _CategoryTypeCardState();
}

class _CategoryTypeCardState extends State<_CategoryTypeCard> {
  Future<String?>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _getBackgroundImage();
  }

  Future<String?> _getBackgroundImage() async {
    String field = widget.isCategory ? 'category' : 'type';
    var snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where(field, isEqualTo: widget.title)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      List images = snapshot.docs.first.data()['images'] ?? [];
      if (images.isNotEmpty) return images.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<String?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        String? bgImage = snapshot.data;

        return GestureDetector(
          onTap: () {
            Get.to(
              () => SearchResultsScreen(
                keyword: "",
                types: widget.isCategory ? null : [widget.title],
                categories: widget.isCategory ? [widget.title] : null,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                bgImage != null
                    ? Image.network(bgImage, fit: BoxFit.cover)
                    : Container(
                        color: isDarkTheme
                            ? Colors.grey[800]
                            : Colors.grey[300],
                      ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (widget.showButton) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 35,
                          child: ElevatedButton(
                            onPressed: () {
                              Get.to(
                                () => SearchResultsScreen(
                                  keyword: "",
                                  types: widget.isCategory
                                      ? null
                                      : [widget.title],
                                  categories: widget.isCategory
                                      ? [widget.title]
                                      : null,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkTheme
                                  ? Colors.black87
                                  : const Color(0xFF222222),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              "เลือกสินค้า ตอนนี้",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
  }
}

class MarqueeAnnouncement extends StatefulWidget {
  final List<QueryDocumentSnapshot> announcements;
  final Color backgroundColor;

  const MarqueeAnnouncement({
    super.key,
    required this.announcements,
    required this.backgroundColor,
  });

  @override
  State<MarqueeAnnouncement> createState() => _MarqueeAnnouncementState();
}

class _MarqueeAnnouncementState extends State<MarqueeAnnouncement> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        double speed = 40.0;
        double durationInSeconds = (maxScroll - currentScroll) / speed;

        if (durationInSeconds > 0) {
          await _scrollController.animateTo(
            maxScroll,
            duration: Duration(seconds: durationInSeconds.toInt()),
            curve: Curves.linear,
          );
        }
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    }
  }

  void _showAnnouncementSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.bell_fill,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "ประกาศข่าวสาร",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.announcements.length,
                itemBuilder: (context, index) {
                  var data =
                      widget.announcements[index].data()
                          as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey[200]!,
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
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
                              CupertinoIcons.circle_fill,
                              color: AppTheme.primaryColor,
                              size: 8,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                data['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Text(
                            data['detail'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String totalText = widget.announcements
        .map((doc) => (doc.data() as Map<String, dynamic>)['title'] ?? '')
        .join('      |      ');
    totalText = "$totalText      |      ";

    return GestureDetector(
      onTap: () => _showAnnouncementSheet(context),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          gradient: LinearGradient(
            colors: [
              widget.backgroundColor,
              widget.backgroundColor.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.backgroundColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              const SizedBox(width: 20),
              const Icon(
                CupertinoIcons.speaker_2_fill,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 12),
              Text(
                totalText + totalText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
