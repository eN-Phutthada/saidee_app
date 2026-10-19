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

/// ข้อมูลความชอบของผู้ใช้ที่ดึงจาก Firestore สำหรับนำไปคำนวณคะแนนสินค้า
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

    // จำกัดขนาด Array ป้องกันข้อมูลบวม
    final rawKeywords = List<String>.from(map['recentSearchKeywords'] ?? []);
    final keywords = rawKeywords.length > 5
        ? rawKeywords.sublist(rawKeywords.length - 5)
        : rawKeywords;

    final rawViewedIds = List<String>.from(map['recentViewedIds'] ?? []);
    final viewedIds = rawViewedIds.length > 10
        ? rawViewedIds.sublist(rawViewedIds.length - 10)
        : rawViewedIds;

    final likedIds = List<String>.from(map['likedProductIds'] ?? []);

    // ดึง avgPrice เป็นตัวเลขเดี่ยว (หากไม่มีให้อ่านจาก recentPrices เดิมเพื่อรองรับผู้ใช้เก่า)
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

    bool hasData = categories.isNotEmpty ||
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
  // ค่าน้ำหนักคะแนนความชอบตามประเภทการมีปฏิสัมพันธ์
  static const double _weightView = 1.0;
  static const double _weightSearch = 2.5;
  static const double _weightLike = 4.0;
  static const double _weightCart = 5.0;
  static const double _weightPurchase = 8.0;

  // ขีดจำกัดเพื่อป้องกันข้อมูลบวม (Sliding Window Limits)
  static const int _maxRecentViewed = 10;
  static const int _maxRecentSearches = 5;
  static const int _maxStoredBrands = 10;

  // แคชในหน่วยความจำเพื่อคำนวณ Sliding Window และ Moving Average โดยไม่ต้อง Read ซ้ำ
  static final Map<String, List<String>> _viewedCache = {};
  static final Map<String, List<String>> _searchCache = {};
  static final Map<String, double> _avgPriceCache = {};

  /// ตรวจสอบสิทธิ์ว่าผู้ใช้ควรถูกบันทึกข้อมูลพฤติกรรมหรือไม่ (ข้าม Admin และ Guest)
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

  /// ฟังก์ชันกลางสำหรับอัปเดตข้อมูลความชอบของผู้ใช้ใน Firestore
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

  /// รวมฟิลด์ความชอบของสินค้าเข้ากับ Map ข้อมูลอัปเดตแบบกะทัดรัด (ไม่ใช้ Array ราคา)
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
    // บันทึกเฉพาะแบรนด์ที่มีชื่อชัดเจนเพื่อไม่ให้แตกฟิลด์ย่อยสูญเปล่า
    if (brand.isNotEmpty && brand != '-' && brand != 'ไม่ระบุ') {
      data['viewedBrands.$brand'] = FieldValue.increment(weight * 0.8);
    }
    if (size.isNotEmpty && size != '-') {
      data['preferredSizes.$size'] = FieldValue.increment(weight * 0.6);
    }

    // คำนวณ Moving Average เก็บเป็น avgPrice ตัวเลขเดี่ยวแทนการสะสม Array
    if (price > 0 && weight > 0 && userId != null && userId.isNotEmpty) {
      final oldAvg = _avgPriceCache[userId] ?? 0.0;
      final newAvg = oldAvg <= 0 ? price : (oldAvg * 0.85) + (price * 0.15);
      _avgPriceCache[userId] = newAvg;
      data['avgPrice'] = newAvg;
    }
  }

  /// บันทึกการเข้าชมสินค้า (Product View) - เก็บประวัติไม่เกิน 10 ชิ้นล่าสุด
  static Future<void> trackProductView(
    String userId,
    ProductModel product,
  ) async {
    if (userId.isEmpty || userId == product.sellerId) return;

    // บริหาร Sliding Window ให้มีขนาดไม่เกิน 10 รายการ
    final currentList = List<String>.from(_viewedCache[userId] ?? []);
    currentList.remove(product.id);
    currentList.add(product.id);
    if (currentList.length > _maxRecentViewed) {
      currentList.removeRange(0, currentList.length - _maxRecentViewed);
    }
    _viewedCache[userId] = currentList;

    Map<String, dynamic> data = {
      'recentViewedIds': currentList,
    };
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

  /// บันทึกการถูกใจ / เลิกถูกใจสินค้า (Like / Unlike)
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

  /// บันทึกการเพิ่มสินค้าลงในตะกร้า (Cart Add)
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

  /// บันทึกประวัติการค้นหาสินค้า - เก็บคำค้นหาไม่เกิน 5 คำล่าสุด
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

  /// บันทึกเมื่อมีการสั่งซื้อสินค้าสำเร็จ (Order Purchase)
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

  /// ล้างข้อมูลเก่าที่บวมในฐานข้อมูล (Auto-Cleanup สำหรับผู้ใช้เดิม)
  static void _autoCleanupBloatedUserData({
    required String userId,
    required Map<String, dynamic> rawData,
    required Map<String, double> brands,
    required List<String> cappedViews,
    required List<String> cappedSearches,
    required double avgPrice,
  }) {
    // รันแบบ Asynchronous ไม่ให้ขวาง Main Thread
    Future.microtask(() async {
      try {
        Map<String, dynamic> cleanUp = {};

        // 1. ลบ Array ราคาเดิมที่บวมทิ้ง และใส่ avgPrice ตัวเลขเดี่ยวแทน
        if (rawData.containsKey('recentPrices')) {
          cleanUp['recentPrices'] = FieldValue.delete();
          cleanUp['avgPrice'] = avgPrice;
        }

        // 2. ตัดทอน Array สินค้าที่เคยเปิดดูให้เหลือไม่เกิน 10 รายการ
        if (rawData['recentViewedIds'] is List &&
            (rawData['recentViewedIds'] as List).length > _maxRecentViewed) {
          cleanUp['recentViewedIds'] = cappedViews;
        }

        // 3. ตัดทอน Array คำค้นหาให้เหลือไม่เกิน 5 รายการ
        if (rawData['recentSearchKeywords'] is List &&
            (rawData['recentSearchKeywords'] as List).length >
                _maxRecentSearches) {
          cleanUp['recentSearchKeywords'] = cappedSearches;
        }

        // 4. ตัดแต่งแบรนด์เก่าที่คะแนนต่ำ ให้คงเหลือเฉพาะ Top 10 แบรนด์
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

  /// คำนวณคะแนนความเหมาะสมของสินค้าแต่ละชิ้น (Scoring Function)
  static double _calculateScore({
    required ProductModel product,
    required _UserPreferences prefs,
    required DateTime now,
    required String? userId,
  }) {
    double score = 0.0;

    // 1. ลดคะแนนสินค้าของตนเอง (เพื่อไม่ให้ผู้ขายเห็นสินค้าตัวเองเป็นอันดับแรกในฟีดแนะนำ)
    if (userId != null && userId.isNotEmpty && product.sellerId == userId) {
      score -= 50.0;
    }

    // 2. คะแนนความนิยม (Popularity): รวมยอดเข้าชม (views) และยอดถูกใจ (likesCount)
    score += log(product.views + 1) * 10.0;
    score += log(product.likesCount + 1) * 16.0;

    // 3. คะแนนความสดใหม่ของสินค้า (Recency)
    double hoursDiff =
        now.difference(product.createdAt.toDate()).inHours.toDouble();
    if (hoursDiff <= 24) {
      score += 65.0;
    } else if (hoursDiff <= 72) {
      score += 35.0;
    } else if (hoursDiff <= 168) {
      score += 15.0;
    }

    // 4. คะแนนความชอบเฉพาะบุคคล (Personalized Signals)
    if (prefs.hasPersonalizedData) {
      double catCount =
          max(0.0, prefs.viewedCategories[product.category] ?? 0.0);
      double typeCount = max(0.0, prefs.viewedTypes[product.type] ?? 0.0);
      double brandCount = max(0.0, prefs.viewedBrands[product.brand] ?? 0.0);

      // จำกัดคะแนนไม่ให้บวมเกินไป
      catCount = min(50.0, catCount);
      typeCount = min(50.0, typeCount);
      brandCount = min(50.0, brandCount);

      double affinity =
          (catCount * 22.0) + (typeCount * 28.0) + (brandCount * 16.0);
      score += affinity * prefs.timeDecay;

      // ค้นหาคีย์เวิร์ดที่เกี่ยวข้อง
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

      // ช่วงราคาที่คุ้นเคย (คำนวณจาก avgPrice ตัวเลขเดี่ยว)
      if (prefs.avgPrice > 0 && product.price > 0) {
        double diffRatio =
            (product.price - prefs.avgPrice).abs() / prefs.avgPrice;
        if (diffRatio <= 0.30) {
          score += 22.0;
        } else if (diffRatio <= 0.60) {
          score += 10.0;
        }
      }

      // ไซส์ที่ตรงกับความชอบ
      if (prefs.topSize.isNotEmpty && product.size == prefs.topSize) {
        score += 18.0;
      } else if (product.size.isNotEmpty &&
          (prefs.preferredSizes[product.size] ?? 0) > 0) {
        score += 8.0;
      }

      // โบนัสสำหรับสินค้าที่ผู้ใช้กดถูกใจไว้ (Favorite Boost)
      if (prefs.likedProductIds.contains(product.id)) {
        score += 25.0;
      }

      // ลดคะแนนสินค้าที่เพิ่งเปิดดูไป 3 ชิ้นล่าสุด เพื่อให้เห็นสินค้าใหม่ๆ
      if (prefs.recentViewedIds.take(3).contains(product.id)) {
        score -= 30.0;
      }
    }

    return score;
  }

  /// ปรับความหลากหลายของรายการแนะนำ ไม่ให้มีสินค้าประเภทเดิมติดกันเกิน 2 ชิ้น
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

      // หากมีประเภทเดิมซ้ำกัน 2 ชิ้นแล้ว พยายามสลับประเภทอื่นจากกลุ่มบนมาแสดง
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

  /// ดึงและจัดอันดับสินค้าแนะนำสำหรับผู้ใช้ พร้อมทำ Auto-Cleanup หากพบข้อมูลบวม
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

            // ซิงค์แคชในหน่วยความจำ
            _viewedCache[userId] = prefs.recentViewedIds;
            _searchCache[userId] = prefs.recentSearchKeywords;
            _avgPriceCache[userId] = prefs.avgPrice;

            // ตรวจสอบและทำ Auto-Cleanup ลบข้อมูลบวมเดิมในพื้นหลัง
            final bool hasLegacyPrices = rawData.containsKey('recentPrices');
            final bool hasTooManyViews =
                (rawData['recentViewedIds'] is List) &&
                    (rawData['recentViewedIds'] as List).length >
                        _maxRecentViewed;
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
