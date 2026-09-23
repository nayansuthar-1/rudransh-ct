import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/core/config/trust_info.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/features/certificate/certificate_data.dart';
import 'package:rudransh_ct/features/certificate/certificate_html.dart';

/// A member with everything the certificate asks for filled in.
Member _member({
  String name = 'Punamabhai',
  String regNo = 'SSY-2026-0184',
  DateTime? dob,
  String state = 'Gujarat',
}) =>
    Member(
      id: 'm1',
      yojnaId: 'y1',
      regNo: regNo,
      name: name,
      fatherOrHusbandName: 'Sonabhai',
      jati: 'Luhar',
      gotra: 'Chauhan',
      dob: dob ?? DateTime(1960, 1, 1),
      warisName: 'Padmabhai',
      warisRelation: 'Son',
      primaryPhone: '9016974664',
      aadhaar: '123456789012',
      village: 'Dhadhra',
      tehsil: 'Vav',
      district: 'Vav Tharad',
      state: state,
      pincode: '385575',
      joinDate: DateTime(2026, 6, 1),
    );

final _yojna = Yojna(
  id: 'y1',
  name: 'Parivar Sahyog Yojna',
  code: 'PSY',
  description: 'तीन महीने तक रु 25000, तीन महीने से एक साल रु 51000',
  contributionAmount: 200,
  claimAmount: 51000,
  registrationFee: 200,
  startDate: DateTime(2026, 7, 1),
  createdAt: DateTime(2026, 9, 20),
);

final _agent = Agent(
  id: 'a1',
  code: 'A-01',
  name: 'Hemtaji Nagaji',
  area: 'Moral',
  district: 'Vav Tharad',
  phone: '9723440164',
  joinDate: DateTime(2025, 8, 25),
);

CertificateData _data({Member? member}) => CertificateData.forMember(
      member: member ?? _member(),
      yojna: _yojna,
      agent: _agent,
      issuedOn: DateTime(2026, 6, 1),
    );

void main() {
  group('certificate data', () {
    test('name carries the father or husband name, as on the sample', () {
      expect(_data().fullName, 'Punamabhai Sonabhai');
    });

    test('a member with no father recorded still has a name', () {
      final m = Member(
        id: 'm2',
        yojnaId: 'y1',
        regNo: 'SSY-2026-0185',
        name: 'Solo',
        fatherOrHusbandName: '',
        jati: '',
        warisName: '',
        warisRelation: '',
        primaryPhone: '9000000000',
        aadhaar: '',
        joinDate: DateTime(2026, 6, 1),
      );
      expect(CertificateData.forMember(member: m).fullName, 'Solo');
    });

    test('an agent name passed by the agent screens wins over the record', () {
      final d = CertificateData.forMember(
        member: _member(),
        agent: _agent,
        agentName: 'Signed-in Agent',
      );
      expect(d.agentName, 'Signed-in Agent');
    });

    test('योजना प्रारंभ is the scheme start date, not the day it was typed in',
        () {
      expect(_data().yojnaStartedOn, DateTime(2026, 7, 1));
    });

    test('an older scheme with no start date falls back to when it was created',
        () {
      final d = CertificateData.forMember(
        member: _member(),
        yojna: _yojna.copyWith(clearStartDate: true),
      );
      expect(d.yojnaStartedOn, DateTime(2026, 9, 20));
    });
  });

  group('certificate html', () {
    final html = buildCertificateHtml(_data(), baseUrl: 'https://trust.test/');

    test('prints every member value', () {
      expect(html, contains('Punamabhai Sonabhai'));
      expect(html, contains('SSY-2026-0184'));
      expect(html, contains('Chauhan'));
      expect(html, contains('Luhar'));
      expect(html, contains('01-01-1960')); // जन्म दि
      expect(html, contains('Dhadhra'));
      expect(html, contains('Vav Tharad'));
      expect(html, contains('Gujarat'));
      expect(html, contains('9016974664'));
      expect(html, contains('Padmabhai'));
      expect(html, contains('Hemtaji Nagaji'));
      expect(html, contains('01-06-2026')); // दिनांक
      expect(html, contains('01-07-2026')); // योजना प्रारंभ
    });

    test('is branded as the trust, in Hindi', () {
      expect(html, contains('रुद्रांश चेरीटेबल ट्रस्ट'));
      expect(html, contains(TrustInfo.slogan));
      expect(html, contains('प्रमाण पत्र'));
      expect(html, contains('सदस्यता क्रमांक'));
      expect(html, contains('वारिसदार'));
      expect(html, isNot(contains('शुभम')));
    });

    test('carries the three invocations the client chose', () {
      expect(html, contains('॥ श्री गणेशाय नमः ॥'));
      expect(html, contains('॥ श्री हनुमते नमः ॥'));
      expect(html, contains('॥ श्री कुलदेवी मातायै नमः ॥'));
      expect(html, isNot(contains('सांवलाजी')));
    });

    test('names the two states at the shoulders of the heading', () {
      expect(html, contains('गुजरात'));
      expect(html, contains('राजस्थान'));
      // The सदस्यता प्रपत्र also names महाराष्ट्र, but the client asked for it
      // off the certificate, along with the `Since` line under the logo.
      expect(html, isNot(contains('महाराष्ट्र')));
      expect(html, isNot(contains('Since')));
    });

    test('signs off with the president and the registration details', () {
      expect(html, contains('अध्यक्ष'));
      expect(html, contains('शैलेषभाई वी.लुहार'));
      expect(html, contains('संस्था स्थापना : <b>01-07-2026</b>'));
      // A placeholder the office must replace, shaped so it cannot be mistaken
      // for the trust's real registration number.
      expect(html, contains('F/0000/B.K.'));
    });

    test('prints the office address and the three chosen phone numbers', () {
      expect(html, contains(TrustInfo.headOfficeAddress));
      expect(html, contains('88299 01246'));
      expect(html, contains('98259 46742'));
      expect(html, contains('95863 40736'));
    });

    test('carries the certificate frame and nothing outside it', () {
      // The reference sheet had a tear-off receipt slip; the client asked for
      // it off, so the frame fills the page.
      expect(html, isNot(contains('Total Amount')));
      expect(html, isNot(contains('Non-Refundable')));
      expect(html, isNot(contains('class="slip"')));
      expect(html, isNot(contains('class="cut"')));
    });

    test('loads both Shiva and Rudransh logos from the asset folder', () {
      expect(
        html,
        contains('src="https://trust.test/assets/assets/brand/'
            'rudransh_logo.png"'),
      );
      expect(
        html,
        contains('src="https://trust.test/assets/assets/brand/'
            'shiva.png"'),
      );
      expect(html, isNot(contains('data:image')));
    });

    test('points both bundled fonts at absolute URLs', () {
      expect(
        html,
        contains(
          "url('https://trust.test/assets/assets/fonts/"
          "NotoSansDevanagari-Regular.ttf')",
        ),
      );
      expect(
        html,
        contains(
          "url('https://trust.test/assets/assets/fonts/YatraOne-Regular.ttf')",
        ),
      );
    });

    test('renders the heading with brand title', () {
      expect(html, contains('class="brand-title"'));
    });

    test('a base URL without a trailing slash still resolves', () {
      final h = buildCertificateHtml(_data(), baseUrl: 'https://trust.test');
      expect(h, contains('https://trust.test/assets/assets/fonts/'));
    });

    test('prints on A4 landscape and asks the browser to print', () {
      expect(html, contains('size: A4 landscape'));
      expect(html, contains('window.print()'));
    });

    test('escapes values so a stray angle bracket cannot inject markup', () {
      final h = buildCertificateHtml(
        _data(member: _member(name: '<script>alert(1)</script>')),
        baseUrl: 'https://trust.test/',
      );
      expect(h, isNot(contains('<script>alert(1)</script>')));
      expect(h, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    });

    test('missing values leave blank lines rather than the word null', () {
      final bare = CertificateData.forMember(
        member: _member(state: '').copyWith(clearDob: true),
        issuedOn: DateTime(2026, 6, 1),
      );
      final h = buildCertificateHtml(bare, baseUrl: 'https://trust.test/');
      expect(h, isNot(contains('null')));
      // The labels are still there, waiting to be filled in by hand.
      expect(h, contains('जन्म दि'));
      expect(h, contains('राज्य'));
    });
  });
}
