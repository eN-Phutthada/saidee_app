import 'package:flutter_test/flutter_test.dart';
import 'package:saidee_app/services/role_guard_service.dart';

void main() {
  group('RoleGuardService Basic & Isolation Tests', () {
    setUp(() {
      RoleGuardService.clearCache();
    });

    test('isUserIdAdmin should return false immediately for empty uid', () async {
      final result = await RoleGuardService.isUserIdAdmin('');
      expect(result, isFalse);
    });

    test('isCurrentUserAdmin should return false when no user is signed in', () async {
      final result = await RoleGuardService.isCurrentUserAdmin();
      expect(result, isFalse);
    });

    test('clearCache should execute smoothly without crashing', () {
      expect(() => RoleGuardService.clearCache(), returnsNormally);
    });

    test('redirectIfAdmin should return false when not admin', () async {
      final redirected = await RoleGuardService.redirectIfAdmin();
      expect(redirected, isFalse);
    });
  });
}
