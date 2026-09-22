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

/// Premium ornamental corner motif matching the reference certificate's
/// traditional Indian flowing vine/scroll design. [flip] mirrors horizontally,
/// [turn] vertically, so one drawing serves all four corners.
///
/// The design features: flowing S-curves extending from the corner along both
/// edges (L-shaped), large spiral scrolls at the endpoints, secondary vine
/// branches with leaf/petal shapes, small circular scroll accents, and dot
/// details — all in a delicate, single-color line-art style.
String _cornerMotif(String position, {bool flip = false, bool turn = false}) {
  final sx = flip ? -1 : 1;
  final sy = turn ? -1 : 1;
  return '''
<svg class="corner $position" viewBox="0 0 360 360" aria-hidden="true">
  <g transform="translate(${flip ? 360 : 0},${turn ? 360 : 0}) scale($sx,$sy)"
     fill="none" stroke="#3B8DC5" stroke-linecap="round" stroke-linejoin="round">

    <!-- ══ MAIN STRUCTURAL VINE ══ -->
    <!-- Primary flowing curve: top edge → corner → left edge -->
    <path d="M348,10 C290,10 230,18 180,38 C130,58 90,92 60,138
             C38,172 22,215 14,265 C10,290 10,320 10,348"
          stroke-width="2.2"/>
    <!-- Parallel companion line (slightly inset, thinner) -->
    <path d="M320,16 C270,18 218,30 172,50 C126,70 92,102 68,148
             C48,185 34,228 26,275 C22,300 20,325 18,340"
          stroke-width="1.0" opacity="0.45"/>

    <!-- ══ TOP-END SCROLL (large spiral) ══ -->
    <path d="M348,10 C355,22 352,40 340,50 C328,60 312,56 305,44
             C298,32 304,18 318,12 C328,8 340,10 346,16"
          stroke-width="2"/>
    <!-- Inner spiral detail -->
    <path d="M325,32 C318,24 320,16 330,14" stroke-width="1.2"/>

    <!-- ══ LEFT-END SCROLL (large spiral) ══ -->
    <path d="M10,348 C22,354 40,350 50,338 C60,326 56,310 44,303
             C32,296 18,302 12,316 C8,326 10,338 16,345"
          stroke-width="2"/>
    <!-- Inner spiral detail -->
    <path d="M32,323 C24,316 16,318 14,328" stroke-width="1.2"/>

    <!-- ══ BRANCH 1 — upper vine with scroll & leaves ══ -->
    <path d="M260,20 C248,36 232,48 215,52 C200,55 190,48 194,38
             C198,28 212,24 225,30"
          stroke-width="1.8"/>
    <!-- Leaf pair on branch 1 -->
    <path d="M238,30 C232,20 222,16 214,20 C222,26 230,30 236,35"
          stroke-width="1.2" fill="rgba(59,141,197,0.05)"/>
    <path d="M242,38 C238,28 230,22 222,24 C228,30 234,36 240,42"
          stroke-width="1.0" fill="rgba(59,141,197,0.04)"/>

    <!-- ══ BRANCH 2 — mid-upper vine with scroll & leaves ══ -->
    <path d="M148,55 C132,72 112,84 96,82 C84,80 80,70 86,62
             C92,54 106,52 115,60"
          stroke-width="1.8"/>
    <!-- Leaf pair on branch 2 -->
    <path d="M122,62 C114,50 102,45 92,50 C100,56 110,60 118,66"
          stroke-width="1.2" fill="rgba(59,141,197,0.05)"/>
    <path d="M130,70 C124,60 114,54 106,56 C112,62 120,68 128,74"
          stroke-width="1.0" fill="rgba(59,141,197,0.04)"/>

    <!-- ══ BRANCH 3 — mid-lower vine with scroll & leaves ══ -->
    <path d="M55,148 C40,168 30,192 32,210 C34,222 42,226 50,218
             C58,210 56,194 46,186"
          stroke-width="1.8"/>
    <!-- Leaf pair on branch 3 -->
    <path d="M46,196 C38,186 28,182 22,188 C28,194 36,198 44,200"
          stroke-width="1.2" fill="rgba(59,141,197,0.05)"/>
    <path d="M50,206 C44,198 36,192 28,194 C34,200 40,206 48,210"
          stroke-width="1.0" fill="rgba(59,141,197,0.04)"/>

    <!-- ══ BRANCH 4 — lower vine with scroll ══ -->
    <path d="M20,260 C32,248 46,240 56,244 C62,246 64,254 58,260
             C52,266 40,264 36,256"
          stroke-width="1.6"/>
    <!-- Leaf on branch 4 -->
    <path d="M48,248 C42,240 34,238 28,242 C34,248 40,250 46,252"
          stroke-width="1.0" fill="rgba(59,141,197,0.04)"/>

    <!-- ══ SMALL DECORATIVE CURLS ══ -->
    <!-- Upper accent curl -->
    <path d="M295,16 C288,26 278,30 270,28 C276,22 284,18 292,18"
          stroke-width="1.2"/>
    <!-- Side accent curl -->
    <path d="M16,295 C26,288 30,278 28,270 C22,276 18,284 18,292"
          stroke-width="1.2"/>
    <!-- Tiny curl near the corner -->
    <path d="M82,100 C74,110 62,114 56,108 C60,102 70,98 80,100"
          stroke-width="1.0"/>
    <!-- Upper-mid small curl -->
    <path d="M195,42 C190,50 182,52 178,48 C182,44 188,42 194,44"
          stroke-width="1.0"/>
    <!-- Lower-mid small curl -->
    <path d="M42,195 C50,190 52,182 48,178 C44,182 42,188 44,194"
          stroke-width="1.0"/>

    <!-- ══ DOT ACCENTS ══ -->
    <circle cx="310" cy="14" r="2.2" fill="#3B8DC5"/>
    <circle cx="14" cy="310" r="2.2" fill="#3B8DC5"/>
    <circle cx="275" cy="24" r="1.6" fill="#3B8DC5"/>
    <circle cx="24" cy="275" r="1.6" fill="#3B8DC5"/>
    <circle cx="220" cy="40" r="1.5" fill="#3B8DC5" opacity="0.7"/>
    <circle cx="40" cy="220" r="1.5" fill="#3B8DC5" opacity="0.7"/>
    <circle cx="160" cy="54" r="1.3" fill="#3B8DC5" opacity="0.6"/>
    <circle cx="54" cy="160" r="1.3" fill="#3B8DC5" opacity="0.6"/>
    <circle cx="100" cy="85" r="1.2" fill="#3B8DC5" opacity="0.5"/>
    <circle cx="85" cy="100" r="1.2" fill="#3B8DC5" opacity="0.5"/>
    <circle cx="68" cy="130" r="1.0" fill="#3B8DC5" opacity="0.45"/>
    <circle cx="130" cy="68" r="1.0" fill="#3B8DC5" opacity="0.45"/>

    <!-- ══ FINE TENDRIL WISPS ══ -->
    <path d="M340,14 C332,8 325,12 328,20" stroke-width="0.8" opacity="0.5"/>
    <path d="M14,340 C8,332 12,325 20,328" stroke-width="0.8" opacity="0.5"/>
    <path d="M108,68 C102,62 96,64 98,72" stroke-width="0.8" opacity="0.4"/>
    <path d="M68,108 C62,102 64,96 72,98" stroke-width="0.8" opacity="0.4"/>
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
  width: 36mm;
  height: 36mm;
  opacity: 0.92;
  z-index: 1;
}
.corner.tl { top: 2.5mm;    left: 2.5mm; }
.corner.tr { top: 2.5mm;    right: 2.5mm; }
.corner.bl { bottom: 2.5mm; left: 2.5mm; }
.corner.br { bottom: 2.5mm; right: 2.5mm; }

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
