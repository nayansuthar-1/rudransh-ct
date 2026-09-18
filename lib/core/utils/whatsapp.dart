import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/models.dart';
import '../l10n/strings.dart';

/// WhatsApp share links (`wa.me`) that agents send from their own phone
/// (IMPLEMENTATION_PLAN §11.2: no WhatsApp Business API, no SMS).
///
/// Messages are in Hindi for members; the app's own labels stay English.
class WhatsApp {
  const WhatsApp._();

  static final _date = DateFormat('dd-MM-yyyy');
  static final _money = NumberFormat.decimalPattern('en_IN');

  static String _rupees(num amount) => '₹${_money.format(amount)}';

  /// Chat with an Indian mobile number and the text filled in, or `null`
  /// when the number is not 10 digits.
  static Uri? link(String phone, String text) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length != 10) return null;
    return Uri.https('wa.me', '/91$digits', {'text': text});
  }

  static String receiptMessage({
    required String memberName,
    required Payment payment,
  }) {
    final kind = switch (payment.kind) {
      PaymentKind.registration => 'पंजीकरण शुल्क',
      PaymentKind.contribution => payment.closingGroup.isEmpty
          ? 'सहयोग राशि'
          : 'सहयोग राशि (${payment.closingGroup})',
      PaymentKind.closingPayout => 'क्लेम भुगतान',
    };
    final status = switch (payment.status) {
      PaymentStatus.paid => 'ट्रस्ट कार्यालय द्वारा स्वीकृत।',
      PaymentStatus.pending => 'ट्रस्ट कार्यालय की स्वीकृति के बाद खाते में जुड़ेगी।',
      PaymentStatus.failed => 'यह रसीद अस्वीकार हो गई है।',
    };
    return [
      'नमस्ते $memberName जी,',
      '${S.trustNameHindi} में आपकी राशि जमा हुई।',
      '',
      'रसीद नं.: ${payment.receiptNo}',
      'राशि: ${_rupees(payment.amount)}',
      'प्रकार: $kind',
      'दिनांक: ${_date.format(payment.date)}',
      if (payment.reference.isNotEmpty) 'संदर्भ: ${payment.reference}',
      '',
      payment.isCancelled ? 'यह रसीद रद्द कर दी गई है।' : status,
      'धन्यवाद।',
    ].join('\n');
  }

  static String duesReminder({
    required MemberDue due,
    required String yojnaName,
    required String agentName,
  }) {
    return [
      'नमस्ते ${due.memberName} जी,',
      '${S.trustNameHindi} की $yojnaName'
          '${due.regNo.isEmpty ? '' : ' (सदस्य नं. ${due.regNo})'} में '
          '${due.closingGroup} (दिनांक ${_date.format(due.closingDate)}) की '
          'सहयोग राशि ${_rupees(due.toCollect)} बाकी है।',
      '',
      'कृपया जल्द से जल्द जमा करें।',
      if (agentName.isNotEmpty) '– $agentName',
    ].join('\n');
  }

  /// Opens WhatsApp (app on phones, WhatsApp Web on computers).
  /// Returns false when nothing could be opened.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
