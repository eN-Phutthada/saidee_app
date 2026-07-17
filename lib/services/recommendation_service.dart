import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/models/product_model.dart';

class ScoredProduct {
  final QueryDocumentSnapshot doc;
  final double score;
  final String badgeText;

  ScoredProduct({
    required this.doc,
    required this.score,
    required this.badgeText,
  });
}

class RecommendationService {
  /// Track when a user views a product
  static Future<void> trackProductView(String userId, ProductModel product) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      Map<String, dynamic> updateData = {};

      if (product.category.isNotEmpty) {
        updateData['viewedCategories.${product.category}'] = FieldValue.increment(1);
      }
      if (product.type.isNotEmpty) {
        updateData['viewedTypes.${product.type}'] = FieldValue.increment(1);
      }
      if (product.brand.isNotEmpty) {
        updateData['viewedBrands.${product.brand}'] = FieldValue.increment(1);
      }
      updateData['recentViewedIds'] = FieldValue.arrayUnion([product.id]);
      updateData['lastInteractedAt'] = FieldValue.serverTimestamp();

      await userRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error tracking product view: $e");
    }
  }

  /// Track when a user adds a product to cart
  static Future<void> trackCartAdd(String userId, ProductModel product) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      Map<String, dynamic> updateData = {};

      if (product.category.isNotEmpty) {
        updateData['viewedCategories.${product.category}'] = FieldValue.increment(3);
      }
      if (product.type.isNotEmpty) {
        updateData['viewedTypes.${product.type}'] = FieldValue.increment(3);
      }
      if (product.brand.isNotEmpty) {
        updateData['viewedBrands.${product.brand}'] = FieldValue.increment(2);
      }

      await userRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error tracking cart add: $e");
    }
  }

  /// Score and rank products based on user interests or global popularity/recency
  static Future<List<ScoredProduct>> getRecommendedProducts({
    required String? userId,
    required List<QueryDocumentSnapshot> rawProducts,
    int limit = 10,
  }) async {
    Map<String, dynamic> userInterests = {};

    if (userId != null && userId.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          userInterests = userDoc.data()!;
        }
      } catch (e) {
        debugPrint("Error loading user preferences for recommendations: $e");
      }
    }

    final Map<String, dynamic> viewedCategories = Map<String, dynamic>.from(userInterests['viewedCategories'] ?? {});
    final Map<String, dynamic> viewedTypes = Map<String, dynamic>.from(userInterests['viewedTypes'] ?? {});
    final Map<String, dynamic> viewedBrands = Map<String, dynamic>.from(userInterests['viewedBrands'] ?? {});

    bool hasPersonalizedData = viewedCategories.isNotEmpty || viewedTypes.isNotEmpty || viewedBrands.isNotEmpty;

    DateTime now = DateTime.now();
    List<ScoredProduct> scoredList = [];

    for (var doc in rawProducts) {
      var data = doc.data() as Map<String, dynamic>;
      String sellerId = data['sellerId'] ?? '';

      // Skip seller's own products if user is logged in
      if (userId != null && userId.isNotEmpty && sellerId == userId) {
        continue;
      }

      double score = 0.0;
      String badgeText = "";

      String category = data['category'] ?? '';
      String type = data['type'] ?? '';
      String brand = data['brand'] ?? '';
      int views = (data['views'] ?? 0) is int ? (data['views'] ?? 0) : ((data['views'] ?? 0) as num).toInt();
      Timestamp? createdAt = data['createdAt'];

      // 1. Popularity score (based on views)
      score += views * 1.5;

      // 2. Recency score (newer products get a boost up to 100 pts)
      if (createdAt != null) {
        double hoursDiff = now.difference(createdAt.toDate()).inHours.toDouble();
        double recencyScore = max(0, 100 - (hoursDiff * 0.5));
        score += recencyScore;
      }

      if (hasPersonalizedData) {
        double categoryCount = (viewedCategories[category] ?? 0).toDouble();
        double typeCount = (viewedTypes[type] ?? 0).toDouble();
        double brandCount = (viewedBrands[brand] ?? 0).toDouble();

        double categoryScore = categoryCount * 25.0;
        double typeScore = typeCount * 25.0;
        double brandScore = brandCount * 15.0;

        score += categoryScore + typeScore + brandScore;

        if (typeCount > 0 && typeCount >= categoryCount) {
          badgeText = "💡 แนะนำจากหมวด $type";
        } else if (categoryCount > 0) {
          badgeText = "✨ ตรงใจคุณ";
        } else if (brandCount > 0) {
          badgeText = "🏷️ แบรนด์ที่คุณชอบ";
        } else if (views >= 10) {
          badgeText = "🔥 ยอดนิยม";
        } else {
          badgeText = "✨ แนะนำสำหรับคุณ";
        }
      } else {
        if (views >= 10) {
          badgeText = "🔥 ยอดนิยม";
        } else {
          badgeText = "✨ สินค้าแนะนำ";
        }
      }

      scoredList.add(ScoredProduct(
        doc: doc,
        score: score,
        badgeText: badgeText,
      ));
    }

    // Sort descending by score
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    return scoredList.take(limit).toList();
  }
}
