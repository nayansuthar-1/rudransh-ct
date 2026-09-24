import '../l10n/strings.dart';

typedef Validator = String? Function(String?);

class V {
  const V._();

  static String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? S.required : null;

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return S.required;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(value.replaceAll(RegExp(r'\D'), ''))
        ? null
        : S.invalidPhone;
  }

  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return phone(value);
  }

  static String? aadhaar(String? value) {
    if (value == null || value.trim().isEmpty) return S.required;
    return RegExp(r'^\d{12}$').hasMatch(value.replaceAll(RegExp(r'\D'), ''))
        ? null
        : S.invalidAadhaar;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return S.required;
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim())
        ? null
        : S.invalidEmail;
  }

  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return email(value);
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return S.required;
    final parsed = num.tryParse(value.replaceAll(',', '').trim());
    return (parsed == null || parsed <= 0) ? S.invalidAmount : null;
  }

  static String? optionalAmount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return amount(value);
  }

  static String? pincode(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^\d{6}$').hasMatch(value.trim()) ? null : 'Invalid PIN';
  }

  /// Runs validators in order and returns the first failure.
  static Validator all(List<Validator> validators) => (value) {
        for (final v in validators) {
          final result = v(value);
          if (result != null) return result;
        }
        return null;
      };
}
