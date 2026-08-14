import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/models/product_model.dart';
import 'package:saidee_app/config/firestore_collections.dart';

class ScoredProduct {
  final QueryDocumentSnapshot doc;
  final double score;

  ScoredProduct({
    required this.doc,
    required this.score,
  });
}

/// Shopee-style Multi-Factor Recommendation Engine for Saidee App
class RecommendationService {
  // Interaction Intent Weights
  static const double _weightView = 1.0;
  static const double _weightSearch = 2.5;
  static const double _weightCart = 5.0;
  static const double _weightPurchase = 8.0;

  /// Track when a user views a product
  static Future<void> trackProductView(
    String userId,
    ProductModel product,
  ) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId);

      Map<String, dynamic> updateData = {};

      if (product.category.isNotEmpty) {
        updateData['viewedCategories.${product.category}'] =
            FieldValue.increment(_weightView);
      }
      if (product.type.isNotEmpty) {
        updateData['viewedTypes.${product.type}'] =
            FieldValue.increment(_weightView);
      }
      if (product.brand.isNotEmpty) {
        updateData['viewedBrands.${product.brand}'] =
            FieldValue.increment(_weightView);
      }
      if (product.size.isNotEmpty && product.size != '-') {
        updateData['preferredSizes.${product.size}'] =
            FieldValue.increment(_weightView);
      }

      updateData['recentViewedIds'] = FieldValue.arrayUnion([product.id]);
      updateData['lastInteractedAt'] = FieldValue.serverTimestamp();

      // Record price history (keep last 20 prices)
      if (product.price > 0) {
        updateData['recentPrices'] = FieldValue.arrayUnion([product.price]);
      }

      await userRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error tracking product view: $e");
    }
  }

  /// Track when a user adds a product to cart
  static Future<void> trackCartAdd(
    String userId,
    ProductModel product,
  ) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId);

      Map<String, dynamic> updateData = {};

      if (product.category.isNotEmpty) {
        updateData['viewedCategories.${product.category}'] =
            FieldValue.increment(_weightCart);
      }
      if (product.type.isNotEmpty) {
        updateData['viewedTypes.${product.type}'] =
            FieldValue.increment(_weightCart);
      }
      if (product.brand.isNotEmpty) {
        updateData['viewedBrands.${product.brand}'] =
            FieldValue.increment(_weightCart * 0.8);
      }
      if (product.size.isNotEmpty && product.size != '-') {
        updateData['preferredSizes.${product.size}'] =
            FieldValue.increment(_weightCart * 0.6);
      }

      updateData['lastInteractedAt'] = FieldValue.serverTimestamp();
      if (product.price > 0) {
        updateData['recentPrices'] = FieldValue.arrayUnion([product.price]);
      }

      await userRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error tracking cart add: $e");
    }
  }

  /// Track user search intent and filters
  static Future<void> trackSearch({
    required String userId,
    required String keyword,
    List<String>? categories,
    List<String>? types,
    List<String>? sizes,
  }) async {
    if (userId.isEmpty) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId);

      Map<String, dynamic> updateData = {};

      if (keyword.trim().isNotEmpty) {
        updateData['recentSearchKeywords'] =
            FieldValue.arrayUnion([keyword.trim()]);
      }

      if (categories != null && categories.isNotEmpty) {
        for (var cat in categories) {
          updateData['viewedCategories.$cat'] =
              FieldValue.increment(_weightSearch);
        }
      }

      if (types != null && types.isNotEmpty) {
        for (var t in types) {
          updateData['viewedTypes.$t'] =
              FieldValue.increment(_weightSearch);
        }
      }

      if (sizes != null && sizes.isNotEmpty) {
        for (var s in sizes) {
          updateData['preferredSizes.$s'] =
              FieldValue.increment(_weightSearch * 0.6);
        }
      }

      updateData['lastInteractedAt'] = FieldValue.serverTimestamp();

      await userRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error tracking search: $e");
    }
  }

  /// Track when a user completes a purchase
  static Future<void> trackOrderPurchase(
    String userId,
    List<dynamic> items,
  ) async {
    if (userId.isEmpty || items.isEmpty) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId);

      Map<String, dynamic> updateData = {};

      for (var item in items) {
        if (item is Map<String, dynamic>) {
          String category = item['category'] ?? '';
          String type = item['type'] ?? '';
          String brand = item['brand'] ?? '';
          String size = item['size'] ?? '';
          double price = (item['price'] ?? 0).toDouble();

          if (category.isNotEmpty) {
            updateData['viewedCategories.$category'] =
                FieldValue.increment(_weightPurchase);
          }
          if (type.isNotEmpty) {
            updateData['viewedTypes.$type'] =
                FieldValue.increment(_weightPurchase);
          }
          if (brand.isNotEmpty) {
            updateData['viewedBrands.$brand'] =
                FieldValue.increment(_weightPurchase * 0.7);
          }
          if (size.isNotEmpty && size != '-') {
            updateData['preferredSizes.$size'] =
                FieldValue.increment(_weightPurchase * 0.6);
          }
          if (price > 0) {
            updateData['recentPrices'] = FieldValue.arrayUnion([price]);
          }
        }
      }

      updateData['lastInteractedAt'] = FieldValue.serverTimestamp();

      await userRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error tracking order purchase: $e");
    }
  }

  /// Shopee-style Multi-Factor Scoring & Diversity Re-ranked Recommendation
  static Future<List<ScoredProduct>> getRecommendedProducts({
    required String? userId,
    required List<QueryDocumentSnapshot> rawProducts,
    int limit = 16,
  }) async {
    if (rawProducts.isEmpty) return [];

    Map<String, dynamic> userInterests = {};

    if (userId != null && userId.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(userId)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          userInterests = userDoc.data()!;
        }
      } catch (e) {
        debugPrint("Error loading user preferences for recommendations: $e");
      }
    }

    final Map<String, dynamic> viewedCategories =
        Map<String, dynamic>.from(userInterests['viewedCategories'] ?? {});
    final Map<String, dynamic> viewedTypes =
        Map<String, dynamic>.from(userInterests['viewedTypes'] ?? {});
    final Map<String, dynamic> viewedBrands =
        Map<String, dynamic>.from(userInterests['viewedBrands'] ?? {});
    final Map<String, dynamic> preferredSizes =
        Map<String, dynamic>.from(userInterests['preferredSizes'] ?? {});
    final List<String> recentSearchKeywords =
        List<String>.from(userInterests['recentSearchKeywords'] ?? []);
    final List<String> recentViewedIds =
        List<String>.from(userInterests['recentViewedIds'] ?? []);
    final List<dynamic> recentPrices =
        List<dynamic>.from(userInterests['recentPrices'] ?? []);

    // 1. Calculate user price preference (average price)
    double avgPrice = 0;
    if (recentPrices.isNotEmpty) {
      double sum = 0;
      for (var p in recentPrices) {
        sum += (p is num) ? p.toDouble() : 0.0;
      }
      avgPrice = sum / recentPrices.length;
    }

    // 2. Calculate most preferred size
    String topSize = '';
    double maxSCount = 0;
    preferredSizes.forEach((k, v) {
      double c = (v is num) ? v.toDouble() : 0.0;
      if (c > maxSCount) {
        maxSCount = c;
        topSize = k;
      }
    });

    // 3. Calculate Exponential Time Decay Factor
    double timeDecay = 1.0;
    Timestamp? lastInteracted = userInterests['lastInteractedAt'];
    if (lastInteracted != null) {
      double daysAgo =
          DateTime.now().difference(lastInteracted.toDate()).inHours / 24.0;
      // Exponential half-life decay around 7 days (min floor 0.35)
      timeDecay = max(0.35, exp(-0.099 * daysAgo));
    }

    bool hasPersonalizedData = viewedCategories.isNotEmpty ||
        viewedTypes.isNotEmpty ||
        viewedBrands.isNotEmpty ||
        recentSearchKeywords.isNotEmpty;

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

      String name = (data['name'] ?? '').toString().toLowerCase();
      String category = data['category'] ?? '';
      String type = data['type'] ?? '';
      String brand = data['brand'] ?? '';
      String size = data['size'] ?? '';
      double price = (data['price'] ?? 0).toDouble();
      int views = (data['views'] ?? 0) is int
          ? (data['views'] ?? 0)
          : ((data['views'] ?? 0) as num).toInt();
      Timestamp? createdAt = data['createdAt'];

      // --- A. Item Quality & Popularity (Log-scaled) ---
      // Shopee uses log scale so 1000 views doesn't completely overwhelm 50 views
      score += log(views + 1) * 14.0;

      // --- B. Freshness / New Arrival Boost ---
      if (createdAt != null) {
        double hoursDiff =
            now.difference(createdAt.toDate()).inHours.toDouble();
        if (hoursDiff <= 24) {
          score += 65.0; // 24h new product boost
        } else if (hoursDiff <= 72) {
          score += 35.0; // 3-day boost
        } else if (hoursDiff <= 168) {
          score += 15.0; // 7-day boost
        }
      }

      // --- C. Personalized Multi-Factor Affinity ---
      if (hasPersonalizedData) {
        double categoryCount =
            (viewedCategories[category] ?? 0).toDouble();
        double typeCount = (viewedTypes[type] ?? 0).toDouble();
        double brandCount = (viewedBrands[brand] ?? 0).toDouble();

        double affinityScore = (categoryCount * 22.0) +
            (typeCount * 28.0) +
            (brandCount * 16.0);

        // Apply time decay to user affinity
        score += affinityScore * timeDecay;

        // --- D. Search Query Relevance ---
        for (var kw in recentSearchKeywords.reversed.take(5)) {
          String cleanKw = kw.toLowerCase();
          if (cleanKw.isNotEmpty &&
              (name.contains(cleanKw) ||
                  type.toLowerCase().contains(cleanKw) ||
                  brand.toLowerCase().contains(cleanKw) ||
                  category.toLowerCase().contains(cleanKw))) {
            score += 45.0;
            break;
          }
        }

        // --- E. Price Tier Fit ---
        if (avgPrice > 0 && price > 0) {
          double diffRatio = (price - avgPrice).abs() / avgPrice;
          if (diffRatio <= 0.30) {
            score += 22.0; // Exact price segment match
          } else if (diffRatio <= 0.60) {
            score += 10.0; // Moderate segment match
          }
        }

        // --- F. Size Preference Match ---
        if (topSize.isNotEmpty && size == topSize) {
          score += 18.0;
        } else if (size.isNotEmpty && (preferredSizes[size] ?? 0) > 0) {
          score += 8.0;
        }

        // --- G. Anti-Staleness Penalty ---
        // Avoid placing the exact item the user just viewed at the very top spot
        if (recentViewedIds.take(3).contains(doc.id)) {
          score -= 30.0;
        }
      }

      scoredList.add(ScoredProduct(
        doc: doc,
        score: score,
      ));
    }

    // Sort descending by score
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    // --- H. Shopee Diversity & Serendipity Re-ranking ---
    List<ScoredProduct> reRankedList = _applyDiversityAndExploration(
      scoredList: scoredList,
      limit: limit,
      hasPersonalizedData: hasPersonalizedData,
    );

    return reRankedList;
  }

  /// Re-ranks products to ensure category diversity (no 3 identical types in a row)
  /// and injects discovery/exploration items (~15-20% serendipity slots).
  static List<ScoredProduct> _applyDiversityAndExploration({
    required List<ScoredProduct> scoredList,
    required int limit,
    required bool hasPersonalizedData,
  }) {
    if (scoredList.length <= 4) return scoredList.take(limit).toList();

    List<ScoredProduct> result = [];
    List<ScoredProduct> pool = List.from(scoredList);

    // Identify distinct types to ensure diversity
    Map<String, int> consecutiveTypeCount = {};
    String lastType = '';

    while (result.length < limit && pool.isNotEmpty) {
      int targetIndex = 0;

      // Every 5th item: Serendipity / Exploration slot
      bool isExplorationSlot = (result.isNotEmpty && result.length % 5 == 4);

      if (isExplorationSlot && pool.length > 4) {
        // Pick an interesting item outside the dominant top types
        int exploreIndex = _findExplorationCandidate(pool, result);
        if (exploreIndex != -1) {
          targetIndex = exploreIndex;
        }
      } else {
        // Ensure max consecutive same type <= 2
        for (int i = 0; i < min(pool.length, 6); i++) {
          var itemData = pool[i].doc.data() as Map<String, dynamic>;
          String itemType = itemData['type'] ?? '';

          if (itemType.isEmpty ||
              itemType != lastType ||
              (consecutiveTypeCount[itemType] ?? 0) < 2) {
            targetIndex = i;
            break;
          }
        }
      }

      ScoredProduct selected = pool.removeAt(targetIndex);
      var selectedData = selected.doc.data() as Map<String, dynamic>;
      String currentType = selectedData['type'] ?? '';

      if (currentType == lastType) {
        consecutiveTypeCount[currentType] =
            (consecutiveTypeCount[currentType] ?? 0) + 1;
      } else {
        consecutiveTypeCount.clear();
        consecutiveTypeCount[currentType] = 1;
        lastType = currentType;
      }

      result.add(selected);
    }

    return result;
  }

  /// Helper to pick a candidate for exploration/discovery slot
  static int _findExplorationCandidate(
    List<ScoredProduct> pool,
    List<ScoredProduct> alreadySelected,
  ) {
    Set<String> selectedTypes = {};
    for (var sp in alreadySelected.take(4)) {
      var d = sp.doc.data() as Map<String, dynamic>;
      if (d['type'] != null) selectedTypes.add(d['type']);
    }

    // Look for an item in the top half of pool with a new type
    for (int i = 3; i < min(pool.length, 12); i++) {
      var d = pool[i].doc.data() as Map<String, dynamic>;
      String t = d['type'] ?? '';
      if (t.isNotEmpty && !selectedTypes.contains(t)) {
        return i;
      }
    }

    return -1;
  }
}
