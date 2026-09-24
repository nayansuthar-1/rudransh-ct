import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/core/l10n/member_text.dart';
import 'package:rudransh_ct/data/models/models.dart';

final _devanagari = RegExp(r'[ऀ-ॿ]');

void main() {
  const hi = MemberText(MemberLang.hi);
  const en = MemberText(MemberLang.en);

  test('every status and field a member sees has a Hindi label', () {
    final labels = [
      for (final s in MemberStatus.values) hi.memberStatus(s),
      for (final k in PaymentKind.values) hi.paymentKind(k),
      for (final s in DueState.values) hi.dueState(s),
      for (final s in RequestStatus.values) hi.requestStatus(s),
      for (final f in ChangeField.values) hi.changeField(f),
    ];
    for (final l in labels) {
      expect(l, matches(_devanagari), reason: '"$l" is not in Hindi');
    }
  });

  test('English keeps the labels the rest of the app uses', () {
    expect(en.memberStatus(MemberStatus.active), MemberStatus.active.label);
    expect(en.changeField(ChangeField.village), ChangeField.village.label);
  });

  test('the switch names the language it switches to', () {
    expect(hi.switchLabel, 'English');
    expect(en.switchLabel, 'हिंदी');
  });

  test('the lookup errors a member can meet read in Hindi', () {
    for (final m in [
      'Too many wrong tries. Try again after 15 minutes.',
      'Please complete the check and try again.',
      'Lookup is not available right now.',
      'Enter the 10-digit phone number.',
      'Enter the last 4 digits of your Aadhaar.',
    ]) {
      expect(hi.serverMessage(m), matches(_devanagari), reason: m);
      expect(en.serverMessage(m), m);
    }
    expect(hi.serverMessage('Something unexpected'), 'Something unexpected');
  });

  test('a cancelled receipt says so in either language', () {
    final p = Payment(
      id: 'p',
      receiptNo: 'R-1',
      memberId: 'm',
      yojnaId: 'y',
      amount: 100,
      date: DateTime(2026, 9, 1),
      cancelledAt: DateTime(2026, 9, 2),
    );
    expect(hi.paymentStatus(p), 'रद्द');
    expect(en.paymentStatus(p), 'Cancelled');
  });
}
