import 'package:intl/intl.dart';

import '../../core/config/trust_info.dart';
import 'certificate_data.dart';

/// Hindi wording printed on the certificate, following the reference sheet the
/// client supplied. The app's own labels stay English; this page is handed to
/// members, so it is entirely Hindi.
class _Hi {
  const _Hi._();

  static const established = 'संस्था स्थापना';
  static const registration = 'संस्था रजीस्टर नं.';
  static const yojnaStarted = 'योजना प्रारंभ';
  static const certificate = 'प्रमाण पत्र';
  static const membershipNo = 'सदस्यता क्रमांक';
  static const date = 'दिनांक';
  static const photo = 'फोटो';
  static const name = 'नाम';
  static const gotra = 'गौत्र';
  static const jati = 'जाति';
  static const dob = 'जन्म तारीख';
  static const village = 'गांव / सिटी';
  static const district = 'जिला';
  static const state = 'राज्य';
  static const address = 'पता';
  static const phone = 'मोबाईल नं.';
  static const waris = 'वारिसदार';
  static const relation = 'सम्बन्ध';

  /// The amount sits between the label-less dotted line and this text:
  /// `..200.. रु प्रत्येक सहयोग पर लागु ।`
  static const perContribution = 'रु प्रत्येक सहयोग पर लागु ।';
  static const note = 'नोंध';
  static const karyakarta = 'कार्यकर्ता';
  static const president = 'अध्यक्ष';
  static const headOffice = 'हेड ओफिस';
  static const mobilePrefix = 'Mo.';
}

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

/// One `label ......value......` field. [grow] sets how much of the row it takes.
String _field(String label, String value, {int grow = 1}) =>
    '<div class="f" style="flex:$grow">'
    '<span class="lbl">${_esc(label)}</span>'
    '<span class="v">${_esc(value)}</span>'
    '</div>';

String _row(List<String> fields) => '<div class="row">${fields.join()}</div>';

/// Text longer than the arc is clipped rather than wrapped, so this is set to
/// leave headroom for the trust's name. A materially longer name needs it
/// lowered.
const _headingSize = 76;

/// The trust's name across the top: arched, filled crimson and outlined in
/// cream so it reads as the embossed heading on the reference sheet.
///
/// Drawn as SVG rather than styled text because CSS cannot curve a baseline.
/// The arc is deliberately shallow — Chrome shapes the Devanagari first and
/// then walks the glyphs along the path, and a steep curve pulls matras off
/// their consonants.
String _heading(String text) => '''
<svg class="title" viewBox="0 0 1200 170" preserveAspectRatio="xMidYMid meet"
     role="img" aria-label="${_esc(text)}">
  <defs>
    <path id="arc" d="M 26,140 Q 600,62 1174,140" fill="none"/>
  </defs>
  <text text-anchor="middle" font-size="$_headingSize" paint-order="stroke"
        stroke="#ffffff" stroke-width="9" stroke-linejoin="round" fill="#B5121B">
    <textPath href="#arc" startOffset="50%">${_esc(text)}</textPath>
  </text>
</svg>''';

/// A corner flourish. [flip] mirrors it horizontally, [turn] vertically, so one
/// drawing serves all four corners of the frame.
String _flourish(String position, {bool flip = false, bool turn = false}) {
  final sx = flip ? -1 : 1;
  final sy = turn ? -1 : 1;
  return '''
<svg class="flourish $position" viewBox="0 0 120 120" aria-hidden="true">
  <g transform="translate(${flip ? 120 : 0},${turn ? 120 : 0}) scale($sx,$sy)"
     fill="none" stroke-linecap="round">
    <path d="M6 42 C 6 18, 18 6, 42 6" stroke="#B5121B" stroke-width="2.4"/>
    <path d="M14 46 C 14 24, 24 14, 46 14" stroke="#B5121B" stroke-width="2.4"/>
    <path d="M22 40 C 30 24, 40 22, 54 22 C 46 30, 44 40, 30 46 C 24 48, 20 46, 22 40 Z" stroke="#0757A5" stroke-width="2"/>
    <path d="M40 52 C 52 44, 62 44, 72 48 C 62 56, 52 58, 44 56" stroke="#B5121B" stroke-width="2.4"/>
    <path d="M52 26 C 62 26, 70 30, 76 36" stroke="#0757A5" stroke-width="2"/>
  </g>
</svg>''';
}

/// Builds the printable membership certificate as one self-contained HTML
/// page: a single A4 landscape sheet, the certificate frame and nothing
/// outside it, with no network calls once it is open.
///
/// The reference sheet had a tear-off receipt slip below a cut line; the client
/// asked for it off (21 Sep 2026), so the frame now fills the page.
///
/// [baseUrl] is the app's own base URL, used to reach the bundled Devanagari
/// fonts and the logo. It must be absolute, because the page is opened from a
/// `blob:` URL, which cannot resolve relative paths itself.
String buildCertificateHtml(CertificateData d, {required String baseUrl}) {
  final body = _assetUrl(baseUrl, 'assets/fonts/NotoSansDevanagari');
  final display = _assetUrl(baseUrl, TrustInfo.headingFontAsset);
  final logo = TrustInfo.hasLogo ? _assetUrl(baseUrl, TrustInfo.logoAsset) : '';
  final signature = TrustInfo.hasSignature
      ? _assetUrl(baseUrl, TrustInfo.signatureAsset)
      : '';

  final amount =
      d.contributionAmount > 0 ? _money.format(d.contributionAmount) : '';
  final phones = TrustInfo.headOfficePhones.join(', ');
  final office = [
    _esc(TrustInfo.headOfficeAddress),
    if (phones.isNotEmpty) '${_Hi.mobilePrefix}${_esc(phones)}',
  ].where((p) => p.isNotEmpty).join(' ');

  // One invocation centres; three spread left, centre and right.
  final invocations =
      TrustInfo.invocations.map((i) => '<span>${_esc(i)}</span>').join();
  final invocationClass =
      TrustInfo.invocations.length == 1 ? 'invocations one' : 'invocations';

  final logoMark = logo.isEmpty
      ? '<div class="logo-fallback"></div>'
      : '<img src="$logo" alt="">';
  final signMark = signature.isEmpty
      ? '<div class="line"></div>'
      : '<img src="$signature" alt="">';

  // The reference sheet's row order: सम्बन्ध closes the पता line, and
  // मोबाईल नं. shares its row with वारिसदार.
  final rows = [
    _row([
      _field(_Hi.name, d.fullName, grow: 5),
      _field(_Hi.gotra, d.gotra, grow: 2),
      _field(_Hi.jati, d.jati, grow: 2),
    ]),
    _row([
      _field(_Hi.dob, _day(d.dob)),
      _field(_Hi.village, d.village),
      _field(_Hi.district, d.district),
      _field(_Hi.state, d.state),
    ]),
    _row([
      _field(_Hi.address, d.address, grow: 5),
      _field(_Hi.relation, d.warisRelation, grow: 2),
    ]),
    _row([
      _field(_Hi.phone, d.phone, grow: 3),
      _field(_Hi.waris, d.warisName, grow: 4),
    ]),
  ].join('\n        ');

  return '''<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<title>${_esc(_Hi.certificate)} - ${_esc(d.regNo)}</title>
<style>
@font-face {
  font-family: 'CertHindi';
  src: url('$body-Regular.ttf') format('truetype');
  font-weight: 400;
}
@font-face {
  font-family: 'CertHindi';
  src: url('$body-Bold.ttf') format('truetype');
  font-weight: 700;
}
@font-face {
  font-family: 'CertTitle';
  src: url('$display') format('truetype');
  font-weight: 400;
}
@page { size: A4 landscape; margin: 4mm; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
  font-family: 'CertHindi', 'Noto Sans Devanagari', sans-serif;
  color: #003B78;
  background: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.sheet {
  width: 289mm;
  height: 202mm;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
}
/* ---------- certificate frame ---------- */
.cert {
  position: relative;
  flex: 1;
  min-height: 0;
  border: 1.2mm solid #B5121B;
  border-radius: 2mm;
  background: radial-gradient(ellipse at 50% 50%, #F7FCFE 0%, #EEF8FC 40%, #D9EAF3 100%);
  padding: 2.5mm 7mm 1.5mm;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.cert::before {
  content: '';
  position: absolute;
  inset: 1.6mm;
  border: 0.6mm solid #0757A5;
  border-radius: 1.4mm;
  pointer-events: none;
  z-index: 0;
}
.cert::after {
  content: '';
  position: absolute;
  inset: 3mm;
  border: 0.2mm solid rgba(7, 87, 165, 0.4);
  border-radius: 1mm;
  pointer-events: none;
  z-index: 0;
}
.geometric-bg {
  position: absolute;
  inset: 0;
  background-image: 
    linear-gradient(135deg, rgba(40,140,210,0.06) 0%, rgba(40,140,210,0) 35%),
    linear-gradient(-135deg, rgba(40,140,210,0.06) 0%, rgba(40,140,210,0) 35%),
    url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="700" viewBox="0 0 1000 700" preserveAspectRatio="none"><polygon points="0,200 150,350 0,500" fill="rgba(40,140,210,0.04)"/><polygon points="1000,200 850,350 1000,500" fill="rgba(40,140,210,0.04)"/><path d="M450 300 C470 280, 530 280, 550 300 C570 320, 570 380, 550 400 C530 420, 470 420, 450 400 C430 380, 430 320, 450 300 Z" fill="none" stroke="rgba(40,140,210,0.05)" stroke-width="2"/></svg>');
  background-size: 100% 100%;
  pointer-events: none;
  z-index: 0;
}
.waves {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 45mm;
  background-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 150" preserveAspectRatio="none"><path d="M0,150 L1000,150 L1000,100 Q800,130 500,80 Q200,30 0,100 Z" fill="rgba(40,140,210,0.1)"/><path d="M0,150 L1000,150 L1000,120 Q800,145 500,110 Q200,75 0,130 Z" fill="rgba(7,87,165,0.08)"/><path d="M0,150 L1000,150 L1000,135 Q750,160 500,135 Q250,110 0,145 Z" fill="rgba(0,59,120,0.1)"/></svg>');
  background-size: 100% 100%;
  pointer-events: none;
  z-index: 0;
}
.flourish {
  position: absolute;
  width: 16mm;
  height: 16mm;
  opacity: 0.85;
}
.flourish.tl { top: 2mm; left: 2mm; }
.flourish.tr { top: 2mm; right: 2mm; }
.flourish.bl { bottom: 2mm; left: 2mm; }
.flourish.br { bottom: 2mm; right: 2mm; }
/* ---------- masthead ---------- */
.invocations {
  display: flex;
  justify-content: space-between;
  font-size: 8.5pt;
  padding: 0 6mm;
  position: relative;
  z-index: 1;
}
.invocations.one { justify-content: center; }
.regline {
  display: flex;
  justify-content: center;
  gap: 18mm;
  font-size: 8.5pt;
  margin-top: 0.8mm;
}
.regline b { font-weight: 700; color: #B5121B; }
.states {
  display: flex;
  justify-content: space-between;
  font-size: 12.5pt;
  font-weight: 700;
  padding: 0 6mm;
  margin-top: 1mm;
}
.title {
  display: block;
  width: 172mm;
  height: 25mm;
  margin: -8mm auto 0;
  font-family: 'CertTitle', 'CertHindi', sans-serif;
  filter: drop-shadow(0.5mm 0.5mm 0.4mm rgba(0, 59, 120, 0.35));
}
.logo {
  width: 23mm;
  height: 23mm;
  margin: 0.5mm auto 0;
  flex: none;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  z-index: 2;
}
.logo img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  mix-blend-mode: multiply;
}
.logo-fallback {
  width: 100%;
  height: 100%;
  border: 0.4mm solid #003B78;
  border-radius: 50%;
}
/* ---------- scheme bar ---------- */
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 5mm;
  margin-top: 0.5mm;
  font-size: 10pt;
}
.head .mid { text-align: center; flex: none; position: relative; z-index: 2; }
.head .side { flex: 1; padding-top: 2mm; }
.head .side.right { text-align: right; }
.head .val {
  color: #B5121B;
  font-weight: 700;
  border-bottom: 0.3mm dotted #003B78;
  padding: 0 3mm;
  min-width: 32mm;
  display: inline-block;
  text-align: center;
}
.cert-title {
  background: #B5121B;
  color: #fff;
  border: 0.4mm solid #d4af37;
  border-radius: 2mm;
  padding: 1.5mm 6mm;
  font-weight: 700;
  font-size: 12pt;
  display: inline-block;
  box-shadow: 0 1mm 2mm rgba(0,0,0,0.1);
}
/* ---------- fields ---------- */
.body { display: flex; gap: 5mm; margin-top: 1.5mm; flex: 1; min-height: 0; position: relative; z-index: 2; }
.photo {
  width: 32mm;
  height: 40mm;
  border: 0.4mm solid #003B78;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 8pt;
  color: #003B78;
  flex: none;
  background: rgba(255,255,255,0.4);
}
.fields {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 1.5mm;
}
.row { display: flex; gap: 6mm; }
.f { display: flex; align-items: baseline; gap: 2mm; min-width: 0; }
.f .lbl { font-size: 10pt; white-space: nowrap; font-weight: 700; }
.f .v {
  flex: 1;
  min-width: 0;
  border-bottom: 0.3mm dotted #003B78;
  color: #B5121B;
  font-weight: 700;
  font-size: 10pt;
  padding: 0 2mm;
  min-height: 5mm;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
/* ---------- amount, note, signature ---------- */
.tail { display: flex; gap: 6mm; align-items: flex-end; }
.tail .left { flex: 1; min-width: 0; }
.amount { display: flex; align-items: baseline; gap: 2mm; font-size: 10pt; font-weight: 700; }
.amount .v {
  border-bottom: 0.3mm dotted #003B78;
  color: #B5121B;
  font-weight: 700;
  min-width: 24mm;
  text-align: center;
  padding: 0 2mm;
}
.tail .row { margin-top: 2mm; align-items: flex-end; }
.note .v {
  text-align: center;
  white-space: normal;
  overflow: visible;
  text-overflow: clip;
  line-height: 1.25;
}
.sign { text-align: center; font-size: 9.5pt; flex: none; width: 50mm; display: flex; flex-direction: column; align-items: center; }
.sign img { height: 10mm; display: block; margin: 0 auto 0.5mm; }
.sign .line { height: 10mm; border-bottom: 0.3mm solid #003B78; width: 100%; }
.sign b { display: block; font-weight: 700; margin-top: 1mm; }
/* ---------- footer ---------- */
.slogan {
  align-self: center;
  background: #003B78;
  color: #fff;
  text-align: center;
  font-size: 10pt;
  font-weight: 700;
  padding: 0.8mm 6mm;
  border-radius: 1mm;
  margin-top: 1mm;
  position: relative;
  z-index: 2;
}
.office { text-align: center; font-size: 9.5pt; margin-top: 0.8mm; position: relative; z-index: 2; }
.office .label { font-weight: 700; }
</style>
</head>
<body>
<div class="sheet">
  <div class="cert">
    <div class="geometric-bg"></div>
    <div class="waves"></div>
    ${_flourish('tl')}
    ${_flourish('tr', flip: true)}
    ${_flourish('bl', turn: true)}
    ${_flourish('br', flip: true, turn: true)}

    <div class="$invocationClass">$invocations</div>
    <div class="regline">
      <span>${_esc(_Hi.established)} : <b>${_esc(TrustInfo.establishedOn)}</b></span>
      <span>${_esc(_Hi.registration)} <b>${_esc(TrustInfo.registrationNo)}</b></span>
    </div>
    <div class="states">
      <span>${_esc(TrustInfo.leftState)}</span>
      <span>${_esc(TrustInfo.rightState)}</span>
    </div>
    ${_heading(TrustInfo.heading)}
    <div class="logo">$logoMark</div>

    <div class="head">
      <div class="side">
        ${_esc(_Hi.membershipNo)}
        <span class="val">${_esc(d.regNo)}</span>
      </div>
      <div class="mid">
        <div class="cert-title">&bull; ${_esc(_Hi.certificate)} &bull;</div>
      </div>
      <div class="side right">
        ${_esc(_Hi.date)}
        <span class="val">${_esc(_day(d.issuedOn))}</span>
      </div>
    </div>

    <div class="body">
      <div class="photo">${_esc(_Hi.photo)}</div>
      <div class="fields">
        $rows
        <div class="tail">
          <div class="left">
            <div class="amount">
              <span class="v">${_esc(amount)}</span>
              <span>${_esc(_Hi.perContribution)}</span>
            </div>
            <div class="row">
              ${_field(_Hi.karyakarta, d.agentName, grow: 3)}
              <div class="f note" style="flex:4">
                <span class="lbl">${_esc(_Hi.note)}</span>
                <span class="v">${_esc(d.payoutNote)}</span>
              </div>
            </div>
          </div>
          <div class="sign">
            $signMark
            <b>${_esc(_Hi.president)}</b>
          </div>
        </div>
      </div>
    </div>

    <div class="slogan">${_esc(TrustInfo.slogan)}</div>
    <div class="office">
      <div class="label">${_esc(_Hi.headOffice)}</div>
      <div>$office</div>
    </div>
  </div>
</div>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>''';
}
