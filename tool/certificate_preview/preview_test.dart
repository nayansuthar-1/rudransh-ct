// Writes a standalone preview of the membership certificate to
// build/certificate_preview.html, so the design can be checked in a browser
// without starting the app:
//
//   flutter test tool/certificate_preview/preview_test.dart
//
// It lives outside test/ on purpose: `flutter test` must not write files in
// CI. The sample data below is made up; nothing touches a database.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/features/certificate/certificate_data.dart';
import 'package:rudransh_ct/features/certificate/certificate_html.dart';

const _out = 'build/certificate_preview.html';

String _mime(String path) => switch (path.split('.').last) {
      'ttf' => 'font/ttf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };

String _dataUri(String path, String mime) =>
    'data:$mime;base64,${base64Encode(File(path).readAsBytesSync())}';

void main() {
  test('preview', () {
    final m = Member(
      id: 'm1',
      yojnaId: 'y1',
      regNo: '111621',
      name: 'रमेश कुमार',
      fatherOrHusbandName: 'फरहान जी',
      jati: 'लुहार',
      gotra: 'केशव',
      dob: DateTime(1960, 1, 1),
      warisName: 'अजय',
      warisRelation: 'पुत्र',
      primaryPhone: '7096578475',
      aadhaar: '',
      village: 'गोआ',
      tehsil: 'रेवदर',
      district: 'सिरोही',
      state: 'राजस्थान',
      pincode: '307513',
      joinDate: DateTime(2026, 9, 20),
      contributionAmount: 200,
    );
    final y = Yojna(
      id: 'y1',
      name: 'सर्व समाज शादी-मामेरा-सुरक्षा सहयोग योजना',
      code: 'SSY',
      description:
          'तीन महीने तक रु 25000, तीन महीने से ऐक साल रु 51000 डोनेशन रासी दी जाऐगी',
      claimAmount: 51000,
      registrationFee: 200,
      startDate: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 9, 20),
    );
    final a = Agent(
      id: 'a1',
      code: 'A-01',
      name: 'रमेश कुमार',
      area: 'मोराल',
      district: 'वाव थराद',
      phone: '9723440164',
      joinDate: DateTime(2026, 7, 1),
    );

    var html = buildCertificateHtml(
      CertificateData.forMember(
        member: m,
        yojna: y,
        agent: a,
      ),
      baseUrl: 'PREVIEW/',
    );

    // The shipped page loads its fonts and images from the app's asset URLs.
    // Inlining them here is only so the preview renders correctly straight
    // off the disk, where a browser refuses to fetch fonts over file://.
    html = html
        .replaceAllMapped(
          RegExp(r'PREVIEW/assets/(assets/[\w/.-]+)'),
          (m) => _dataUri(m[1]!, _mime(m[1]!)),
        )
        // The preview should not fire the print dialog on open.
        .replaceAll('window.print();', '/* print on demand */');

    File(_out).parent.createSync(recursive: true);
    File(_out).writeAsStringSync(html);
    stdout.writeln('Preview written to $_out');
    expect(html, isNot(contains('PREVIEW/')));
  });
}
