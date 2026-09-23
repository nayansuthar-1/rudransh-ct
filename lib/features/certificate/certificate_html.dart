import 'package:intl/intl.dart';

import '../../core/config/trust_info.dart';
import 'certificate_data.dart';

final _date = DateFormat('dd-MM-yyyy');
final _money = NumberFormat.decimalPattern('en_IN');

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _day(DateTime? d) => d == null ? '' : _date.format(d);

/// Flutter serves a declared asset at `<base>assets/<declared path>`.
String _assetUrl(String base, String path) {
  final sep = base.isEmpty || base.endsWith('/') ? '' : '/';
  return '$base${sep}assets/$path';
}

/// Size of the template image (`final.png` → [TrustInfo.certificateBgAsset]).
/// Every coordinate below is in the pixels of this image.
const _imgW = 1654;
const _imgH = 1167;

/// The sheet keeps the template's own aspect ratio, so the image is never
/// stretched: 297mm wide, and 297 × 1167 / 1654 ≈ 209.55mm tall.
const _sheetWmm = 297.0;
const _sheetHmm = _sheetWmm * _imgH / _imgW;

String _pct(num v, int of) => '${(v * 100 / of).toStringAsFixed(3)}%';

/// One value written onto a printed line: from [x1] to [x2], sitting on the
/// line at [lineY]. Positions are measured from the template image.
String _field(String value, {required int x1, required int x2, required int lineY}) {
  const gap = 5; // a few pixels clear of the line, as handwriting would sit
  return '<div class="v" style="left:${_pct(x1, _imgW)};'
      'width:${_pct(x2 - x1, _imgW)};'
      'bottom:${_pct(_imgH - lineY + gap, _imgH)};">${_esc(value)}</div>';
}

/// Builds the printable membership certificate as one self-contained HTML
/// page: a single A4 landscape sheet with the certificate template image as
/// the background, and each member value written on its line.
///
/// Everything printed on the template — heading, invocations, labels, logos —
/// comes from the image itself, so the sheet matches it pixel for pixel. Only
/// the member's own details are laid over it.
///
/// [baseUrl] is the app's own base URL, used to reach the bundled assets.
String buildCertificateHtml(CertificateData d, {required String baseUrl}) {
  final bgImage = _assetUrl(baseUrl, TrustInfo.certificateBgAsset);
  final fonts = _assetUrl(baseUrl, 'assets/fonts');

  final amount =
      d.contributionAmount > 0 ? _money.format(d.contributionAmount) : '';

  final memberPhoto = d.photoUrl.isNotEmpty
      ? '<img src="${_esc(d.photoUrl)}" alt="">'
      : '';

  // Line coordinates measured on the 1654×1167 template. The two top-row
  // labels (सदस्यता क्रमांक, दिनांक) have no printed line, so they use the
  // line their text would sit on.
  final fields = [
    _field(d.regNo, x1: 258, x2: 640, lineY: 439), // सदस्यता क्रमांक
    _field(_day(d.issuedOn), x1: 1125, x2: 1300, lineY: 439), // दिनांक
    _field(d.fullName, x1: 189, x2: 619, lineY: 504), // नाम
    _field(d.gotra, x1: 785, x2: 1215, lineY: 504), // गोत्र
    _field(d.jati, x1: 189, x2: 489, lineY: 559), // जाति
    _field(_day(d.dob), x1: 855, x2: 1215, lineY: 559), // जन्म तारीख
    _field(d.phone, x1: 249, x2: 585, lineY: 614), // मोबाइल नं.
    _field(d.village, x1: 860, x2: 1215, lineY: 614), // गाँव / सिटी
    _field(d.district, x1: 194, x2: 585, lineY: 669), // जिला
    _field(d.state, x1: 795, x2: 1216, lineY: 669), // राज्य
    _field(d.address, x1: 184, x2: 659, lineY: 724), // पता
    _field(d.warisName, x1: 835, x2: 1216, lineY: 724), // वारिसदार
    _field(d.warisRelation, x1: 229, x2: 659, lineY: 779), // सम्बन्ध
    _field(amount, x1: 870, x2: 1215, lineY: 779), // प्रत्येक सहयोग
    _field(d.agentName, x1: 229, x2: 659, lineY: 834), // कार्यकर्ता
    _field(d.payoutNote, x1: 190, x2: 663, lineY: 889), // नोंध
  ].join('\n  ');

  // Inside the फोटो box's 3px border: x 1309–1507, y 453–651.
  final photoStyle = 'left:${_pct(1309, _imgW)};top:${_pct(453, _imgH)};'
      'width:${_pct(1507 - 1309, _imgW)};height:${_pct(651 - 453, _imgH)};';

  return '''<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<title>प्रमाण पत्र - ${_esc(d.regNo)}</title>
<style>
@font-face {
  font-family: 'Noto Sans Devanagari';
  src: url('$fonts/NotoSansDevanagari-SemiBold.ttf') format('truetype');
  font-weight: 600;
}
@font-face {
  font-family: 'Noto Sans Devanagari';
  src: url('$fonts/NotoSansDevanagari-Regular.ttf') format('truetype');
  font-weight: 400;
}
@page { size: A4 landscape; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
  background: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.page {
  position: relative;
  width: ${_sheetWmm}mm;
  height: ${_sheetHmm.toStringAsFixed(2)}mm;
  overflow: hidden;
  margin: 0 auto;
}
.page > img.bg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
}
/* A member value, written on its line. */
.v {
  position: absolute;
  z-index: 1;
  padding: 0 1mm;
  font-family: 'Noto Sans Devanagari', 'Nirmala UI', 'Mangal', sans-serif;
  font-size: 11.5pt;
  font-weight: 600;
  line-height: 1.2;
  color: #1c1a4e;
  white-space: nowrap;
  overflow: hidden;
}
.photo {
  position: absolute;
  z-index: 1;
  overflow: hidden;
}
.photo img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
</head>
<body>
<div class="page">
  <img class="bg" src="$bgImage" alt="">
  $fields
  <div class="photo" style="$photoStyle">$memberPhoto</div>
</div>
<script>
// A value too long for its line is shrunk to fit rather than cut off.
function fitValues() {
  document.querySelectorAll('.v').forEach(function (el) {
    var size = 11.5;
    while (el.scrollWidth > el.clientWidth && size > 6) {
      size -= 0.5;
      el.style.fontSize = size + 'pt';
    }
  });
}
window.addEventListener('load', function () {
  var fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
  fontsReady.then(function () {
    fitValues();
    window.print();
  });
});
</script>
</body>
</html>''';
}
