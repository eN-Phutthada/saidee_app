import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/config/firestore_collections.dart';
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
  static final Map<String, bool> _globalSellerStatusCache = {};
  static final Map<String, Map<String, String>> _globalSellerProfileCache = {};

  bool _isLoading = true;
  String? _errorMessage;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _products = [];

  @override
  void initState() {
    super.initState();
    RoleGuardService.redirectIfAdmin(context);
    _loadSearchResults();
  }

  Future<void> _loadSearchResults({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.products)
          .where('status', isEqualTo: 'active')
          .limit(200)
          .get();

      var rawProducts = snapshot.docs;

      final filteredProducts = rawProducts.where((doc) {
        final data = doc.data();

        if (widget.categories != null && widget.categories!.isNotEmpty) {
          final cat = data['category']?.toString() ?? '';
          if (!widget.categories!.contains(cat)) return false;
        }

        if (widget.types != null && widget.types!.isNotEmpty) {
          final t = data['type']?.toString() ?? '';
          if (!widget.types!.contains(t)) return false;
        }

        if (widget.sizes != null && widget.sizes!.isNotEmpty) {
          final s = data['size']?.toString() ?? '';
          if (!widget.sizes!.contains(s)) return false;
        }

        if (widget.keyword.trim().isNotEmpty) {
          final searchTerm = widget.keyword.trim().toLowerCase();
          final name = (data['name'] ?? '').toString().toLowerCase();
          final brand = (data['brand'] ?? '').toString().toLowerCase();
          if (!name.contains(searchTerm) && !brand.contains(searchTerm)) {
            return false;
          }
        }

        if (widget.minPrice != null || widget.maxPrice != null) {
          final price = (data['price'] ?? 0).toDouble();
          if (widget.minPrice != null && price < widget.minPrice!) return false;
          if (widget.maxPrice != null && price > widget.maxPrice!) return false;
        }

        return true;
      }).toList();

      final sellerIds = <String>{};
      for (var doc in filteredProducts) {
        final sId = doc.data()['sellerId']?.toString() ?? '';
        if (sId.isNotEmpty) {
          sellerIds.add(sId);
        }
      }

      if (sellerIds.isNotEmpty) {
        await _batchFetchSellers(sellerIds);
      }

      final validProducts = filteredProducts.where((doc) {
        final sId = doc.data()['sellerId']?.toString() ?? '';
        return sId.isEmpty || _globalSellerStatusCache[sId] != false;
      }).toList();

      if (mounted) {
        setState(() {
          _products = validProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading search results: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "เกิดข้อผิดพลาดในการโหลดข้อมูลสินค้า";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _batchFetchSellers(Set<String> sellerIds) async {
    final toFetch = sellerIds
        .where((id) => !_globalSellerStatusCache.containsKey(id))
        .toList();

    if (toFetch.isEmpty) return;

    for (int i = 0; i < toFetch.length; i += 30) {
      final chunk = toFetch.sublist(
        i,
        i + 30 > toFetch.length ? toFetch.length : i + 30,
      );

      try {
        final usersSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        final foundIds = <String>{};
        for (var doc in usersSnap.docs) {
          foundIds.add(doc.id);
          final data = doc.data();
          final status = (data['status'] ?? 'active').toString().toLowerCase();
          _globalSellerStatusCache[doc.id] =
              (status != 'suspended' && status != 'banned');
          _globalSellerProfileCache[doc.id] = {
            'name': data['name'] ?? 'ผู้ขาย',
            'profileImage': data['profileImage'] ?? '',
          };
        }

        final missingIds = chunk.where((id) => !foundIds.contains(id)).toList();
        if (missingIds.isNotEmpty) {
          for (int j = 0; j < missingIds.length; j += 30) {
            final adminChunk = missingIds.sublist(
              j,
              j + 30 > missingIds.length ? missingIds.length : j + 30,
            );
            try {
              final adminsSnap = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.admins)
                  .where(FieldPath.documentId, whereIn: adminChunk)
                  .get();

              final adminFoundIds = <String>{};
              for (var doc in adminsSnap.docs) {
                adminFoundIds.add(doc.id);
                final data = doc.data();
                final status = (data['status'] ?? 'active')
                    .toString()
                    .toLowerCase();
                _globalSellerStatusCache[doc.id] =
                    (status != 'suspended' && status != 'banned');
                _globalSellerProfileCache[doc.id] = {
                  'name': data['name'] ?? 'ผู้ดูแลระบบ',
                  'profileImage': data['profileImage'] ?? '',
                };
              }

              for (var id in adminChunk) {
                if (!adminFoundIds.contains(id)) {
                  _globalSellerStatusCache[id] = true;
                  _globalSellerProfileCache[id] = {
                    'name': 'ร้านค้า',
                    'profileImage': '',
                  };
                }
              }
            } catch (e) {
              for (var id in adminChunk) {
                _globalSellerStatusCache[id] = true;
                _globalSellerProfileCache[id] = {
                  'name': 'ร้านค้า',
                  'profileImage': '',
                };
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error batch fetching sellers from users: $e");
        for (var id in chunk) {
          _globalSellerStatusCache[id] = true;
          _globalSellerProfileCache[id] = {
            'name': 'ร้านค้า',
            'profileImage': '',
          };
        }
      }
    }
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
      body: RefreshIndicator(
        onRefresh: () => _loadSearchResults(isRefresh: true),
        color: AppTheme.primaryColor,
        child: _buildBody(theme, isDark),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _products.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(child: _buildEmptyResult(theme, isDark))],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        var doc = _products[index];
        var data = doc.data();
        return _buildProductCard(context, data, doc.id, isDark);
      },
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
            _errorMessage ?? "ไม่พบสินค้าที่คุณค้นหา",
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
                          child: Icon(CupertinoIcons.photo, color: Colors.grey),
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
                      String sellerName =
                          _globalSellerProfileCache[sId]?['name'] ?? 'ร้านค้า';
                      String sellerImg =
                          _globalSellerProfileCache[sId]?['profileImage'] ?? '';
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
