import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/services/contact_service.dart';

void main() {
  group('ContactService Tests', () {
    test('adminHotline constants should be properly formatted and consistent', () {
      expect(ContactService.adminHotlineFormatted, '064-749-0079');
      expect(ContactService.adminHotlineRaw, '0647490079');
      expect(
        ContactService.adminHotlineFormatted.replaceAll('-', ''),
        ContactService.adminHotlineRaw,
      );
    });
  });
}
