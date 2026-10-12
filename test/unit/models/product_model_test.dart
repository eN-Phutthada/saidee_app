import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/models/product_model.dart';

void main() {
  group('ProductModel Tests', () {
    test('should correctly deserialize from Map', () {
      final now = Timestamp.now();
      final map = {
        'sellerId': 'seller_555',
        'name': 'แจ็คเก็ตยีนส์ Levi’s มือสอง',
        'category': 'เสื้อผ้าผู้ชาย',
        'type': 'แจ็คเก็ต',
        'description': 'สภาพดีมาก ใส่น้อย กระดุมครบทุกเม็ด',
        'price': 1250.0,
        'size': 'XL',
        'brand': "Levi's",
        'condition': '95%',
        'weight': 650.0,
        'images': ['https://example.com/jacket1.jpg', 'https://example.com/jacket2.jpg'],
        'video': 'https://example.com/video.mp4',
        'status': 'active',
        'createdAt': now,
      };

      final product = ProductModel.fromMap(map, 'prod_001');

      expect(product.id, 'prod_001');
      expect(product.sellerId, 'seller_555');
      expect(product.name, 'แจ็คเก็ตยีนส์ Levi’s มือสอง');
      expect(product.category, 'เสื้อผ้าผู้ชาย');
      expect(product.type, 'แจ็คเก็ต');
      expect(product.price, 1250.0);
      expect(product.size, 'XL');
      expect(product.brand, "Levi's");
      expect(product.condition, '95%');
      expect(product.weight, 650.0);
      expect(product.images.length, 2);
      expect(product.video, 'https://example.com/video.mp4');
      expect(product.status, 'active');
      expect(product.createdAt, now);
    });

    test('should provide sensible defaults for missing optional data', () {
      final map = <String, dynamic>{};
      final product = ProductModel.fromMap(map, 'prod_default');

      expect(product.id, 'prod_default');
      expect(product.sellerId, '');
      expect(product.name, '');
      expect(product.price, 0.0);
      expect(product.weight, 0.0);
      expect(product.images, isEmpty);
      expect(product.status, 'active');
      expect(product.createdAt, isA<Timestamp>());
    });

    test('should correctly serialize to Map', () {
      final now = Timestamp.now();
      final product = ProductModel(
        id: 'prod_test',
        sellerId: 'seller_123',
        name: 'เสื้อฮู้ด Champion',
        category: 'เสื้อกันหนาว',
        type: 'ฮู้ดดี้',
        description: 'ผ้านุ่ม สีไม่ตก',
        price: 490.0,
        size: 'M',
        brand: 'Champion',
        condition: '85%',
        weight: 400.0,
        images: ['https://example.com/hoodie.jpg'],
        video: '',
        status: 'active',
        createdAt: now,
      );

      final map = product.toMap();

      expect(map['sellerId'], 'seller_123');
      expect(map['name'], 'เสื้อฮู้ด Champion');
      expect(map['price'], 490.0);
      expect(map['size'], 'M');
      expect(map['brand'], 'Champion');
      expect(map['weight'], 400.0);
      expect(map['images'], ['https://example.com/hoodie.jpg']);
      expect(map['status'], 'active');
      expect(map['createdAt'], now);
    });
  });
}
