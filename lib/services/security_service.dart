class SecurityService {
  /// Sanitize text input to prevent XSS and HTML/Script injection attacks
  static String sanitizeText(String input) {
    if (input.isEmpty) return input;

    String clean = input;

    // Remove dangerous HTML and Script tags
    clean = clean.replaceAll(RegExp(r'<script[^>]*>([\s\S]*?)<\/script>', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<style[^>]*>([\s\S]*?)<\/style>', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove inline JS event handlers (e.g. onerror=, onload=, onclick=)
    clean = clean.replaceAll(RegExp(r'''on\w+\s*=\s*["\'][^"\']*["\']''', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'javascript:\s*', caseSensitive: false), '');

    return clean.trim();
  }

  /// Validate email format using standard regex pattern
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate Thai phone number format (10 digits starting with 0)
  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^0[0-9]{9}$');
    return phoneRegex.hasMatch(phone.trim());
  }

  /// Check if the transaction amount is positive and within reasonable limits
  static bool isSafeAmount(double amount, {double maxLimit = 100000.0}) {
    return !amount.isNaN && !amount.isInfinite && amount > 0 && amount <= maxLimit;
  }
}
