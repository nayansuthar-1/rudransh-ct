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

/// Premium ornamental corner motif. [flip] mirrors horizontally, [turn]
/// vertically, so one drawing serves all four corners. This is a richer,
/// more traditional Indian-inspired design than the original simple curves.
String _cornerMotif(String position, {bool flip = false, bool turn = false}) {
  final sx = flip ? -1 : 1;
  final sy = turn ? -1 : 1;
  return '''
<svg class="corner $position" viewBox="0 0 160 160" aria-hidden="true">
  <g transform="translate(${flip ? 160 : 0},${turn ? 160 : 0}) scale($sx,$sy)"
     fill="none" stroke-linecap="round" stroke-linejoin="round">
    <!-- Outer arch pair -->
    <path d="M4 50 C 4 16, 16 4, 50 4" stroke="#0A3D6B" stroke-width="2.2"/>
    <path d="M8 54 C 8 22, 22 8, 54 8" stroke="#0757A5" stroke-width="1.4" stroke-dasharray="0.6 2.4"/>
    <path d="M12 52 C 12 24, 24 12, 52 12" stroke="#0A3D6B" stroke-width="2.2"/>
    <!-- Lotus petal motif -->
    <path d="M20 48 C 28 28, 44 20, 56 20 C 48 32, 42 44, 28 52 C 22 55, 18 52, 20 48 Z"
          fill="rgba(7,87,165,0.06)" stroke="#0757A5" stroke-width="1.6"/>
    <path d="M32 54 C 38 42, 48 36, 60 34 C 54 44, 48 52, 38 58 C 34 60, 30 58, 32 54 Z"
          fill="rgba(181,18,27,0.04)" stroke="#B5121B" stroke-width="1.4"/>
    <!-- Inner floral curl -->
    <path d="M44 60 C 56 50, 66 48, 78 52 C 68 60, 58 64, 48 62" stroke="#0757A5" stroke-width="1.6"/>
    <path d="M58 24 C 68 22, 78 26, 86 34" stroke="#B5121B" stroke-width="1.4"/>
    <!-- Dot accents -->
    <circle cx="50" cy="6" r="1.6" fill="#0757A5"/>
    <circle cx="6" cy="50" r="1.6" fill="#0757A5"/>
    <circle cx="26" cy="26" r="1.2" fill="#B5121B"/>
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
  final memberPhoto = d.photoUrl.isNotEmpty
      ? '<img src="${_esc(d.photoUrl)}" alt="">'
      : '${_esc(_Hi.photo)}';

  final rows = [
    _row([
      _field(_Hi.name, d.fullName, grow: 5),
      _field(_Hi.gotra, d.gotra, grow: 2),
      _field(_Hi.jati, d.jati, grow: 2),
    ]),
    _row([
      _field(_Hi.dob, _day(d.dob)),
      _field(_Hi.phone, d.phone, grow: 2),
      _field(_Hi.village, d.village, grow: 3),
    ]),
    _row([
      _field(_Hi.district, d.district, grow: 3),
      _field(_Hi.state, d.state, grow: 3),
      _field(_Hi.address, d.address, grow: 5),
    ]),
    _row([
      _field(_Hi.waris, d.warisName, grow: 4),
      _field(_Hi.relation, d.warisRelation, grow: 2),
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
@page { size: A4 landscape; margin: 3mm; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
  font-family: 'CertHindi', 'Noto Sans Devanagari', sans-serif;
  color: #0A3D6B;
  background: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.sheet {
  width: 291mm;
  height: 204mm;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
}

/* ═══════════════════════════════════════════════════════════════
   PREMIUM MULTI-LAYER BORDER FRAME
   ═══════════════════════════════════════════════════════════════ */
.cert {
  position: relative;
  flex: 1;
  min-height: 0;
  border: 1.6mm solid #0A3D6B;
  border-radius: 1.5mm;
  background: #EBF4FA;
  padding: 5mm 8mm 3mm;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
/* Second border — thin navy */
.cert::before {
  content: '';
  position: absolute;
  inset: 2.2mm;
  border: 0.35mm solid #0A3D6B;
  border-radius: 1mm;
  pointer-events: none;
  z-index: 0;
}
/* Third border — hairline decorative */
.cert::after {
  content: '';
  position: absolute;
  inset: 3.4mm;
  border: 0.8mm solid rgba(7, 87, 165, 0.18);
  border-radius: 0.8mm;
  pointer-events: none;
  z-index: 0;
}

/* ═══════════════════════════════════════════════════════════════
   SUBTLE WATERMARK / GEOMETRIC BACKGROUND
   ═══════════════════════════════════════════════════════════════ */
.watermark {
  position: absolute;
  inset: 0;
  /* Subtle repeating geometric — very faint diamond / mandala lattice */
  background-image:
    url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='80' height='80' viewBox='0 0 80 80'%3E%3Cpath d='M40 8 L72 40 L40 72 L8 40 Z' fill='none' stroke='%230757A5' stroke-width='0.3' opacity='0.08'/%3E%3Ccircle cx='40' cy='40' r='6' fill='none' stroke='%230757A5' stroke-width='0.25' opacity='0.06'/%3E%3C/svg%3E");
  background-size: 18mm 18mm;
  pointer-events: none;
  z-index: 0;
}

/* Radial powder-blue glow behind centre content */
.glow {
  position: absolute;
  inset: 0;
  background: radial-gradient(ellipse at 50% 38%, rgba(215,235,248,0.7) 0%, rgba(235,244,250,0.0) 65%);
  pointer-events: none;
  z-index: 0;
}

/* Extremely soft wave at the bottom */
.waves {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  height: 38mm;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1200 150' preserveAspectRatio='none'%3E%3Cpath d='M0,150 L1200,150 L1200,105 Q950,135 600,85 Q250,35 0,105 Z' fill='rgba(10,61,107,0.045)'/%3E%3Cpath d='M0,150 L1200,150 L1200,125 Q900,148 600,115 Q300,82 0,135 Z' fill='rgba(7,87,165,0.035)'/%3E%3C/svg%3E");
  background-size: 100% 100%;
  pointer-events: none;
  z-index: 0;
}

/* ═══════════════════════════════════════════════════════════════
   CORNER MOTIFS
   ═══════════════════════════════════════════════════════════════ */
.corner {
  position: absolute;
  width: 22mm;
  height: 22mm;
  opacity: 0.9;
  z-index: 1;
}
.corner.tl { top: 3mm;    left: 3mm; }
.corner.tr { top: 3mm;    right: 3mm; }
.corner.bl { bottom: 3mm; left: 3mm; }
.corner.br { bottom: 3mm; right: 3mm; }

/* ═══════════════════════════════════════════════════════════════
   MASTHEAD — invocations, registration, states
   ═══════════════════════════════════════════════════════════════ */
.invocations {
  display: flex;
  justify-content: space-between;
  font-size: 8.5pt;
  padding: 0 8mm;
  position: relative;
  z-index: 1;
  color: #B5121B;
  font-weight: 700;
  letter-spacing: 0.02em;
}
.invocations.one { justify-content: center; }

.regline {
  display: flex;
  justify-content: center;
  gap: 22mm;
  font-size: 8pt;
  margin-top: 1mm;
  position: relative;
  z-index: 1;
  color: #0A3D6B;
  letter-spacing: 0.01em;
}
.regline b { font-weight: 700; color: #B5121B; }

.states {
  display: flex;
  justify-content: space-between;
  font-size: 12pt;
  font-weight: 700;
  padding: 0 8mm;
  margin-top: 1mm;
  position: relative;
  z-index: 1;
  color: #0A3D6B;
}

/* ═══════════════════════════════════════════════════════════════
   TRUST NAME (arched SVG) & LOGO
   ═══════════════════════════════════════════════════════════════ */
.title {
  display: block;
  width: 178mm;
  height: 26mm;
  margin: -8mm auto 0;
  font-family: 'CertTitle', 'CertHindi', sans-serif;
  filter: drop-shadow(0.4mm 0.6mm 0.6mm rgba(10, 61, 107, 0.25));
  position: relative;
  z-index: 2;
}
.logo {
  width: 24mm;
  height: 24mm;
  margin: 0mm auto 0;
  flex: none;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  z-index: 2;
  /* Subtle circular halo around the logo */
  background: radial-gradient(circle, rgba(255,255,255,0.9) 40%, rgba(215,235,248,0.3) 100%);
  border-radius: 50%;
  padding: 1mm;
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
  border: 0.4mm solid #0A3D6B;
  border-radius: 50%;
}

/* ═══════════════════════════════════════════════════════════════
   SCHEME BAR — membership no · प्रमाण पत्र badge · date
   ═══════════════════════════════════════════════════════════════ */
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 5mm;
  margin-top: 1mm;
  font-size: 10pt;
  position: relative;
  z-index: 2;
}
.head .mid { text-align: center; flex: none; }
.head .side { flex: 1; padding-top: 1mm; font-weight: 600; }
.head .side.right { text-align: right; }
.head .val {
  color: #B5121B;
  font-weight: 700;
  border-bottom: 0.3mm dotted #4A7FAF;
  padding: 0 4mm;
  min-width: 34mm;
  display: inline-block;
  text-align: center;
}

/* ── Premium ribbon badge for the certificate title ── */
.cert-title {
  display: inline-block;
  position: relative;
  background: linear-gradient(180deg, #0F4C81 0%, #0A3D6B 100%);
  color: #fff;
  font-weight: 700;
  font-size: 13pt;
  padding: 2mm 10mm;
  border-radius: 0.8mm;
  letter-spacing: 0.06em;
  box-shadow:
    0 1mm 3mm rgba(10,61,107,0.25),
    inset 0 0.4mm 0 rgba(255,255,255,0.12);
  border: 0.3mm solid rgba(212,175,55,0.5);
}
/* Small ribbon tails */
.cert-title::before,
.cert-title::after {
  content: '';
  position: absolute;
  top: 50%;
  width: 5mm;
  height: 0;
  border-top: 3.5mm solid #0A3D6B;
  border-bottom: 3.5mm solid #0A3D6B;
  transform: translateY(-50%);
}
.cert-title::before {
  right: 100%;
  border-left: 2.5mm solid transparent;
  border-right: none;
}
.cert-title::after {
  left: 100%;
  border-right: 2.5mm solid transparent;
  border-left: none;
}

/* ═══════════════════════════════════════════════════════════════
   BODY — fields + photo
   ═══════════════════════════════════════════════════════════════ */
.body {
  display: flex;
  gap: 5mm;
  margin-top: 2mm;
  flex: 1;
  min-height: 0;
  position: relative;
  z-index: 2;
}

/* ── Photo frame (premium) ── */
.photo {
  width: 32mm;
  height: 40mm;
  border: 0.5mm solid #0A3D6B;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 8pt;
  color: #4A7FAF;
  flex: none;
  background: rgba(255,255,255,0.6);
  overflow: hidden;
  box-shadow:
    0 0 0 0.3mm rgba(7,87,165,0.12),
    0 0.5mm 2mm rgba(10,61,107,0.08);
}
.photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* ── Field rows ── */
.fields {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 2mm;
}
.row { display: flex; gap: 5mm; }
.f { display: flex; align-items: baseline; gap: 1.5mm; min-width: 0; }
.f .lbl {
  font-size: 10pt;
  white-space: nowrap;
  font-weight: 700;
  color: #0A3D6B;
}
.f .v {
  flex: 1;
  min-width: 0;
  border-bottom: 0.3mm dotted #4A7FAF;
  color: #B5121B;
  font-weight: 700;
  font-size: 10pt;
  padding: 0 2mm;
  min-height: 5.5mm;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  line-height: 1.5;
}

/* ═══════════════════════════════════════════════════════════════
   TAIL — amount, karyakarta/note, signature
   ═══════════════════════════════════════════════════════════════ */
.tail { display: flex; gap: 6mm; align-items: flex-end; }
.tail .left { flex: 1; min-width: 0; }
.amount {
  display: flex;
  align-items: baseline;
  gap: 2mm;
  font-size: 10pt;
  font-weight: 700;
}
.amount .v {
  border-bottom: 0.3mm dotted #4A7FAF;
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

/* ── Signature block ── */
.sign {
  text-align: center;
  font-size: 9.5pt;
  flex: none;
  width: 50mm;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.sign img { height: 10mm; display: block; margin: 0 auto 0.5mm; }
.sign .line { height: 10mm; border-bottom: 0.3mm solid #0A3D6B; width: 100%; }
.sign b { display: block; font-weight: 700; margin-top: 1mm; color: #0A3D6B; }

/* ═══════════════════════════════════════════════════════════════
   FOOTER — slogan ribbon + head office
   ═══════════════════════════════════════════════════════════════ */
.slogan {
  align-self: center;
  position: relative;
  z-index: 2;
  margin-top: 1.5mm;
  /* Ribbon background */
  background: linear-gradient(180deg, #0F4C81 0%, #0A3D6B 100%);
  color: #fff;
  text-align: center;
  font-size: 9.5pt;
  font-weight: 700;
  padding: 1mm 12mm;
  border-radius: 0.6mm;
  letter-spacing: 0.03em;
  box-shadow: 0 0.8mm 2mm rgba(10,61,107,0.18);
}
.office {
  text-align: center;
  font-size: 9pt;
  margin-top: 1mm;
  position: relative;
  z-index: 2;
  color: #0A3D6B;
}
.office .label { font-weight: 700; }

/* ── Decorative thin rule above footer ── */
.footer-rule {
  width: 70%;
  margin: 1.5mm auto 0;
  border: none;
  border-top: 0.2mm solid rgba(7,87,165,0.2);
  position: relative;
  z-index: 2;
}
</style>
</head>
<body>
<div class="sheet">
  <div class="cert">
    <!-- Background layers -->
    <div class="watermark"></div>
    <div class="glow"></div>
    <div class="waves"></div>

    <!-- Ornamental corners -->
    ${_cornerMotif('tl')}
    ${_cornerMotif('tr', flip: true)}
    ${_cornerMotif('bl', turn: true)}
    ${_cornerMotif('br', flip: true, turn: true)}

    <!-- Invocations -->
    <div class="$invocationClass">$invocations</div>

    <!-- Registration line -->
    <div class="regline">
      <span>${_esc(_Hi.established)} : <b>${_esc(TrustInfo.establishedOn)}</b></span>
      <span>${_esc(_Hi.registration)} <b>${_esc(TrustInfo.registrationNo)}</b></span>
    </div>

    <!-- State names -->
    <div class="states">
      <span>${_esc(TrustInfo.leftState)}</span>
      <span>${_esc(TrustInfo.rightState)}</span>
    </div>

    <!-- Trust name (arched) -->
    ${_heading(TrustInfo.heading)}

    <!-- Logo -->
    <div class="logo">$logoMark</div>

    <!-- Membership No · Certificate Title · Date -->
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

    <!-- Body: fields + photo -->
    <div class="body">
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
      <div class="photo">$memberPhoto</div>
    </div>

    <!-- Footer -->
    <hr class="footer-rule">
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
