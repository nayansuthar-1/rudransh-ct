import 'package:intl/intl.dart';

/// Shared display formatting. Money is Indian Rupee with lakh/crore grouping.
class Fmt {
  const Fmt._();

  static final _date = DateFormat('dd MMM yyyy');
  static final _dateShort = DateFormat('dd/MM/yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _month = DateFormat('MMM yyyy');
  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );
  static final _plain = NumberFormat.decimalPattern('en_IN');

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String dateShort(DateTime? d) =>
      d == null ? '—' : _dateShort.format(d);
  static String dateTime(DateTime? d) =>
      d == null ? '—' : _dateTime.format(d);
  static String month(DateTime d) => _month.format(d);

  static String money(num? v) => v == null ? '—' : _inr.format(v);
  /// `₹1.2L`, `₹85K`, `₹0` — a trailing ".0" is dropped.
  static String moneyCompact(num? v) => v == null
      ? '—'
      : _compact.format(v).replaceFirst(RegExp(r'\.0(?=\D*$)'), '');
  static String number(num? v) => v == null ? '—' : _plain.format(v);

  /// `9876543210` -> `98765 43210`
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return raw;
    return '${digits.substring(0, 5)} ${digits.substring(5)}';
  }

  /// `123456789012` -> `1234 5678 9012`
  static String aadhaar(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12) return raw;
    return '${digits.substring(0, 4)} ${digits.substring(4, 8)} '
        '${digits.substring(8)}';
  }

  /// Masked Aadhaar for list views: `XXXX XXXX 9012`
  static String aadhaarMasked(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12) return raw;
    return 'XXXX XXXX ${digits.substring(8)}';
  }

  /// The same mask built from the four digits alone, which is all a real build
  /// has: the number is encrypted at rest (IMPLEMENTATION_PLAN §7). Returns a
  /// dash when the member has no Aadhaar on record.
  static String aadhaarFromLast4(String last4) {
    final digits = last4.replaceAll(RegExp(r'\D'), '');
    return digits.length == 4 ? 'XXXX XXXX $digits' : '—';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters(2);
    return '${parts.first.characters(1)}${parts.elementAt(1).characters(1)}';
  }

  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return date(d);
  }
}

extension on String {
  String characters(int n) =>
      length <= n ? toUpperCase() : substring(0, n).toUpperCase();
}
