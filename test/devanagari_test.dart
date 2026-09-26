import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/core/utils/devanagari.dart';

void main() {
  test('known Hinglish words take their Hindi spelling', () {
    expect(toDevanagari('Shadi'), 'शादी');
    expect(toDevanagari('shaadi'), 'शादी');
    expect(toDevanagari('Mayara'), 'मायरा');
    expect(toDevanagari('Mameru'), 'मामेरा');
    expect(toDevanagari('Suraksha'), 'सुरक्षा');
    expect(toDevanagari('Kanya Vivah'), 'कन्या विवाह');
  });

  test('other words are spelled by sound', () {
    expect(toDevanagari('Gau'), 'गौ');
    expect(toDevanagari('Raksha'), 'रक्षा');
    expect(toDevanagari('Pooja'), 'पूजा');
    expect(toDevanagari('Dev'), 'देव');
    expect(toDevanagari('Dharm'), 'धर्म');
    expect(toDevanagari('Sant'), 'संत');
  });

  test('Hindi, digits and punctuation are left alone', () {
    expect(toDevanagari('शादी'), 'शादी');
    expect(toDevanagari('Shadi-Mayra (2026)'), 'शादी-मायरा (2026)');
    expect(toDevanagari(''), '');
  });
}
