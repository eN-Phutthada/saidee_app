import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import '../../models/product_model.dart';
import '../product/product_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String keyword;
  final List<String>? categories;
  final List<String>? types;
  final List<String>? sizes;

  const SearchResultsScreen({
    super.key,
    required this.keyword,
    this.categories,
    this.types,
    this.sizes,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final Map<String, bool> _sellerStatusCache = {};

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

  String get _appBarTitle {
    if (widget.keyword.isNotEmpty) {
      return "'${widget.keyword}'";
    }

    int catCount = widget.categories?.length ?? 0;
    int typeCount = widget.types?.length ?? 0;
    int sizeCount = widget.sizes?.length ?? 0;

    int activeFilterGroups =
        (catCount > 0 ? 1 : 0) +
        (typeCount > 0 ? 1 : 0) +
        (sizeCount > 0 ? 1 : 0);

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
      }
    }

    return "ผลลัพธ์การกรอง";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'active');

    if (widget.categories != null && widget.categories!.isNotEmpty) {
      query = query.where('category', whereIn: widget.categories);
    }
    if (widget.types != null && widget.types!.isNotEmpty) {
      query = query.where('type', whereIn: widget.types);
    }
    if (widget.sizes != null && widget.sizes!.isNotEmpty) {
      query = query.where('size', whereIn: widget.sizes);
    }

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyResult(theme, isDark);
          }

          var products = snapshot.data!.docs;

          if (widget.keyword.isNotEmpty) {
            final searchTerm = widget.keyword.toLowerCase();
            products = products.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String name = (data['name'] ?? '').toLowerCase();
              String brand = (data['brand'] ?? '').toLowerCase();
              return name.contains(searchTerm) || brand.contains(searchTerm);
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
                padding: const EdgeInsets.all(15),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
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
              child: Container(
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
                        child: Icon(CupertinoIcons.photo, color: Colors.grey),
                      )
                    : null,
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
