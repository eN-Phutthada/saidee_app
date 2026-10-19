import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/models/product_model.dart';
import 'package:saidee_app/services/recommendation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('RecommendationService Tests', () {
    test('getRecommendedProducts should return empty list when rawProducts is empty', () async {
      final result = await RecommendationService.getRecommendedProducts(
        userId: 'test_user_id',
        rawProducts: [],
      );
      expect(result, isEmpty);
    });

    test('trackProductLike should return safely when userId is empty', () async {
      final product = ProductModel(
        id: 'prod_1',
        sellerId: 'seller_1',
        name: 'เสื้อยืดวินเทจ',
        category: 'เสื้อผ้า',
        type: 'เสื้อยืด',
        description: 'เสื้อยืดสภาพดี',
        price: 250,
        size: 'L',
        brand: 'Nike',
        condition: 'สภาพดี',
        weight: 0.2,
        images: ['https://example.com/image.jpg'],
        video: '',
        status: 'active',
        createdAt: Timestamp.now(),
      );

      // Should complete normally without throwing error
      await expectLater(
        RecommendationService.trackProductLike('', product, isLiked: true),
        completes,
      );
    });

    test('trackProductLike should ignore tracking when userId is sellerId', () async {
      final product = ProductModel(
        id: 'prod_1',
        sellerId: 'user_123',
        name: 'เสื้อยืดวินเทจ',
        category: 'เสื้อผ้า',
        type: 'เสื้อยืด',
        description: 'เสื้อยืดสภาพดี',
        price: 250,
        size: 'L',
        brand: 'Nike',
        condition: 'สภาพดี',
        weight: 0.2,
        images: ['https://example.com/image.jpg'],
        video: '',
        status: 'active',
        createdAt: Timestamp.now(),
      );

      await expectLater(
        RecommendationService.trackProductLike('user_123', product, isLiked: true),
        completes,
      );
    });

    test('trackProductView and trackCartAdd should return safely with empty userId', () async {
      final product = ProductModel(
        id: 'prod_2',
        sellerId: 'seller_2',
        name: 'กางเกงยีนส์',
        category: 'เสื้อผ้า',
        type: 'กางเกง',
        description: 'กางเกงสภาพดี',
        price: 500,
        size: '32',
        brand: 'Levi',
        condition: 'สภาพดี',
        weight: 0.5,
        images: ['https://example.com/pants.jpg'],
        video: '',
        status: 'active',
        createdAt: Timestamp.now(),
      );

      await expectLater(
        RecommendationService.trackProductView('', product),
        completes,
      );

      await expectLater(
        RecommendationService.trackCartAdd('', product),
        completes,
      );
    });

    test('trackSearch should return safely with empty keyword or userId', () async {
      await expectLater(
        RecommendationService.trackSearch(
          userId: '',
          keyword: 'เสื้อ',
        ),
        completes,
      );

      await expectLater(
        RecommendationService.trackSearch(
          userId: 'user_1',
          keyword: '',
        ),
        completes,
      );
    });
  });
}
