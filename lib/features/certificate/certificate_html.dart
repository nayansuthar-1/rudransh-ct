import 'package:intl/intl.dart';

import '../../core/config/trust_info.dart';
import 'certificate_data.dart';

/// Hindi wording printed on the certificate, following the reference sheet the
/// client supplied. The app's own labels stay English; this page is handed to
/// members, so it is entirely Hindi.
class _Hi {
  const _Hi._();

  static const established = 'स्थापना';
  static const registration = 'संस्था रजीस्टर नं.';
  static const certificate = 'प्रमाण पत्र';
  static const membershipNo = 'सदस्यता क्रमांक';
  static const date = 'दिनांक';
  static const photo = 'फोटो';
  static const name = 'नाम';
  static const gotra = 'गोत्र';
  static const jati = 'जाति';
  static const dob = 'जन्म तारीख';
  static const village = 'गाँव / सिटी';
  static const district = 'जिला';
  static const state = 'राज्य';
  static const address = 'पता';
  static const phone = 'मोबाइल नं.';
  static const waris = 'वारिसदार';
  static const relation = 'सम्बन्ध';
  static const perContribution = 'प्रत्येक सहयोग';
  static const note = 'नोंध';
  static const karyakarta = 'कार्यकर्ता';
  static const president = 'अध्यक्ष';
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

/// Builds the printable membership certificate as one self-contained HTML
/// page: a single A4 landscape sheet, the certificate frame and nothing
/// outside it, with no network calls once it is open.
///
/// [baseUrl] is the app's own base URL, used to reach the bundled Devanagari
/// fonts and the logo. It must be absolute, because the page is opened from a
/// `blob:` URL, which cannot resolve relative paths itself.
String buildCertificateHtml(CertificateData d, {required String baseUrl}) {
  final body = _assetUrl(baseUrl, 'assets/fonts/NotoSansDevanagari');
  final display = _assetUrl(baseUrl, TrustInfo.headingFontAsset);
  final logo = TrustInfo.hasLogo ? _assetUrl(baseUrl, TrustInfo.logoAsset) : '';
  final shiva =
      TrustInfo.hasShiva ? _assetUrl(baseUrl, TrustInfo.shivaAsset) : '';
  final signature = TrustInfo.hasSignature
      ? _assetUrl(baseUrl, TrustInfo.signatureAsset)
      : '';

  final amount =
      d.contributionAmount > 0 ? _money.format(d.contributionAmount) : '';
  final phones = TrustInfo.headOfficePhones.join(' / ');

  final shivaMark = shiva.isEmpty
      ? '<div class="logo-fallback"></div>'
      : '<img src="$shiva" alt="Lord Shiva">';
  final logoMark = logo.isEmpty
      ? '<div class="logo-fallback"></div>'
      : '<img src="$logo" alt="Logo">';
  final signMark = signature.isEmpty
      ? '<div class="sign-line"></div>'
      : '<img src="$signature" alt="">';
  final memberPhoto = d.photoUrl.isNotEmpty
      ? '<img src="${_esc(d.photoUrl)}" alt="">'
      : _esc(_Hi.photo);

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
  color: #1a1a4e;
  background: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

/* ═══════════════════════════════════════════════════════════════
   SHEET — A4 landscape container
   ═══════════════════════════════════════════════════════════════ */
.sheet {
  width: 291mm;
  height: 204mm;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
}

/* ═══════════════════════════════════════════════════════════════
   OUTER FRAME — thick blue border with golden inner border
   ═══════════════════════════════════════════════════════════════ */
.cert {
  position: relative;
  flex: 1;
  min-height: 0;
  border: 3mm solid #0077c0;
  background: linear-gradient(180deg, #e8f0f8 0%, #f0f4fa 40%, #e4ecf5 100%);
  padding: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Golden inner border line */
.inner-border {
  position: absolute;
  top: 2mm;
  left: 2mm;
  right: 2mm;
  bottom: 2mm;
  border: 0.6mm solid #c8a84e;
  pointer-events: none;
  z-index: 3;
}

/* ═══════════════════════════════════════════════════════════════
   SUBTLE BACKGROUND PATTERN
   ═══════════════════════════════════════════════════════════════ */
.watermark {
  position: absolute;
  inset: 0;
  background-image:
    radial-gradient(circle, rgba(7, 87, 165, 0.07) 0.5mm, transparent 0.5mm);
  background-size: 7mm 7mm;
  pointer-events: none;
  z-index: 0;
}

.glow {
  position: absolute;
  inset: 0;
  background: radial-gradient(ellipse at 50% 35%,
    rgba(255,255,255,0.5) 0%,
    rgba(235,244,250,0.0) 60%);
  pointer-events: none;
  z-index: 0;
}

/* ═══════════════════════════════════════════════════════════════
   CORNER DECORATIONS — ornamental corner accents
   ═══════════════════════════════════════════════════════════════ */
.corner-decor {
  position: absolute;
  width: 22mm;
  height: 22mm;
  z-index: 4;
  pointer-events: none;
}
.corner-decor.tl { top: 1mm; left: 1mm; }
.corner-decor.tr { top: 1mm; right: 1mm; }
.corner-decor.bl { bottom: 1mm; left: 1mm; }
.corner-decor.br { bottom: 1mm; right: 1mm; }

/* ═══════════════════════════════════════════════════════════════
   CONTENT WRAPPER — padding inside the golden border
   ═══════════════════════════════════════════════════════════════ */
.content {
  position: relative;
  z-index: 2;
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  padding: 3.5mm 8mm 0mm;
}

/* ═══════════════════════════════════════════════════════════════
   INVOCATIONS — left and right religious text
   ═══════════════════════════════════════════════════════════════ */
.invocations {
  display: flex;
  justify-content: space-between;
  font-size: 8.5pt;
  padding: 0 5mm;
  color: #c4161c;
  font-weight: 700;
  letter-spacing: 0.02em;
}

/* ═══════════════════════════════════════════════════════════════
   HEADER BANNER: Shiva (Left) | Title & Address (Mid) | Logo (Right)
   ═══════════════════════════════════════════════════════════════ */
.header-banner {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 3mm;
  margin-top: 0mm;
  padding: 0 0mm;
}

.header-logo {
  width: 30mm;
  height: 30mm;
  flex: none;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  overflow: hidden;
}
.header-logo img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.header-logo.shiva-wrap {
  margin-top: -2mm;
}
.header-logo.logo-wrap {
  width: 36mm;
  height: 36mm;
  margin-top: -2mm;
}
.logo-fallback {
  width: 100%;
  height: 100%;
  border: 0.4mm solid #0A3D6B;
  border-radius: 50%;
}

.header-center {
  flex: 1;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-width: 0;
}

.brand-title {
  font-family: 'CertTitle', 'CertHindi', sans-serif;
  color: #1a1a4e;
  font-size: 28pt;
  font-weight: 700;
  line-height: 1.15;
  letter-spacing: 0.02em;
}

.brand-subtitle {
  font-size: 13pt;
  font-weight: 700;
  color: #1a1a4e;
  margin-top: 0mm;
  letter-spacing: 0.02em;
}

.header-reg {
  font-size: 8.5pt;
  font-weight: 600;
  color: #1a1a4e;
  margin-top: 0.8mm;
  line-height: 1.3;
}

.header-address {
  font-size: 9pt;
  font-weight: 700;
  color: #1a1a4e;
  margin-top: 0.3mm;
  line-height: 1.3;
}

.header-phones {
  font-size: 9pt;
  font-weight: 700;
  color: #1a1a4e;
  margin-top: 0.3mm;
  letter-spacing: 0.03em;
}

/* ── Certificate title pill badge ── */
.cert-title {
  display: inline-block;
  background: linear-gradient(180deg, #2b3a7a 0%, #1a1a4e 100%);
  color: #fff;
  font-weight: 700;
  font-size: 12pt;
  padding: 1.5mm 14mm;
  border-radius: 5mm;
  letter-spacing: 0.06em;
  margin-top: 1.8mm;
  box-shadow: 0 0.8mm 2mm rgba(26,26,78,0.25);
}

/* ═══════════════════════════════════════════════════════════════
   HEAD META — membership no · date
   ═══════════════════════════════════════════════════════════════ */
.head-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 3mm;
  margin-bottom: 1mm;
  font-size: 10pt;
  font-weight: 700;
  color: #1a1a4e;
  padding: 0 2mm;
}
.head-meta .side { flex: 1; }
.head-meta .side.right { text-align: right; }
.head-meta .val {
  border-bottom: 0.4mm solid #333;
  padding: 0 4mm;
  min-width: 40mm;
  display: inline-block;
  text-align: center;
  color: #1a1a4e;
}

/* ═══════════════════════════════════════════════════════════════
   BODY — two-column fields on left + photo on right
   ═══════════════════════════════════════════════════════════════ */
.body {
  display: flex;
  gap: 5mm;
  margin-top: 2mm;
  flex: 1;
  min-height: 0;
  padding: 0 2mm;
}

.fields-area {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0;
}

/* ── Photo frame ── */
.photo {
  width: 34mm;
  height: 38mm;
  border: 0.8mm solid #1a1a4e;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11pt;
  color: #1a1a4e;
  font-weight: 700;
  flex: none;
  background: rgba(255,255,255,0.85);
  overflow: hidden;
  margin-top: 0mm;
  align-self: flex-start;
}
.photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* ═══════════════════════════════════════════════════════════════
   FIELD ROWS — label: ___value___ layout
   ═══════════════════════════════════════════════════════════════ */
.form-row {
  display: flex;
  gap: 6mm;
  margin-bottom: 3mm;
}
.form-row.single {
  max-width: 60%;
}

.field {
  display: flex;
  align-items: baseline;
  gap: 1.5mm;
  min-width: 0;
  flex: 1;
}
.field.grow2 { flex: 2; }
.field.grow3 { flex: 3; }
.field.grow4 { flex: 4; }
.field.grow5 { flex: 5; }

.field .lbl {
  font-size: 10.5pt;
  white-space: nowrap;
  font-weight: 700;
  color: #1a1a4e;
}
.field .val {
  flex: 1;
  min-width: 0;
  border-bottom: 0.4mm solid #555;
  color: #1a1a4e;
  font-weight: 600;
  font-size: 10pt;
  padding: 0 2mm;
  min-height: 5.5mm;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  line-height: 1.6;
}

/* The top section: fields + photo side by side */
.fields-with-photo {
  display: flex;
  gap: 5mm;
}
.fields-left {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0;
}

/* ═══════════════════════════════════════════════════════════════
   SIGNATURE AREA — अध्यक्ष at bottom right
   ═══════════════════════════════════════════════════════════════ */
.signature-area {
  display: flex;
  justify-content: flex-end;
  align-items: flex-end;
  padding: 0 4mm;
  margin-top: auto;
  margin-bottom: 3mm;
}
.sign-block {
  text-align: center;
  font-size: 11pt;
  font-weight: 700;
  color: #1a1a4e;
  display: flex;
  align-items: baseline;
  gap: 2mm;
}
.sign-block .sign-line {
  width: 40mm;
  border-bottom: 0.4mm solid #333;
  display: inline-block;
}
.sign-block img {
  height: 10mm;
  display: block;
  margin: 0 auto 1mm;
}

/* ═══════════════════════════════════════════════════════════════
   FOOTER — golden slogan bar
   ═══════════════════════════════════════════════════════════════ */
.slogan-bar {
  background: linear-gradient(180deg, #f5e6b8 0%, #e8d090 50%, #d4af37 100%);
  color: #1a1a4e;
  text-align: center;
  font-size: 16pt;
  font-weight: 700;
  padding: 3mm 12mm;
  letter-spacing: 0.04em;
  margin-top: auto;
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

    <!-- Golden inner border -->
    <div class="inner-border"></div>

    <!-- Corner decorations -->
    <svg class="corner-decor tl" viewBox="0 0 80 80" aria-hidden="true">
      <path d="M5,5 L5,35 M5,5 L35,5" stroke="#0077c0" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path d="M5,5 C5,5 15,5 15,15 C15,25 5,25 5,15" stroke="#0077c0" stroke-width="1.5" fill="none"/>
      <circle cx="8" cy="8" r="2.5" fill="#0077c0"/>
      <path d="M10,5 Q20,3 25,8 Q20,13 10,10 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
      <path d="M5,10 Q3,20 8,25 Q13,20 10,10 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
    </svg>
    <svg class="corner-decor tr" viewBox="0 0 80 80" aria-hidden="true">
      <path d="M75,5 L75,35 M75,5 L45,5" stroke="#0077c0" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path d="M75,5 C75,5 65,5 65,15 C65,25 75,25 75,15" stroke="#0077c0" stroke-width="1.5" fill="none"/>
      <circle cx="72" cy="8" r="2.5" fill="#0077c0"/>
      <path d="M70,5 Q60,3 55,8 Q60,13 70,10 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
      <path d="M75,10 Q77,20 72,25 Q67,20 70,10 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
    </svg>
    <svg class="corner-decor bl" viewBox="0 0 80 80" aria-hidden="true">
      <path d="M5,75 L5,45 M5,75 L35,75" stroke="#0077c0" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path d="M5,75 C5,75 15,75 15,65 C15,55 5,55 5,65" stroke="#0077c0" stroke-width="1.5" fill="none"/>
      <circle cx="8" cy="72" r="2.5" fill="#0077c0"/>
      <path d="M10,75 Q20,77 25,72 Q20,67 10,70 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
      <path d="M5,70 Q3,60 8,55 Q13,60 10,70 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
    </svg>
    <svg class="corner-decor br" viewBox="0 0 80 80" aria-hidden="true">
      <path d="M75,75 L75,45 M75,75 L45,75" stroke="#0077c0" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path d="M75,75 C75,75 65,75 65,65 C65,55 75,55 75,65" stroke="#0077c0" stroke-width="1.5" fill="none"/>
      <circle cx="72" cy="72" r="2.5" fill="#0077c0"/>
      <path d="M70,75 Q60,77 55,72 Q60,67 70,70 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
      <path d="M75,70 Q77,60 72,55 Q67,60 70,70 Z" fill="rgba(0,119,192,0.2)" stroke="#0077c0" stroke-width="0.8"/>
    </svg>

    <!-- Main content -->
    <div class="content">

      <!-- Invocations — left and right -->
      <div class="invocations">
        <span>${_esc(TrustInfo.invocations.first)}</span>
        <span>${_esc(TrustInfo.invocations.last)}</span>
      </div>

      <!-- Header Banner: Shiva (Left) | Title & Address (Mid) | Logo (Right) -->
      <div class="header-banner">
        <div class="header-logo shiva-wrap">$shivaMark</div>
        <div class="header-center">
          <div class="brand-title">${_esc(TrustInfo.nameHindi)}</div>
          <div class="brand-subtitle">${_esc(TrustInfo.place)} - गुजरात</div>
          <div class="header-reg">
            ${_esc(_Hi.established)}: ${_esc(TrustInfo.establishedOn)}
            &nbsp; | &nbsp;
            ${_esc(_Hi.registration)}: &nbsp;${_esc(TrustInfo.registrationNo)}
          </div>
          <div class="header-address">${_esc(TrustInfo.headOfficeAddress)}</div>
          <div class="header-phones">Mobile: ${_esc(phones)}</div>
          <div class="cert-title">${_esc(_Hi.certificate)}</div>
        </div>
        <div class="header-logo logo-wrap">$logoMark</div>
      </div>

      <!-- Membership No · Date -->
      <div class="head-meta">
        <div class="side">
          ${_esc(_Hi.membershipNo)}:
          <span class="val">${_esc(d.regNo)}</span>
        </div>
        <div class="side right">
          ${_esc(_Hi.date)}:
          <span class="val">${_esc(_day(d.issuedOn))}</span>
        </div>
      </div>

      <!-- Body: fields + photo -->
      <div class="body">
        <div class="fields-area">
          <!-- Top section: two-column fields with photo on right -->
          <div class="fields-with-photo">
            <div class="fields-left">
              <!-- Row 1: नाम / गोत्र -->
              <div class="form-row">
                <div class="field grow3">
                  <span class="lbl">${_esc(_Hi.name)}:</span>
                  <span class="val">${_esc(d.fullName)}</span>
                </div>
                <div class="field grow2">
                  <span class="lbl">${_esc(_Hi.gotra)}:</span>
                  <span class="val">${_esc(d.gotra)}</span>
                </div>
              </div>

              <!-- Row 2: जाति / जन्म तारीख -->
              <div class="form-row">
                <div class="field grow3">
                  <span class="lbl">${_esc(_Hi.jati)}:</span>
                  <span class="val">${_esc(d.jati)}</span>
                </div>
                <div class="field grow2">
                  <span class="lbl">${_esc(_Hi.dob)} :</span>
                  <span class="val">${_esc(_day(d.dob))}</span>
                </div>
              </div>

              <!-- Row 3: मोबाइल नं. / गाँव-सिटी -->
              <div class="form-row">
                <div class="field grow3">
                  <span class="lbl">${_esc(_Hi.phone)}:</span>
                  <span class="val">${_esc(d.phone)}</span>
                </div>
                <div class="field grow2">
                  <span class="lbl">${_esc(_Hi.village)}:</span>
                  <span class="val">${_esc(d.village)}</span>
                </div>
              </div>

              <!-- Row 4: जिला / राज्य -->
              <div class="form-row">
                <div class="field grow3">
                  <span class="lbl">${_esc(_Hi.district)}:</span>
                  <span class="val">${_esc(d.district)}</span>
                </div>
                <div class="field grow2">
                  <span class="lbl">${_esc(_Hi.state)}:</span>
                  <span class="val">${_esc(d.state)}</span>
                </div>
              </div>
            </div>

            <!-- Photo box — positioned to right of first 4 rows -->
            <div class="photo">$memberPhoto</div>
          </div>

          <!-- Remaining rows span full width -->
          <!-- Row 5: पता / वारिसदार -->
          <div class="form-row">
            <div class="field grow3">
              <span class="lbl">${_esc(_Hi.address)}:</span>
              <span class="val">${_esc(d.address)}</span>
            </div>
            <div class="field grow3">
              <span class="lbl">${_esc(_Hi.waris)}:</span>
              <span class="val">${_esc(d.warisName)}</span>
            </div>
          </div>

          <!-- Row 6: सम्बन्ध / प्रत्येक सहयोग -->
          <div class="form-row">
            <div class="field grow3">
              <span class="lbl">${_esc(_Hi.relation)} :</span>
              <span class="val">${_esc(d.warisRelation)}</span>
            </div>
            <div class="field grow3">
              <span class="lbl">${_esc(_Hi.perContribution)}:</span>
              <span class="val">${_esc(amount)}</span>
            </div>
          </div>

          <!-- Row 7: कार्यकर्ता (single, half width) -->
          <div class="form-row single">
            <div class="field">
              <span class="lbl">${_esc(_Hi.karyakarta)}:</span>
              <span class="val">${_esc(d.agentName)}</span>
            </div>
          </div>

          <!-- Row 8: नोंध (single, half width) -->
          <div class="form-row single">
            <div class="field">
              <span class="lbl">${_esc(_Hi.note)}:</span>
              <span class="val">${_esc(d.payoutNote)}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Signature: अध्यक्ष at bottom right -->
      <div class="signature-area">
        <div class="sign-block">
          <span>${_esc(_Hi.president)}:</span>
          $signMark
        </div>
      </div>

    </div>

    <!-- Footer Slogan Bar — golden -->
    <div class="slogan-bar">${_esc(TrustInfo.slogan)}</div>
  </div>
</div>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>''';
}
