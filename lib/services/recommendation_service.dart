import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:saidee_app/models/product_model.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/services/role_guard_service.dart';

class ScoredProduct {
  final QueryDocumentSnapshot doc;
  final double score;

  ScoredProduct({required this.doc, required this.score});
}

class _UserPreferences {
  final Map<String, double> viewedCategories;
  final Map<String, double> viewedTypes;
  final Map<String, double> viewedBrands;
  final Map<String, double> preferredSizes;
  final List<String> recentSearchKeywords;
  final List<String> recentViewedIds;
  final List<String> likedProductIds;
  final double avgPrice;
  final String topSize;
  final double timeDecay;
  final bool hasPersonalizedData;

  _UserPreferences({
    required this.viewedCategories,
    required this.viewedTypes,
    required this.viewedBrands,
    required this.preferredSizes,
    required this.recentSearchKeywords,
    required this.recentViewedIds,
    required this.likedProductIds,
    required this.avgPrice,
    required this.topSize,
    required this.timeDecay,
    required this.hasPersonalizedData,
  });

  factory _UserPreferences.fromMap(Map<String, dynamic> map) {
    Map<String, double> toDoubleMap(dynamic source) {
      if (source is! Map) return {};
      return source.map(
        (k, v) => MapEntry(k.toString(), (v is num) ? v.toDouble() : 0.0),
      );
    }

    final categories = toDoubleMap(map['viewedCategories']);
    final types = toDoubleMap(map['viewedTypes']);
    final brands = toDoubleMap(map['viewedBrands']);
    final sizes = toDoubleMap(map['preferredSizes']);

    final rawKeywords = List<String>.from(map['recentSearchKeywords'] ?? []);
    final keywords = rawKeywords.length > 5
        ? rawKeywords.sublist(rawKeywords.length - 5)
        : rawKeywords;

    final rawViewedIds = List<String>.from(map['recentViewedIds'] ?? []);
    final viewedIds = rawViewedIds.length > 10
        ? rawViewedIds.sublist(rawViewedIds.length - 10)
        : rawViewedIds;

    final likedIds = List<String>.from(map['likedProductIds'] ?? []);

    double avg = 0;
    if (map['avgPrice'] is num) {
      avg = (map['avgPrice'] as num).toDouble();
    } else {
      final prices = List<dynamic>.from(map['recentPrices'] ?? []);
      if (prices.isNotEmpty) {
        double sum = prices.fold(
          0.0,
          (acc, p) => acc + ((p is num) ? p.toDouble() : 0.0),
        );
        avg = sum / prices.length;
      }
    }

    String top = '';
    double maxCount = 0;
    sizes.forEach((k, v) {
      if (v > maxCount) {
        maxCount = v;
        top = k;
      }
    });

    double decay = 1.0;
    Timestamp? last = map['lastInteractedAt'];
    if (last != null) {
      double daysAgo = DateTime.now().difference(last.toDate()).inHours / 24.0;
      decay = max(0.35, exp(-0.099 * daysAgo));
    }

    bool hasData =
        categories.isNotEmpty ||
        types.isNotEmpty ||
        brands.isNotEmpty ||
        keywords.isNotEmpty ||
        likedIds.isNotEmpty;

    return _UserPreferences(
      viewedCategories: categories,
      viewedTypes: types,
      viewedBrands: brands,
      preferredSizes: sizes,
      recentSearchKeywords: keywords,
      recentViewedIds: viewedIds,
      likedProductIds: likedIds,
      avgPrice: avg,
      topSize: top,
      timeDecay: decay,
      hasPersonalizedData: hasData,
    );
  }

  factory _UserPreferences.empty() => _UserPreferences(
    viewedCategories: {},
    viewedTypes: {},
    viewedBrands: {},
    preferredSizes: {},
    recentSearchKeywords: [],
    recentViewedIds: [],
    likedProductIds: [],
    avgPrice: 0,
    topSize: '',
    timeDecay: 1.0,
    hasPersonalizedData: false,
  );
}

class RecommendationService {
  static const double _weightView = 1.0;
  static const double _weightSearch = 2.5;
  static const double _weightLike = 4.0;
  static const double _weightCart = 5.0;
  static const double _weightPurchase = 8.0;

  static const int _maxRecentViewed = 10;
  static const int _maxRecentSearches = 5;
  static const int _maxStoredBrands = 10;

  static final Map<String, List<String>> _viewedCache = {};
  static final Map<String, List<String>> _searchCache = {};
  static final Map<String, double> _avgPriceCache = {};

  static Future<bool> _isEligibleForTracking(String userId) async {
    if (userId.isEmpty) return false;

    try {
      final isAdmin = await RoleGuardService.isUserIdAdmin(userId);
      if (isAdmin) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get();
      return userDoc.exists;
    } catch (e) {
      debugPrint("Error checking tracking eligibility: $e");
      return false;
    }
  }

  static Future<void> _updateAffinityData(
    String userId,
    Map<String, dynamic> updateData,
  ) async {
    if (updateData.isEmpty) return;
    if (!await _isEligibleForTracking(userId)) return;

    try {
      updateData['lastInteractedAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .update(updateData);
    } catch (e) {
      debugPrint("Error updating recommendation affinity: $e");
    }
  }

  static void _addAffinityFields(
    Map<String, dynamic> data, {
    required String category,
    required String type,
    required String brand,
    required String size,
    required double price,
    required double weight,
    String? userId,
  }) {
    if (category.isNotEmpty) {
      data['viewedCategories.$category'] = FieldValue.increment(weight);
    }
    if (type.isNotEmpty) {
      data['viewedTypes.$type'] = FieldValue.increment(weight);
    }
    if (brand.isNotEmpty && brand != '-' && brand != 'ไม่ระบุ') {
      data['viewedBrands.$brand'] = FieldValue.increment(weight * 0.8);
    }
    if (size.isNotEmpty && size != '-') {
      data['preferredSizes.$size'] = FieldValue.increment(weight * 0.6);
    }

    if (price > 0 && weight > 0 && userId != null && userId.isNotEmpty) {
      final oldAvg = _avgPriceCache[userId] ?? 0.0;
      final newAvg = oldAvg <= 0 ? price : (oldAvg * 0.85) + (price * 0.15);
      _avgPriceCache[userId] = newAvg;
      data['avgPrice'] = newAvg;
    }
  }

  static Future<void> trackProductView(
    String userId,
    ProductModel product,
  ) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    final currentList = List<String>.from(_viewedCache[userId] ?? []);
    currentList.remove(product.id);
    currentList.add(product.id);
    if (currentList.length > _maxRecentViewed) {
      currentList.removeRange(0, currentList.length - _maxRecentViewed);
    }
    _viewedCache[userId] = currentList;

    Map<String, dynamic> data = {'recentViewedIds': currentList};
    _addAffinityFields(
      data,
      category: product.category,
      type: product.type,
      brand: product.brand,
      size: product.size,
      price: product.price,
      weight: _weightView,
      userId: userId,
    );
    await _updateAffinityData(userId, data);
  }

  static Future<void> trackProductLike(
    String userId,
    ProductModel product, {
    required bool isLiked,
  }) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    Map<String, dynamic> data = {
      'likedProductIds': isLiked
          ? FieldValue.arrayUnion([product.id])
          : FieldValue.arrayRemove([product.id]),
    };
    _addAffinityFields(
      data,
      category: product.category,
      type: product.type,
      brand: product.brand,
      size: product.size,
      price: product.price,
      weight: isLiked ? _weightLike : -_weightLike,
      userId: userId,
    );
    await _updateAffinityData(userId, data);
  }

  static Future<void> trackCartAdd(String userId, ProductModel product) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    Map<String, dynamic> data = {};
    _addAffinityFields(
      data,
      category: product.category,
      type: product.type,
      brand: product.brand,
      size: product.size,
      price: product.price,
      weight: _weightCart,
      userId: userId,
    );
    await _updateAffinityData(userId, data);
  }

  static Future<void> trackSearch({
    required String userId,
    required String keyword,
    List<String>? categories,
    List<String>? types,
    List<String>? sizes,
  }) async {
    if (userId.isEmpty) return;

    Map<String, dynamic> data = {};
    final cleanKw = keyword.trim();
    if (cleanKw.isNotEmpty) {
      final kwList = List<String>.from(_searchCache[userId] ?? []);
      kwList.remove(cleanKw);
      kwList.add(cleanKw);
      if (kwList.length > _maxRecentSearches) {
        kwList.removeRange(0, kwList.length - _maxRecentSearches);
      }
      _searchCache[userId] = kwList;
      data['recentSearchKeywords'] = kwList;
    }
    if (categories != null) {
      for (var cat in categories) {
        if (cat.isNotEmpty) {
          data['viewedCategories.$cat'] = FieldValue.increment(_weightSearch);
        }
      }
    }
    if (types != null) {
      for (var t in types) {
        if (t.isNotEmpty) {
          data['viewedTypes.$t'] = FieldValue.increment(_weightSearch);
        }
      }
    }
    if (sizes != null) {
      for (var s in sizes) {
        if (s.isNotEmpty && s != '-') {
          data['preferredSizes.$s'] = FieldValue.increment(_weightSearch * 0.6);
        }
      }
    }
    await _updateAffinityData(userId, data);
  }

  static Future<void> trackOrderPurchase(
    String userId,
    List<dynamic> items,
  ) async {
    if (userId.isEmpty || items.isEmpty) return;

    Map<String, dynamic> data = {};
    for (var item in items) {
      if (item is Map<String, dynamic>) {
        _addAffinityFields(
          data,
          category: item['category'] ?? '',
          type: item['type'] ?? '',
          brand: item['brand'] ?? '',
          size: item['size'] ?? '',
          price: (item['price'] ?? 0).toDouble(),
          weight: _weightPurchase,
          userId: userId,
        );
      }
    }
    await _updateAffinityData(userId, data);
  }

  static void _autoCleanupBloatedUserData({
    required String userId,
    required Map<String, dynamic> rawData,
    required Map<String, double> brands,
    required List<String> cappedViews,
    required List<String> cappedSearches,
    required double avgPrice,
  }) {
    Future.microtask(() async {
      try {
        Map<String, dynamic> cleanUp = {};

        if (rawData.containsKey('recentPrices')) {
          cleanUp['recentPrices'] = FieldValue.delete();
          cleanUp['avgPrice'] = avgPrice;
        }

        if (rawData['recentViewedIds'] is List &&
            (rawData['recentViewedIds'] as List).length > _maxRecentViewed) {
          cleanUp['recentViewedIds'] = cappedViews;
        }

        if (rawData['recentSearchKeywords'] is List &&
            (rawData['recentSearchKeywords'] as List).length >
                _maxRecentSearches) {
          cleanUp['recentSearchKeywords'] = cappedSearches;
        }

        if (brands.length > _maxStoredBrands) {
          final sortedEntries = brands.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          for (var entry in sortedEntries.skip(_maxStoredBrands)) {
            cleanUp['viewedBrands.${entry.key}'] = FieldValue.delete();
          }
        }

        if (cleanUp.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(userId)
              .update(cleanUp);
        }
      } catch (e) {
        debugPrint("Auto-cleanup recommendation data error: $e");
      }
    });
  }

  static double _calculateScore({
    required ProductModel product,
    required _UserPreferences prefs,
    required DateTime now,
    required String? userId,
  }) {
    double score = 0.0;

    if (userId != null && userId.isNotEmpty && product.sellerId == userId) {
      score -= 50.0;
    }

    score += log(product.views + 1) * 10.0;
    score += log(product.likesCount + 1) * 16.0;

    double hoursDiff = now
        .difference(product.createdAt.toDate())
        .inHours
        .toDouble();
    if (hoursDiff <= 24) {
      score += 65.0;
    } else if (hoursDiff <= 72) {
      score += 35.0;
    } else if (hoursDiff <= 168) {
      score += 15.0;
    }

    if (prefs.hasPersonalizedData) {
      double catCount = max(
        0.0,
        prefs.viewedCategories[product.category] ?? 0.0,
      );
      double typeCount = max(0.0, prefs.viewedTypes[product.type] ?? 0.0);
      double brandCount = max(0.0, prefs.viewedBrands[product.brand] ?? 0.0);

      catCount = min(50.0, catCount);
      typeCount = min(50.0, typeCount);
      brandCount = min(50.0, brandCount);

      double affinity =
          (catCount * 22.0) + (typeCount * 28.0) + (brandCount * 16.0);
      score += affinity * prefs.timeDecay;

      String name = product.name.toLowerCase();
      String type = product.type.toLowerCase();
      String brand = product.brand.toLowerCase();
      String category = product.category.toLowerCase();

      for (var kw in prefs.recentSearchKeywords.reversed.take(5)) {
        String cleanKw = kw.toLowerCase();
        if (cleanKw.isNotEmpty &&
            (name.contains(cleanKw) ||
                type.contains(cleanKw) ||
                brand.contains(cleanKw) ||
                category.contains(cleanKw))) {
          score += 45.0;
          break;
        }
      }

      if (prefs.avgPrice > 0 && product.price > 0) {
        double diffRatio =
            (product.price - prefs.avgPrice).abs() / prefs.avgPrice;
        if (diffRatio <= 0.30) {
          score += 22.0;
        } else if (diffRatio <= 0.60) {
          score += 10.0;
        }
      }

      if (prefs.topSize.isNotEmpty && product.size == prefs.topSize) {
        score += 18.0;
      } else if (product.size.isNotEmpty &&
          (prefs.preferredSizes[product.size] ?? 0) > 0) {
        score += 8.0;
      }

      if (prefs.likedProductIds.contains(product.id)) {
        score += 25.0;
      }

      if (prefs.recentViewedIds.take(3).contains(product.id)) {
        score -= 30.0;
      }
    }

    return score;
  }

  static List<ScoredProduct> _applyDiversity({
    required List<ScoredProduct> scoredList,
    required int limit,
  }) {
    if (scoredList.length <= 4) return scoredList.take(limit).toList();

    List<ScoredProduct> result = [];
    List<ScoredProduct> pool = List.from(scoredList);
    String lastType = '';
    int consecutiveCount = 0;

    while (result.length < limit && pool.isNotEmpty) {
      int pickIndex = 0;

      if (consecutiveCount >= 2 && lastType.isNotEmpty) {
        for (int i = 1; i < min(pool.length, 6); i++) {
          final p = ProductModel.fromMap(
            pool[i].doc.data() as Map<String, dynamic>,
            pool[i].doc.id,
          );
          if (p.type != lastType) {
            pickIndex = i;
            break;
          }
        }
      }

      final chosen = pool.removeAt(pickIndex);
      final chosenProduct = ProductModel.fromMap(
        chosen.doc.data() as Map<String, dynamic>,
        chosen.doc.id,
      );

      if (chosenProduct.type == lastType && chosenProduct.type.isNotEmpty) {
        consecutiveCount++;
      } else {
        lastType = chosenProduct.type;
        consecutiveCount = 1;
      }

      result.add(chosen);
    }

    return result;
  }

  static Future<List<ScoredProduct>> getRecommendedProducts({
    required String? userId,
    required List<QueryDocumentSnapshot> rawProducts,
    int limit = 16,
  }) async {
    if (rawProducts.isEmpty) return [];

    _UserPreferences prefs = _UserPreferences.empty();

    if (userId != null && userId.isNotEmpty) {
      try {
        final isAdmin = await RoleGuardService.isUserIdAdmin(userId);
        if (!isAdmin) {
          final userDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(userId)
              .get();
          if (userDoc.exists && userDoc.data() != null) {
            final rawData = userDoc.data()!;
            prefs = _UserPreferences.fromMap(rawData);

            _viewedCache[userId] = prefs.recentViewedIds;
            _searchCache[userId] = prefs.recentSearchKeywords;
            _avgPriceCache[userId] = prefs.avgPrice;

            final bool hasLegacyPrices = rawData.containsKey('recentPrices');
            final bool hasTooManyViews =
                (rawData['recentViewedIds'] is List) &&
                (rawData['recentViewedIds'] as List).length > _maxRecentViewed;
            final bool hasTooManySearches =
                (rawData['recentSearchKeywords'] is List) &&
                (rawData['recentSearchKeywords'] as List).length >
                    _maxRecentSearches;
            final bool hasTooManyBrands =
                prefs.viewedBrands.length > _maxStoredBrands;

            if (hasLegacyPrices ||
                hasTooManyViews ||
                hasTooManySearches ||
                hasTooManyBrands) {
              _autoCleanupBloatedUserData(
                userId: userId,
                rawData: rawData,
                brands: prefs.viewedBrands,
                cappedViews: prefs.recentViewedIds,
                cappedSearches: prefs.recentSearchKeywords,
                avgPrice: prefs.avgPrice,
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading user preferences for recommendations: $e");
      }
    }

    final now = DateTime.now();
    List<ScoredProduct> scoredList = [];

    for (var doc in rawProducts) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final product = ProductModel.fromMap(data, doc.id);
        final score = _calculateScore(
          product: product,
          prefs: prefs,
          now: now,
          userId: userId,
        );
        scoredList.add(ScoredProduct(doc: doc, score: score));
      } catch (e) {
        scoredList.add(ScoredProduct(doc: doc, score: 0.0));
      }
    }

    scoredList.sort((a, b) => b.score.compareTo(a.score));

    return _applyDiversity(scoredList: scoredList, limit: limit);
  }
}
