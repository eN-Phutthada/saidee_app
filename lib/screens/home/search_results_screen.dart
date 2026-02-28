import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import '../../models/product_model.dart';
import '../product/product_detail_screen.dart';

class SearchResultsScreen extends StatelessWidget {
  final String keyword;
  final String? category;
  final String? type;
  final String? size;

  const SearchResultsScreen({
    super.key,
    required this.keyword,
    this.category,
    this.type,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'active');

    if (category != null) query = query.where('category', isEqualTo: category);
    if (type != null) query = query.where('type', isEqualTo: type);
    if (size != null) query = query.where('size', isEqualTo: size);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "ผลลัพธ์การค้นหา",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
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
          if (keyword.isNotEmpty) {
            final searchTerm = keyword.toLowerCase();
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

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              var doc = products[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildProductCard(context, data, doc.id, isDark);
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

  // ใช้การ์ดหน้าตาเหมือนหน้า Home
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
