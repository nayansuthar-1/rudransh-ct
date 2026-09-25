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
      contributionAmount: 200,
    );

final _yojna = Yojna(
  id: 'y1',
  name: 'Parivar Sahyog Yojna',
  code: 'PSY',
  description: 'तीन महीने तक रु 25000, तीन महीने से एक साल रु 51000',
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

    test('सहयोग राशि is the member\'s own amount', () {
      final d = CertificateData.forMember(
        member: _member().copyWith(contributionAmount: 500),
        yojna: _yojna,
      );
      expect(d.contributionAmount, 500);
    });

    group('सहयोग राशि label names the Yojna', () {
      String label(String name, {String short = ''}) => CertificateData(
            regNo: '',
            issuedOn: DateTime(2026),
            name: '',
            yojnaName: name,
            yojnaShortName: short,
          ).contributionLabel;

      test('from the Yojna name, without सहयोग योजना', () {
        expect(label('शादी सहयोग योजना'), 'प्रत्येक शादी सहयोग राशि');
        expect(label('मायरा सहयोग योजना'), 'प्रत्येक मायरा सहयोग राशि');
        expect(label('सुरक्षा सहयोग योजना'), 'प्रत्येक सुरक्षा सहयोग राशि');
        expect(label('Parivar Sahyog Yojna'), 'प्रत्येक Parivar सहयोग राशि');
      });

      test('the Yojna\'s name on certificate wins', () {
        expect(
          label('मामेरा (मायरा) सहयोग योजना', short: 'मायरा'),
          'प्रत्येक मायरा सहयोग राशि',
        );
      });

      test('plain सहयोग राशि with no Yojna', () {
        expect(label(''), 'सहयोग राशि');
        expect(label('सहयोग योजना'), 'सहयोग राशि');
      });
    });
  });

  group('certificate html', () {
    final html = buildCertificateHtml(_data(), baseUrl: 'https://trust.test/');

    test('prints every member value', () {
      expect(html, contains('>Punamabhai<'));
      expect(html, contains('>Sonabhai<'));
      expect(html, contains('SSY-2026-0184'));
      expect(html, contains('Chauhan'));
      expect(html, contains('Luhar'));
      expect(html, contains('01-01-1960')); // जन्म तारीख
      expect(html, contains('Dhadhra'));
      expect(html, contains('Vav Tharad'));
      expect(html, contains('Gujarat'));
      expect(html, contains('9016974664'));
      expect(html, contains('Padmabhai'));
      expect(html, contains('Son'));
      expect(html, contains('Hemtaji Nagaji'));
      expect(html, contains('01-06-2026')); // दिनांक
      expect(html, contains('>प्रत्येक Parivar सहयोग राशि:</span>'));
      expect(html, isNot(contains('प्रत्येक मायरा पर')));
      expect(html, contains('>200/-<')); // सहयोग राशि
      expect(html, contains('तीन महीने तक रु 25000')); // नोंध
    });

    test('draws the reference frame with the trust header over it', () {
      expect(
        html,
        contains('href="https://trust.test/assets/assets/brand/'
            'certificate_frame.jpg"'),
      );
      expect(html, contains(TrustInfo.certificateName));
      expect(html, contains('${TrustInfo.place} - ${TrustInfo.state}'));
      expect(html, contains(TrustInfo.headOfficeAddress));
      expect(html, contains(TrustInfo.headOfficePhones.first));
      expect(html, isNot(contains('आपका साथ सहयोग वही समाज का कल्याण')));
      for (final line in TrustInfo.invocations) {
        expect(html, contains(line));
      }
      expect(html, isNot(contains('data:image')));
    });

    test('sets Latin runs in the header in the Latin face', () {
      expect(
        html,
        contains('<tspan class="lat">${TrustInfo.establishedOn}</tspan>'),
      );
    });

    test('lays the reference page out and scales it to A4 landscape', () {
      expect(html, contains('width: 595.275574pt'));
      expect(html, contains('width: 297mm'));
      expect(html, contains('height: 209.31mm'));
    });

    test('writes the name and the father on their own lines', () {
      expect(
        html,
        contains('>नाम:</span><div class="ln" style="width:150.00pt">'
            '<span class="v">Punamabhai</span>'),
      );
      expect(
        html,
        contains('>पिता/पति का नाम:</span><div class="ln" '
            'style="width:150.00pt"><span class="v">Sonabhai</span>'),
      );
    });

    test('नोंध is a field of its own, on the row under सम्बन्ध', () {
      final relation = html.indexOf('>सम्बन्ध :</span>');
      final note = html.indexOf('>नोंध:</span>');
      expect(relation, isNonNegative);
      expect(note, greaterThan(relation));
      expect(
        html,
        contains('>नोंध:</span><div class="ln" style="min-width:160.00pt">'
            '<span class="v">'
            'तीन महीने तक रु 25000'),
      );
    });

    test('prints the payout rule under the fields', () {
      for (final line in TrustInfo.certificateRule) {
        expect(html, contains(line));
      }
    });

    test('the agent signs as कार्यकर्ता', () {
      expect(
        html,
        contains('<div class="name">Hemtaji Nagaji</div><div class="rule">'
            '</div><div class="role">कार्यकर्ता</div>'),
      );
    });

    test('shows the member photo inside the फोटो box', () {
      final h = buildCertificateHtml(
        CertificateData.forMember(
          member: _member().copyWith(photoUrl: 'https://cdn.test/p.jpg'),
          issuedOn: DateTime(2026, 6, 1),
        ),
        baseUrl: 'https://trust.test/',
      );
      expect(h, contains('<img src="https://cdn.test/p.jpg"'));
    });

    test('points the bundled font at an absolute URL', () {
      expect(
        html,
        contains(
          "url('https://trust.test/assets/assets/fonts/"
          "NotoSansDevanagari-Bold.ttf')",
        ),
      );
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
    });
  });
}
