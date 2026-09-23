import 'package:flutter_test/flutter_test.dart';
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
      expect(html, contains('01-01-1960')); // जन्म तारीख
      expect(html, contains('Dhadhra'));
      expect(html, contains('Vav Tharad'));
      expect(html, contains('Gujarat'));
      expect(html, contains('9016974664'));
      expect(html, contains('Padmabhai'));
      expect(html, contains('Son'));
      expect(html, contains('Hemtaji Nagaji'));
      expect(html, contains('01-06-2026')); // दिनांक
      expect(html, contains('>200<')); // प्रत्येक सहयोग
      expect(html, contains('तीन महीने तक रु 25000')); // नोंध
    });

    test('draws the certificate template as the background', () {
      expect(
        html,
        contains('src="https://trust.test/assets/assets/brand/'
            'certificate_bg.png"'),
      );
      expect(html, isNot(contains('data:image')));
    });

    test('keeps the template aspect ratio so the image is not stretched', () {
      expect(html, contains('width: 297.0mm'));
      expect(html, contains('height: 209.55mm'));
    });

    test('places the name on its line, clear of the नाम label', () {
      // The नाम line runs from x=189 on the 1654px template.
      expect(html, contains('left:11.427%'));
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
          "NotoSansDevanagari-SemiBold.ttf')",
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
