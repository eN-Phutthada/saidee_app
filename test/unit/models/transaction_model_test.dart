import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/models/transaction_model.dart';

void main() {
  group('TransactionModel Tests', () {
    test('should correctly deserialize topup transaction with slip', () {
      final now = Timestamp.now();
      final map = {
        'uid': 'user_888',
        'type': 'topup',
        'amount': 500.0,
        'status': 'success',
        'slip_url': 'https://storage.googleapis.com/slips/slip1.jpg',
        'note': 'เติมเงินผ่าน PromptPay QR',
        'createdAt': now,
      };

      final tx = TransactionModel.fromMap(map, 'tx_001');

      expect(tx.id, 'tx_001');
      expect(tx.userId, 'user_888');
      expect(tx.type, 'topup');
      expect(tx.amount, 500.0);
      expect(tx.status, 'success');
      expect(tx.slipUrl, 'https://storage.googleapis.com/slips/slip1.jpg');
      expect(tx.note, 'เติมเงินผ่าน PromptPay QR');
      expect(tx.createdAt, now);
    });

    test('should correctly deserialize withdraw transaction with bank details', () {
      final map = {
        'userId': 'user_999',
        'type': 'withdraw',
        'amount': 1200.0,
        'status': 'pending',
        'bank_name': 'ธนาคารกสิกรไทย (KBANK)',
        'account_number': '012-3-45678-9',
        'account_name': 'นายสมบัติ สายดี',
      };

      final tx = TransactionModel.fromMap(map, 'tx_002');

      expect(tx.id, 'tx_002');
      expect(tx.userId, 'user_999');
      expect(tx.type, 'withdraw');
      expect(tx.amount, 1200.0);
      expect(tx.status, 'pending');
      expect(tx.bankName, 'ธนาคารกสิกรไทย (KBANK)');
      expect(tx.accountNumber, '012-3-45678-9');
      expect(tx.accountName, 'นายสมบัติ สายดี');
    });

    test('should correctly serialize to Map', () {
      final tx = TransactionModel(
        id: 'tx_003',
        userId: 'user_111',
        type: 'income',
        amount: 350.0,
        status: 'success',
        note: 'รายได้จากการขายสินค้า order_123',
      );

      final map = tx.toMap();

      expect(map['userId'], 'user_111');
      expect(map['type'], 'income');
      expect(map['amount'], 350.0);
      expect(map['status'], 'success');
      expect(map['note'], 'รายได้จากการขายสินค้า order_123');
    });
  });
}
