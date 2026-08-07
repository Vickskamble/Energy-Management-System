/// Shared input-validation helpers.
///
/// Centralizes password and email policy so every page enforces the same
/// rules (see SECURITY.md gap G5).
class ValidationRules {
  ValidationRules._();

  /// Minimum password length. Keep in sync with any server-side policy.
  static const int minPasswordLength = 8;

  /// Validates an email address (practical RFC-5321 subset).
  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Validates a password against the app policy:
  /// minimum length + at least one letter and one digit.
  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < minPasswordLength) {
      return 'Min $minPasswordLength characters';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasDigit = RegExp(r'[0-9]').hasMatch(v);
    if (!hasLetter || !hasDigit) {
      return 'Use at least one letter and one number';
    }
    return null;
  }
}
