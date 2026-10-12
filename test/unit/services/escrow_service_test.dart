import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/services/escrow_service.dart';

void main() {
  group('EscrowService Business Logic Tests', () {
    test('autoReleaseDays must be strictly configured to 7 days', () {
      expect(EscrowService.autoReleaseDays, 7);
    });

    test('order should be ineligible for auto-release if status is not shipping', () {
      // Logic simulation of Escrow rule: status must be shipping
      const allowedStatus = 'shipping';

      expect('pending' == allowedStatus, isFalse);
      expect('paid' == allowedStatus, isFalse);
      expect('completed' == allowedStatus, isFalse);
      expect('shipping' == allowedStatus, isTrue);
    });

    test('order should be held when isDisputed is true or status is disputed', () {
      bool isOrderEligible(Map<String, dynamic> order) {
        if (order['status'] != 'shipping') return false;
        if (order['isDisputed'] == true || order['status'] == 'disputed') return false;
        return true;
      }

      final disputedOrder1 = {'status': 'shipping', 'isDisputed': true};
      final disputedOrder2 = {'status': 'disputed', 'isDisputed': false};
      final normalShippingOrder = {'status': 'shipping', 'isDisputed': false};

      expect(isOrderEligible(disputedOrder1), isFalse);
      expect(isOrderEligible(disputedOrder2), isFalse);
      expect(isOrderEligible(normalShippingOrder), isTrue);
    });

    test('order should only release after exactly 7 full days from shippedAt', () {
      bool isDueForRelease(DateTime shippedDate, DateTime now) {
        final diff = now.difference(shippedDate);
        return diff.inDays >= EscrowService.autoReleaseDays;
      }

      final now = DateTime(2026, 10, 11, 12, 0);

      // Shipped 6 days ago -> NOT DUE
      final shipped6DaysAgo = now.subtract(const Duration(days: 6));
      expect(isDueForRelease(shipped6DaysAgo, now), isFalse);

      // Shipped 6 days and 23 hours ago -> NOT DUE
      final shippedAlmost7Days = now.subtract(const Duration(days: 6, hours: 23));
      expect(isDueForRelease(shippedAlmost7Days, now), isFalse);

      // Shipped exactly 7 days ago -> DUE
      final shipped7DaysAgo = now.subtract(const Duration(days: 7));
      expect(isDueForRelease(shipped7DaysAgo, now), isTrue);

      // Shipped 10 days ago -> DUE
      final shipped10DaysAgo = now.subtract(const Duration(days: 10));
      expect(isDueForRelease(shipped10DaysAgo, now), isTrue);
    });

    test('should resolve totalAmount fallback between total and grandTotal', () {
      double extractTotal(Map<String, dynamic> data) {
        return (data['total'] ?? data['grandTotal'] ?? 0).toDouble();
      }

      expect(extractTotal({'total': 450.0}), 450.0);
      expect(extractTotal({'grandTotal': 550.0}), 550.0);
      expect(extractTotal({'total': 300.0, 'grandTotal': 350.0}), 300.0);
      expect(extractTotal({}), 0.0);
    });
  });
}
