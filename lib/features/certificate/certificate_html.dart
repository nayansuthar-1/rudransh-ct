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

// The design copies the reference certificate
// (KALPESH_KUMAR_R707604_Certificate.pdf), measured off the PDF itself:
//
// * The sheet is the reference's A5 landscape page, 595.28 × 419.53pt, and
//   every body position below is in those points. It prints in the top half
//   of an A4 portrait page, shrunk to leave white space on every side, so the
//   paper can be turned round and the next certificate printed in the other.
// * The header lives in the pixel space of the frame image, 2559 × 1659.
//   The reference stretches that image onto the page, so its header is 8.7%
//   taller than drawn; laying ours out in the same space stretches it the
//   same way.

/// The reference page, in points.
const _sheetW = 595.275574;
const _sheetH = 419.527557;

/// The white space, in mm, above the certificate and at either side of it,
/// and between it and the next one printed after turning the paper round:
/// the one gap that fits three times with two certificates down A4's 297mm,
/// `3m + 2h = 297` with `h = (210 − 2m) × sheet height / sheet width`. It
/// comes to 5.53mm.
const _margin = (297 - 2 * 210 * _sheetH / _sheetW) / (3 - 4 * _sheetH / _sheetW);

/// The sheet is the full 210mm A4 width less a margin each side, about
/// 199 × 140mm.
const _fit = (210 - 2 * _margin) / 210;

/// The frame image, in pixels.
const _artW = 2559;
const _artH = 1659;

/// Baseline of the first body row, and the distance between rows. The
/// reference spaces its six rows 24pt apart; ours has eight, so they are
/// drawn 21pt apart to leave the rule and the signatures where they were.
const _row1 = 175.23;
const _rowPitch = 21.0;

/// Baseline of the rule's first line: 11pt under the नोंध row's line.
const _ruleBase = _row1 + 7 * _rowPitch + 4.70 + 1 + 11;

/// Wraps each run of Latin letters and digits — `01-07-2026`, `F/0000/B.K.,`
/// — in a tspan for the Latin face, as the reference sets `C-3,` in Arial
/// Bold inside a Yatra One line.
String _mixed(String s) {
  final latin = RegExp(r'[A-Za-z0-9][A-Za-z0-9./,\-]*');
  final out = StringBuffer();
  var at = 0;
  for (final m in latin.allMatches(s)) {
    out
      ..write(_esc(s.substring(at, m.start)))
      ..write('<tspan class="lat">${_esc(m.group(0)!)}</tspan>');
    at = m.end;
  }
  out.write(_esc(s.substring(at)));
  return out.toString();
}

/// The frame, the two images and the trust's header, drawn in the frame
/// image's pixel space. Sizes, baselines and colours are matched to the
/// reference header.
String _art(String baseUrl) {
  final frame = _assetUrl(baseUrl, TrustInfo.certificateFrameAsset);
  final shiva = _assetUrl(baseUrl, TrustInfo.shivaAsset);
  final logo = _assetUrl(baseUrl, TrustInfo.logoAsset);

  final inv = TrustInfo.invocations;
  final left = inv.isEmpty ? '' : inv.first;
  final right = inv.length < 2 ? '' : inv.last;

  final established =
      'स्थापना: ${TrustInfo.establishedOn}  |  संस्था रजिस्टर नं.: '
      '${TrustInfo.registrationNo}';
  final phones = 'Mobile: ${TrustInfo.headOfficePhones.join(' / ')}';

  return '''
<svg class="art" viewBox="0 0 $_artW $_artH" preserveAspectRatio="none">
  <defs>
    <linearGradient id="heading-fill" gradientUnits="userSpaceOnUse" x1="0" y1="193" x2="0" y2="234">
      <stop offset="0" stop-color="#1e1856"/>
      <stop offset="1" stop-color="#e31e27"/>
    </linearGradient>
  </defs>
  <image href="$frame" x="0" y="0" width="$_artW" height="$_artH" preserveAspectRatio="none"/>
  ${TrustInfo.hasShiva ? '<image href="$shiva" x="214.7" y="166" width="375.5" height="375.5" preserveAspectRatio="none"/>' : ''}
  ${TrustInfo.hasLogo ? '<image href="$logo" x="1964.4" y="157.9" width="354.2" height="354.2" preserveAspectRatio="none"/>' : ''}
  <text class="inv" transform="translate(327 0) scale(0.9 1)" y="145">${_esc(left)}</text>
  <text class="inv" transform="translate(2227 0) scale(0.9 1)" y="145" text-anchor="end">${_esc(right)}</text>
  <text class="heading" fill="url(#heading-fill)" transform="translate(1279.5 0) scale(0.897 1)" y="251" text-anchor="middle">${_esc(TrustInfo.certificateName)}</text>
  <text class="place" x="1279.5" y="325" text-anchor="middle">${_esc('${TrustInfo.place} - ${TrustInfo.state}')}</text>
  <text class="line" x="1279.5" y="389" text-anchor="middle">${_mixed(established)}</text>
  <text class="line" x="1279.5" y="439" text-anchor="middle">${_mixed(TrustInfo.headOfficeAddress)}</text>
  <text class="phones" x="1279.5" y="499" text-anchor="middle">${_esc(phones)}</text>
</svg>''';
}

/// One label with its dotted line and the member's value written on it.
/// [width] is the line's length in points. A [hug] line is only that long at
/// the least: it runs on under a longer value, up to the end of the row.
/// [unit] follows the line, as `रुपये` does on the reference. A [fitLabel]
/// label shrinks, when printed, until its row fits.
class _Field {
  const _Field(
    this.label,
    this.value, {
    required this.width,
    this.hug = false,
    this.unit = '',
    this.fitLabel = false,
  });
  final String label;
  final String value;
  final double width;
  final bool hug;
  final String unit;
  final bool fitLabel;
}

String _fieldHtml(_Field f) {
  final width = '${f.hug ? 'min-width' : 'width'}:'
      '${f.width.toStringAsFixed(2)}pt';
  // A zero-width space keeps a baseline on an empty line.
  final value = f.value.isEmpty ? '&#8203;' : _esc(f.value);
  final unit = f.unit.isEmpty ? '' : '<span class="l">${_esc(f.unit)}</span>';
  return '<div class="f${f.hug ? ' hug' : ''}">'
      '<span class="l${f.fitLabel ? ' fit' : ''}">${_esc(f.label)}</span>'
      '<div class="ln" style="$width"><span class="v">$value</span></div>'
      '$unit</div>';
}

/// A row of fields whose labels sit on the baseline of row [index].
String _rowHtml(int index, List<_Field> fields, {bool spread = false}) {
  // Values are the tallest thing on a row, 10pt with 0.896em above the
  // baseline, so the row box starts that far above it.
  final top = _row1 + index * _rowPitch - 8.96;
  return '<div class="row${spread ? ' spread' : ''}" '
      'style="top:${top.toStringAsFixed(2)}pt">'
      '${fields.map(_fieldHtml).join()}</div>';
}

/// The certificate itself, laid out as the reference sheet, in the top half
/// of the page.
String _sheetHtml(CertificateData d, String baseUrl) {
  final amount =
      d.contributionAmount > 0 ? '${_money.format(d.contributionAmount)}/-' : '';

  final photo = d.photoUrl.isNotEmpty
      ? '<img src="${_esc(d.photoUrl)}" alt="">'
      : '<span>फोटो</span>';

  // Rows 0–5 are the reference's own fields and line lengths. Row 5 names
  // the Yojna in its सहयोग राशि label, as the reference names मायरा, so its
  // वारिसदार line is shorter to make room. The सम्बन्ध and नोंध rows are
  // ours, in the same style; the नोंध line runs only as far as its note.
  final rows = [
    _rowHtml(0, spread: true, [
      _Field('सदस्यता क्रमांक:', d.regNo, width: 90),
      _Field('दिनांक:', _day(d.issuedOn), width: 62.74),
    ]),
    _rowHtml(1, [
      _Field('नाम:', d.name, width: 150),
      _Field('पिता/पति का नाम:', d.fatherOrHusbandName, width: 150),
    ]),
    _rowHtml(2, [
      _Field('गोत्र:', d.gotra, width: 90),
      _Field('जाति:', d.jati, width: 100),
      _Field('जन्म दि.:', _day(d.dob), width: 110),
    ]),
    _rowHtml(3, [
      _Field('मोबाईल नंबर', d.phone, width: 140),
      _Field('गाँव/शहर का नाम:', d.village, width: 135),
    ]),
    _rowHtml(4, [
      _Field('जिला:', d.district, width: 160),
      _Field('राज्य:', d.state, width: 180),
    ]),
    _rowHtml(5, [
      _Field('वारिसदार:', d.warisName, width: 120),
      _Field('${d.contributionLabel}:', amount,
          width: 60, unit: 'रुपये', fitLabel: true),
    ]),
    _rowHtml(6, [
      _Field('सम्बन्ध :', d.warisRelation, width: 160),
    ]),
    _rowHtml(7, [
      _Field('नोंध:', d.payoutNote.trim(), width: 160, hug: true),
    ]),
  ].join('\n  ');

  // The trust's rule, under the fields on the left, so the space above the
  // अध्यक्ष line stays clear for the trust's stamp. The lines sit centred on
  // the reference's two-line block, so a single line lands midway between
  // its two.
  final ruleLines = TrustInfo.certificateRule;
  final rule = [
    for (final (i, line) in ruleLines.indexed)
      '<div class="rule-line" '
          'style="top:${(_ruleBase + (i + 1 - ruleLines.length / 2) * 11.9 - 0.896 * 8.5).toStringAsFixed(2)}pt">'
          '${_esc(line)}</div>',
  ].join('\n  ');

  return '''
<div class="sheet">
  ${_art(baseUrl)}
  <div class="title">प्रमाण पत्र</div>
  <div class="photo">$photo</div>
  $rows
  $rule
  <div class="sig" style="left:77.09pt;width:155.49pt">
    <div class="name">${_esc(d.agentName)}</div><div class="rule"></div><div class="role">कार्यकर्ता</div>
  </div>
  <div class="sig" style="left:370.44pt;width:140pt">
    <div class="name">${_esc(TrustInfo.certificateName)}</div><div class="rule"></div><div class="role">अध्यक्ष</div>
  </div>
</div>''';
}

/// Builds the printable membership certificate as one self-contained HTML
/// page: the certificate laid out as the reference, carrying the trust's
/// details and the member's, in the top half of an A4 portrait sheet.
///
/// The bottom half is left blank, so the paper can be turned round and fed
/// back in for the next member, whose certificate then lands there without
/// touching the first.
///
/// [baseUrl] is the app's own base URL, used to reach the bundled assets.
String buildCertificateHtml(CertificateData d, {required String baseUrl}) {
  final fonts = _assetUrl(baseUrl, 'assets/fonts');

  return '''<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<title>प्रमाण पत्र - ${_esc(d.regNo)}</title>
<style>
@font-face {
  font-family: 'Noto Sans Devanagari';
  src: url('$fonts/NotoSansDevanagari-Regular.ttf') format('truetype');
  font-weight: 400;
}
@font-face {
  font-family: 'Noto Sans Devanagari';
  src: url('$fonts/NotoSansDevanagari-Bold.ttf') format('truetype');
  font-weight: 700;
}
@font-face {
  font-family: 'Yatra One';
  src: url('$fonts/YatraOne-Regular.ttf') format('truetype');
}
@font-face {
  font-family: 'Arimo';
  src: url('$fonts/Arimo-Bold.ttf') format('truetype');
  font-weight: 700;
}
@page { size: A4 portrait; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
  background: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.page {
  position: relative;
  width: 210mm;
  /* A millimetre short of A4, so rounding never spills onto a second page. */
  height: 296mm;
  overflow: hidden;
  margin: 0 auto;
}
.sheet {
  position: absolute;
  left: ${_margin.toStringAsFixed(2)}mm;
  top: ${_margin.toStringAsFixed(2)}mm;
  width: ${_sheetW}pt;
  height: ${_sheetH}pt;
  transform: scale(${_fit.toStringAsFixed(4)});
  transform-origin: 0 0;
  font-family: 'Noto Sans Devanagari', 'Nirmala UI', 'Mangal', sans-serif;
  color: #000;
  line-height: normal;
}

/* Frame and header, in the frame image's pixels. */
.art { position: absolute; left: 0; top: 0; width: 100%; height: 100%; }
.art text { font-family: 'Yatra One', 'Noto Sans Devanagari', sans-serif; }
.art .inv { font-size: 40.8px; fill: #e31e27; }
.art .heading {
  font-size: 129.2px;
  stroke: #fff;
  stroke-width: 13px;
  stroke-linejoin: round;
  paint-order: stroke;
}
.art .place { font-size: 63px; fill: #070705; }
.art .line { font-size: 40.7px; letter-spacing: -1px; fill: #070705; }
.art .lat, .art .phones { font-family: 'Arimo', Arial, sans-serif; font-weight: 700; }
.art .phones { font-size: 41.3px; letter-spacing: -0.7px; fill: #070705; }

.title {
  position: absolute;
  top: 133.47pt;
  left: ${(_sheetW / 2).toStringAsFixed(2)}pt;
  transform: translateX(-50%);
  height: 21.42pt;
  padding: 5pt 14pt 0;
  border-radius: 10.71pt;
  background: #1a0f5e;
  color: #fff;
  font-size: 11pt;
  font-weight: 700;
  letter-spacing: 0.4pt;
  white-space: nowrap;
}

.photo {
  position: absolute;
  left: 475.28pt;
  top: 150pt;
  width: 80pt;
  height: 80pt;
  border: 2pt solid #333;
  border-radius: 3pt;
  background: #fff;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}
.photo img { width: 100%; height: 100%; object-fit: cover; display: block; }
.photo span { font-size: 12pt; font-weight: 700; color: #777; }

/* A row of fields: 9.5pt labels, then a 1pt dotted line with the 10pt bold
   value written 5pt in and 1.38pt above the label's baseline. */
.row {
  position: absolute;
  left: 38pt;
  width: 402pt;
  display: flex;
  align-items: baseline;
  white-space: nowrap;
}
.row.spread { width: 424.28pt; justify-content: space-between; }
.f { display: flex; align-items: baseline; flex: none; }
.f + .f { margin-left: 12pt; }
.row.spread .f + .f { margin-left: 0; }
.f.hug { flex: 0 1 auto; min-width: 0; }
.l { font-size: 9.5pt; font-weight: 400; }
.ln { position: relative; margin-left: 4pt; flex: none; }
.f.hug .ln { flex: 0 1 auto; }
.ln::after, .sig .rule {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  height: 1pt;
  background: repeating-linear-gradient(to right, #000 0 1pt, transparent 1pt 2.2pt);
}
.ln::after { top: 13.66pt; }
.v {
  display: block;
  position: relative;
  top: -1.38pt;
  padding-left: 5pt;
  font-size: 10pt;
  font-weight: 700;
}

.rule-line {
  position: absolute;
  /* In line with the field labels, and ending short of the अध्यक्ष
     signature (from 370.44pt) so the stamp has the space above it. */
  left: 38pt;
  width: 317pt;
  font-size: 8.5pt;
  text-align: left;
  white-space: nowrap;
}

/* Signatures: the name over a dotted line, the role under it. */
.sig { position: absolute; top: 0; height: 100%; text-align: center; font-weight: 700; }
.sig .name { position: absolute; left: 0; right: 0; top: ${(363.94 - 0.896 * 9.5 + 0.25).toStringAsFixed(2)}pt; font-size: 9.5pt; white-space: nowrap; }
.sig .rule { top: 374.49pt; }
.sig .role { position: absolute; left: 0; right: 0; top: ${(388.55 - 0.896 * 9 - 0.19).toStringAsFixed(2)}pt; font-size: 9pt; }
</style>
</head>
<body>
<div class="page">${_sheetHtml(d, baseUrl)}
</div>
<script>
// A value too long for its line is shrunk to fit rather than run over.
function fit(el, room, size, min) {
  while (el.scrollWidth > room() && size > min) {
    size -= 0.25;
    el.style.fontSize = size + 'pt';
  }
}
function fitValues() {
  document.querySelectorAll('.v').forEach(function (el) {
    fit(el, function () { return el.parentNode.clientWidth; }, 10, 6);
  });
  // A long Yojna name shrinks its label until the row fits.
  document.querySelectorAll('.l.fit').forEach(function (el) {
    var row = el.closest('.row');
    var size = 9.5;
    while (row.scrollWidth > row.clientWidth && size > 6) {
      size -= 0.25;
      el.style.fontSize = size + 'pt';
    }
  });
  // The rule's lines share the size the longest one needs, so they read as
  // one block.
  var rules = document.querySelectorAll('.rule-line');
  var ruleSize = 8.5;
  rules.forEach(function (el) {
    fit(el, function () { return el.clientWidth; }, 8.5, 6);
    ruleSize = Math.min(ruleSize, parseFloat(el.style.fontSize) || 8.5);
  });
  rules.forEach(function (el) { el.style.fontSize = ruleSize + 'pt'; });
  document.querySelectorAll('.sig .name').forEach(function (el) {
    fit(el, function () { return el.clientWidth; }, 9.5, 6);
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
