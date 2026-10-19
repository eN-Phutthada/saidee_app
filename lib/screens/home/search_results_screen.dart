import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import '../../models/product_model.dart';
import '../product/product_detail_screen.dart';
import '../../services/role_guard_service.dart';

class SearchResultsScreen extends StatefulWidget {
  final String keyword;
  final List<String>? categories;
  final List<String>? types;
  final List<String>? sizes;
  final double? minPrice;
  final double? maxPrice;

  const SearchResultsScreen({
    super.key,
    required this.keyword,
    this.categories,
    this.types,
    this.sizes,
    this.minPrice,
    this.maxPrice,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final Map<String, bool> _sellerStatusCache = {};
  final Map<String, Map<String, String>> _sellerProfileCache = {};

  @override
  void initState() {
    super.initState();
    RoleGuardService.redirectIfAdmin(context);
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
          String status = (userData['status'] ?? 'active').toString().toLowerCase();
          _sellerStatusCache[sId] =
              (status != 'suspended' && status != 'banned');
          _sellerProfileCache[sId] = {
            'name': userData['name'] ?? 'ผู้ขาย',
            'profileImage': userData['profileImage'] ?? '',
          };
        } else {
          var adminDoc = await FirebaseFirestore.instance
              .collection('admins')
              .doc(sId)
              .get();
          if (adminDoc.exists) {
            var adminData = adminDoc.data() as Map<String, dynamic>;
            String status = (adminData['status'] ?? 'active').toString().toLowerCase();
            _sellerStatusCache[sId] =
                (status != 'suspended' && status != 'banned');
            _sellerProfileCache[sId] = {
              'name': adminData['name'] ?? 'ผู้ดูแลระบบ',
              'profileImage': adminData['profileImage'] ?? '',
            };
          } else {
            _sellerStatusCache[sId] = true;
            _sellerProfileCache[sId] = {
              'name': 'ร้านค้า',
              'profileImage': '',
            };
          }
        }
      } catch (e) {
        _sellerStatusCache[sId] = true;
        _sellerProfileCache[sId] = {
          'name': 'ร้านค้า',
          'profileImage': '',
        };
      }
    }

    for (var p in rawProducts) {
      String sId = (p.data() as Map<String, dynamic>)['sellerId'] ?? '';
      if (sId.isEmpty || _sellerStatusCache[sId] != false) {
        validProducts.add(p);
      }
    }

    return validProducts;
  }

  String get _appBarTitle {
    if (widget.keyword.isNotEmpty) {
      return "'${widget.keyword}'";
    }

    int catCount = widget.categories?.length ?? 0;
    int typeCount = widget.types?.length ?? 0;
    int sizeCount = widget.sizes?.length ?? 0;
    bool hasPrice = widget.minPrice != null || widget.maxPrice != null;

    int activeFilterGroups =
        (catCount > 0 ? 1 : 0) +
        (typeCount > 0 ? 1 : 0) +
        (sizeCount > 0 ? 1 : 0) +
        (hasPrice ? 1 : 0);

    if (activeFilterGroups == 0) return "สินค้าทั้งหมด";

    if (activeFilterGroups == 1) {
      if (catCount > 0) {
        return catCount == 1
            ? widget.categories!.first
            : "หมวดหมู่ ($catCount)";
      } else if (typeCount > 0) {
        return typeCount == 1 ? widget.types!.first : "ประเภท ($typeCount)";
      } else if (sizeCount > 0) {
        return sizeCount == 1
            ? "ไซส์: ${widget.sizes!.first}"
            : "หลายไซส์ ($sizeCount)";
      } else if (hasPrice) {
        if (widget.minPrice != null && widget.maxPrice != null) {
          return "ราคา: ${widget.minPrice!.toStringAsFixed(0)} - ${widget.maxPrice!.toStringAsFixed(0)} ฿";
        } else if (widget.minPrice != null) {
          return "ราคา: > ${widget.minPrice!.toStringAsFixed(0)} ฿";
        } else {
          return "ราคา: < ${widget.maxPrice!.toStringAsFixed(0)} ฿";
        }
      }
    }

    return "ผลลัพธ์การกรอง";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Query query = FirebaseFirestore.instance.collection('products');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildEmptyResult(theme, isDark);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyResult(theme, isDark);
          }

          var products = snapshot.data!.docs;

          products = products.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String status = (data['status'] ?? 'active').toString().toLowerCase();
            return status == 'active';
          }).toList();

          if (widget.categories != null && widget.categories!.isNotEmpty) {
            products = products.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String cat = data['category']?.toString() ?? '';
              return widget.categories!.contains(cat);
            }).toList();
          }

          if (widget.types != null && widget.types!.isNotEmpty) {
            products = products.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String t = data['type']?.toString() ?? '';
              return widget.types!.contains(t);
            }).toList();
          }

          if (widget.sizes != null && widget.sizes!.isNotEmpty) {
            products = products.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String s = data['size']?.toString() ?? '';
              return widget.sizes!.contains(s);
            }).toList();
          }

          if (widget.keyword.isNotEmpty) {
            final searchTerm = widget.keyword.toLowerCase();
            products = products.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String name = (data['name'] ?? '').toLowerCase();
              String brand = (data['brand'] ?? '').toLowerCase();
              return name.contains(searchTerm) || brand.contains(searchTerm);
            }).toList();
          }

          if (widget.minPrice != null || widget.maxPrice != null) {
            products = products.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              double price = (data['price'] ?? 0).toDouble();
              if (widget.minPrice != null && price < widget.minPrice!) return false;
              if (widget.maxPrice != null && price > widget.maxPrice!) return false;
              return true;
            }).toList();
          }

          if (products.isEmpty) {
            return _buildEmptyResult(theme, isDark);
          }

          return FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _filterValidProducts(products),
            builder: (context, filterSnapshot) {
              if (filterSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var validProducts = filterSnapshot.data ?? [];

              if (validProducts.isEmpty) {
                return _buildEmptyResult(theme, isDark);
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
                itemCount: validProducts.length,
                itemBuilder: (context, index) {
                  var doc = validProducts[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildProductCard(context, data, doc.id, isDark);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyResult(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 80,
            color: isDark ? Colors.grey[600] : Colors.grey[300],
          ),
          const SizedBox(height: 15),
          Text(
            "ไม่พบสินค้าที่คุณค้นหา",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "ลองเปลี่ยนคำค้นหา หรือเอาตัวกรองออก",
            style: TextStyle(color: Colors.grey[600]),
          ),
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : const Color(0xFFEEEEEE),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11.2),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.photo,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.photo,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name']?.isNotEmpty == true
                        ? data['name']
                        : (data['brand'] ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (data['size'] != null &&
                          data['size'].toString().isNotEmpty &&
                          data['size'] != '-') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "ไซส์ ${data['size']}",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (data['type'] != null &&
                          data['type'].toString().isNotEmpty)
                        Expanded(
                          child: Text(
                            data['type'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${data['price']} ฿",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      String sId = data['sellerId'] ?? '';
                      String sellerName = _sellerProfileCache[sId]?['name'] ?? 'ร้านค้า';
                      String sellerImg = _sellerProfileCache[sId]?['profileImage'] ?? '';
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 8.5,
                            backgroundImage: sellerImg.isNotEmpty
                                ? NetworkImage(sellerImg)
                                : null,
                            backgroundColor: isDark
                                ? Colors.grey[700]
                                : Colors.grey[300],
                            child: sellerImg.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 11,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
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
