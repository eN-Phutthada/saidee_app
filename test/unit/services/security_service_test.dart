import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/services/security_service.dart';

void main() {
  group('SecurityService isSlipReceiverValid Tests', () {
    const expectedName = 'นายพุทธดา หาญนอก';
    const expectedPhone = '0647490079';

    test('should return true when displayName contains first name', () {
      final receiver = {
        'displayName': 'นาย พุทธดา หาญนอก',
        'proxy': {'type': 'MSISDN', 'value': '064-xxx-0079'},
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isTrue,
      );
    });

    test('should return true when name is abbreviated like พุทธดา ห.', () {
      final receiver = {
        'name': 'พุทธดา ห.',
        'proxy': {'value': 'xxx-xxx-xxxx'},
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isTrue,
      );
    });

    test('should return true when receiver name is English transliteration', () {
      final receiver = {
        'displayName': 'MR. PHUTTHADA H',
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isTrue,
      );
    });

    test('should return true when account.name matches', () {
      final receiver = {
        'account': {'name': 'พุทธดา หาญนอก'},
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isTrue,
      );
    });

    test('should return true when proxy value matches promptpay prefix and suffix', () {
      final receiver = {
        'displayName': 'บัญชีพร้อมเพย์',
        'proxy': {'value': '064-xxx-0079'},
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isTrue,
      );
    });

    test('should return true for withdrawal when bank account digits match', () {
      const userBankAcc = '123-4-56789-0';
      const userFullName = 'นายสมชาย ใจดี';
      final receiver = {
        'displayName': 'นายสมชาย',
        'account': {'value': 'xxx-x-xx789-0'},
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: userFullName,
          expectedPromptPay: userBankAcc,
        ),
        isTrue,
      );
    });

    test('should return true for withdrawal when user last name or first name matches', () {
      const userBankAcc = '0987654321';
      const userFullName = 'สมหญิง รักสงบ';
      final receiver = {
        'name': 'สมหญิง ร.',
        'account': {'value': 'xxx-xxx-xxxx'},
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: userFullName,
          expectedPromptPay: userBankAcc,
        ),
        isTrue,
      );
    });

    test('should return false when receiver is another person', () {
      final receiver = {
        'displayName': 'นาย สมชาย ใจดี',
        'name': 'สมชาย จ.',
        'proxy': {'value': '089-xxx-1234'},
        'account': {'value': '123-4-56789-0'},
      };
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: receiver,
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isFalse,
      );
    });

    test('should return false when receiverData is null or invalid', () {
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: null,
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isFalse,
      );
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: {},
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isFalse,
      );
      expect(
        SecurityService.isSlipReceiverValid(
          receiverData: 'not a map',
          expectedAccountName: expectedName,
          expectedPromptPay: expectedPhone,
        ),
        isFalse,
      );
    });
  });
}
