import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/models/cart_item_model.dart';
import 'package:saidee_app/models/coupon_model.dart';

void main() {
  group('Cart & Checkout Flow Logic Tests', () {
    late List<CartItemModel> cartItems;

    setUp(() {
      cartItems = [
        CartItemModel(
          id: 'c1',
          productId: 'p1',
          name: 'เสื้อยืดวินเทจ',
          price: 250.0,
          quantity: 2, // 500.0
          sellerId: 's1',
          image: '',
          weight: 200.0, // 400g total
        ),
        CartItemModel(
          id: 'c2',
          productId: 'p2',
          name: 'กางเกงยีนส์ขาสั้น',
          price: 350.0,
          quantity: 1, // 350.0
          sellerId: 's1',
          image: '',
          weight: 350.0, // 350g total
        ),
      ];
    });

    test('should accurately calculate subtotal and total package weight', () {
      double subtotal = 0;
      double totalWeight = 0;

      for (var item in cartItems) {
        subtotal += item.price * item.quantity;
        totalWeight += item.weight * item.quantity;
      }

      expect(subtotal, 850.0); // (250*2) + (350*1)
      expect(totalWeight, 750.0); // (200*2) + (350*1)
    });

    test('should calculate correct shipping fee based on tiered weight rules', () {
      double calculateShipping(String provider, double weight) {
        if (provider == 'Flash Express') {
          if (weight <= 1000) return 25.0;
          if (weight <= 2000) return 35.0;
          return 50.0;
        } else if (provider == 'Thailand Post (EMS)') {
          if (weight <= 500) return 42.0;
          if (weight <= 1000) return 52.0;
          return 70.0;
        }
        return 40.0;
      }

      const totalWeight = 750.0; // From previous items
      expect(calculateShipping('Flash Express', totalWeight), 25.0);
      expect(calculateShipping('Thailand Post (EMS)', totalWeight), 52.0);

      // Heavy package (1200g)
      expect(calculateShipping('Flash Express', 1200.0), 35.0);
    });

    test('should properly validate and apply coupon discounts', () {
      double calculateDiscount(CouponModel coupon, double subtotal) {
        if (!coupon.isActive) return 0.0;
        if (subtotal < coupon.minOrderAmount) return 0.0;

        if (coupon.type == 'percent') {
          return subtotal * (coupon.discountValue / 100.0);
        } else {
          return coupon.discountValue;
        }
      }

      const subtotal = 850.0;

      // 1. Valid percent coupon (10% off for min 500)
      final coupon10Percent = CouponModel(
        id: 'cp1',
        code: 'SAIDEE10',
        type: 'percent',
        discountValue: 10.0,
        minOrderAmount: 500.0,
        isActive: true,
      );
      expect(calculateDiscount(coupon10Percent, subtotal), 85.0);

      // 2. Valid fixed coupon (50฿ off for min 300)
      final coupon50Fixed = CouponModel(
        id: 'cp2',
        code: 'WELCOME50',
        type: 'fixed',
        discountValue: 50.0,
        minOrderAmount: 300.0,
        isActive: true,
      );
      expect(calculateDiscount(coupon50Fixed, subtotal), 50.0);

      // 3. Ineligible coupon (requires min 1000)
      final couponHighMin = CouponModel(
        id: 'cp3',
        code: 'BIG1000',
        type: 'fixed',
        discountValue: 100.0,
        minOrderAmount: 1000.0,
        isActive: true,
      );
      expect(calculateDiscount(couponHighMin, subtotal), 0.0);

      // 4. Inactive coupon
      final inactiveCoupon = CouponModel(
        id: 'cp4',
        code: 'EXPIRED',
        type: 'percent',
        discountValue: 20.0,
        minOrderAmount: 100.0,
        isActive: false,
      );
      expect(calculateDiscount(inactiveCoupon, subtotal), 0.0);
    });

    test('should compute grand total invoice correctly', () {
      const subtotal = 850.0;
      const shippingFee = 25.0; // Flash Express
      const discountAmount = 85.0; // 10% coupon

      final grandTotal = (subtotal + shippingFee - discountAmount);
      expect(grandTotal, 790.0);
    });

    test('should correctly verify wallet payment sufficiency', () {
      bool canPayWithWallet(double walletBalance, double grandTotal) {
        return walletBalance >= grandTotal;
      }

      const grandTotal = 790.0;

      expect(canPayWithWallet(1000.0, grandTotal), isTrue);
      expect(canPayWithWallet(790.0, grandTotal), isTrue);
      expect(canPayWithWallet(500.0, grandTotal), isFalse);
    });
  });
}
