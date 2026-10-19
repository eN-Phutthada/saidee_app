class SecurityService {
  static String sanitizeText(String input) {
    if (input.isEmpty) return input;

    String clean = input;

    clean = clean.replaceAll(RegExp(r'<script[^>]*>([\s\S]*?)<\/script>', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<style[^>]*>([\s\S]*?)<\/style>', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<[^>]*>'), '');

    clean = clean.replaceAll(RegExp(r'''on\w+\s*=\s*["\'][^"\']*["\']''', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'javascript:\s*', caseSensitive: false), '');

    return clean.trim();
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^0[0-9]{9}$');
    return phoneRegex.hasMatch(phone.trim());
  }

  static bool isSafeAmount(double amount, {double maxLimit = 100000.0}) {
    return !amount.isNaN && !amount.isInfinite && amount > 0 && amount <= maxLimit;
  }

  static bool isSlipReceiverValid({
    required dynamic receiverData,
    required String expectedAccountName,
    required String expectedPromptPay,
  }) {
    if (receiverData == null || receiverData is! Map) return false;

    final displayName = (receiverData['displayName'] ?? '').toString().toLowerCase();
    final name = (receiverData['name'] ?? '').toString().toLowerCase();
    String accountOwner = '';
    if (receiverData['account'] is Map) {
      accountOwner = (receiverData['account']['name'] ?? '').toString().toLowerCase();
    }

    final combinedNames = '$displayName $name $accountOwner'.replaceAll(RegExp(r'\s+'), '');

    final cleanTarget = expectedAccountName
        .replaceAll(RegExp(r'^(นาย|นางสาว|นาง|mr\.|ms\.|mrs\.)\s*', caseSensitive: false), '')
        .trim();
    final targetParts = cleanTarget.split(RegExp(r'\s+'));

    for (var part in targetParts) {
      final cleanPart = part.toLowerCase();
      if (cleanPart.length >= 3 && combinedNames.contains(cleanPart)) {
        return true;
      }
    }

    if (cleanTarget.contains('พุทธดา') && combinedNames.contains('phutthada')) {
      return true;
    }

    String proxyValue = '';
    if (receiverData['proxy'] is Map) {
      proxyValue = (receiverData['proxy']['value'] ?? '').toString();
    }
    String accountValue = '';
    if (receiverData['account'] is Map) {
      accountValue = (receiverData['account']['value'] ?? '').toString();
    }

    final cleanDigits = expectedPromptPay.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length >= 7) {
      final prefix = cleanDigits.substring(0, 3);
      final suffix = cleanDigits.substring(cleanDigits.length - 4);

      final cleanProxy = proxyValue.replaceAll(RegExp(r'[^0-9xX*]'), '');
      if (cleanProxy.contains(prefix) && cleanProxy.contains(suffix)) {
        return true;
      }

      final cleanAcc = accountValue.replaceAll(RegExp(r'[^0-9xX*]'), '');
      if (cleanAcc.endsWith(suffix) || (cleanAcc.contains(prefix) && cleanAcc.contains(suffix))) {
        return true;
      }
    } else if (cleanDigits.length >= 4) {
      final suffix4 = cleanDigits.substring(cleanDigits.length - 4);
      final cleanProxy = proxyValue.replaceAll(RegExp(r'[^0-9xX*]'), '');
      final cleanAcc = accountValue.replaceAll(RegExp(r'[^0-9xX*]'), '');
      if (cleanAcc.endsWith(suffix4) || cleanProxy.endsWith(suffix4)) {
        return true;
      }
    }

    return false;
  }
}
