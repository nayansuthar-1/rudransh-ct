import 'package:intl/intl.dart';

import '../../core/config/trust_info.dart';
import 'receipt_data.dart';

final _date = DateFormat('dd-MM-yyyy');
final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _assetUrl(String base, String path) {
  final sep = base.isEmpty || base.endsWith('/') ? '' : '/';
  return '$base${sep}assets/$path';
}

/// Builds the printable payment receipt HTML page.
String buildReceiptHtml(ReceiptData d, {required String baseUrl}) {
  final body = _assetUrl(baseUrl, 'assets/fonts/NotoSansDevanagari');
  final display = _assetUrl(baseUrl, TrustInfo.headingFontAsset);
  final logo = TrustInfo.hasLogo ? _assetUrl(baseUrl, TrustInfo.logoAsset) : '';
  final signature = TrustInfo.hasSignature
      ? _assetUrl(baseUrl, TrustInfo.signatureAsset)
      : '';

  final phones = TrustInfo.headOfficePhones.join(', ');
  final logoMark = logo.isEmpty
      ? ''
      : '<img class="logo" src="$logo" alt="Logo">';
  final signMark = signature.isEmpty
      ? '<div class="sign-line"></div>'
      : '<img class="sign-img" src="$signature" alt="Sign">';

  final cancelledBanner = d.isCancelled
      ? '<div class="cancelled-watermark">रद्द / CANCELLED</div>'
      : '';

  return '''<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<title>रसीद - ${_esc(d.receiptNo)}</title>
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
@page { size: A5 landscape; margin: 4mm; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
  font-family: 'CertHindi', 'Noto Sans Devanagari', sans-serif;
  color: #0A3D6B;
  background: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.sheet {
  width: 202mm;
  height: 140mm;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
}

.receipt-frame {
  position: relative;
  flex: 1;
  border: 1.8mm solid #0A3D6B;
  border-radius: 2mm;
  background: #FAFDFE;
  padding: 4mm 6mm;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  overflow: hidden;
}

.inner-border {
  position: absolute;
  inset: 1.5mm;
  border: 0.4mm solid #0A3D6B;
  border-radius: 1mm;
  pointer-events: none;
}

.cancelled-watermark {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%) rotate(-25deg);
  font-size: 32pt;
  font-weight: 800;
  color: rgba(200, 30, 30, 0.25);
  border: 2mm dashed rgba(200, 30, 30, 0.35);
  padding: 4mm 16mm;
  border-radius: 4mm;
  pointer-events: none;
  z-index: 10;
  white-space: nowrap;
}

/* ── Header ── */
.hdr {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 3mm;
  position: relative;
  z-index: 2;
  border-bottom: 0.4mm solid #0A3D6B;
  padding-bottom: 2mm;
}
.hdr .logo {
  width: 20mm;
  height: 20mm;
  object-fit: contain;
}
.hdr .mid {
  flex: 1;
  text-align: center;
}
.hdr .invocation {
  font-size: 8pt;
  font-weight: 700;
  color: #B5121B;
}
.hdr .title {
  font-family: 'CertTitle', 'CertHindi', sans-serif;
  color: #B5121B;
  font-size: 19pt;
  font-weight: 700;
  line-height: 1.1;
  margin: 0.5mm 0;
}
.hdr .subtitle {
  font-size: 8pt;
  color: #0A3D6B;
  font-weight: 600;
}
.hdr .phones {
  font-size: 8pt;
  color: #0A3D6B;
  font-weight: 700;
}

/* ── Badge ── */
.badge-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 2mm;
  position: relative;
  z-index: 2;
}
.receipt-badge {
  background: linear-gradient(180deg, #0F4C81 0%, #0A3D6B 100%);
  color: #fff;
  font-size: 10.5pt;
  font-weight: 700;
  padding: 1mm 6mm;
  border-radius: 1mm;
  letter-spacing: 0.04em;
}
.meta-box {
  display: flex;
  gap: 6mm;
  font-size: 9pt;
  font-weight: 700;
}
.meta-box .val {
  color: #B5121B;
  font-weight: 700;
}

/* ── Grid of Details ── */
.details-table {
  width: 100%;
  margin-top: 2.5mm;
  border-collapse: collapse;
  font-size: 9pt;
  position: relative;
  z-index: 2;
}
.details-table td {
  padding: 1.3mm 2mm;
  vertical-align: baseline;
  border-bottom: 0.25mm dotted #A2C4DE;
}
.details-table .lbl {
  font-weight: 700;
  color: #0A3D6B;
  width: 28%;
  white-space: nowrap;
}
.details-table .val {
  font-weight: 700;
  color: #082847;
  width: 72%;
}
.details-table .val.highlight {
  color: #B5121B;
}

/* ── Amount highlight box ── */
.amount-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: rgba(235, 244, 250, 0.9);
  border: 0.35mm solid #0A3D6B;
  border-radius: 1mm;
  padding: 2mm 4mm;
  margin-top: 2mm;
  position: relative;
  z-index: 2;
}
.amount-box {
  display: flex;
  align-items: baseline;
  gap: 2mm;
}
.amount-box .lbl {
  font-size: 9.5pt;
  font-weight: 700;
  color: #0A3D6B;
}
.amount-box .num {
  font-size: 13pt;
  font-weight: 800;
  color: #B5121B;
}
.amount-words {
  font-size: 8.5pt;
  font-weight: 700;
  color: #0A3D6B;
}

/* ── Signatures ── */
.tail-row {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  margin-top: 3mm;
  position: relative;
  z-index: 2;
}
.sign-block {
  text-align: center;
  width: 45mm;
}
.sign-line {
  border-bottom: 0.3mm solid #0A3D6B;
  height: 6mm;
  margin-bottom: 1mm;
}
.sign-img {
  height: 7mm;
  object-fit: contain;
  margin-bottom: 0.5mm;
}
.sign-lbl {
  font-size: 8pt;
  font-weight: 700;
  color: #0A3D6B;
}
.sign-sub {
  font-size: 7.5pt;
  color: #4A7FAF;
}

/* ── Footer ── */
.footer-text {
  text-align: center;
  font-size: 7pt;
  color: #4A7FAF;
  margin-top: 1.5mm;
  position: relative;
  z-index: 2;
}
</style>
</head>
<body>
<div class="sheet">
  <div class="receipt-frame">
    <div class="inner-border"></div>
    $cancelledBanner

    <!-- Header -->
    <div class="hdr">
      $logoMark
      <div class="mid">
        <div class="invocation">॥ श्री गणेशाय नमः ॥</div>
        <div class="title">${_esc(TrustInfo.nameHindi)} – ${_esc(TrustInfo.place)}</div>
        <div class="subtitle">${_esc(TrustInfo.headOfficeAddress)}</div>
        <div class="phones">संस्था रजीस्टर नं.: ${_esc(TrustInfo.registrationNo)} | Mo. ${_esc(phones)}</div>
      </div>
      $logoMark
    </div>

    <!-- Badge & Meta -->
    <div class="badge-row">
      <div class="receipt-badge">सहयोग रसीद &bull; PAYMENT RECEIPT</div>
      <div class="meta-box">
        <div>रसीद नं.: <span class="val">${_esc(d.receiptNo)}</span></div>
        <div>दिनांक: <span class="val">${_esc(_date.format(d.date))}</span></div>
      </div>
    </div>

    <!-- Details Grid -->
    <table class="details-table">
      <tr>
        <td class="lbl">सदस्य का नाम (Member Name):</td>
        <td class="val highlight">${_esc(d.memberName)}</td>
        <td class="lbl">सदस्यता क्रमांक (Reg No):</td>
        <td class="val highlight">${_esc(d.regNo.isNotEmpty ? d.regNo : '—')}</td>
      </tr>
      <tr>
        <td class="lbl">पिता / पति का नाम:</td>
        <td class="val">${_esc(d.fatherOrHusbandName.isNotEmpty ? d.fatherOrHusbandName : '—')}</td>
        <td class="lbl">मोबाईल नंबर (Phone):</td>
        <td class="val">${_esc(d.phone.isNotEmpty ? d.phone : '—')}</td>
      </tr>
      <tr>
        <td class="lbl">योजना (Scheme Name):</td>
        <td class="val">${_esc(d.yojnaName.isNotEmpty ? d.yojnaName : '—')}</td>
        <td class="lbl">सहयोग प्रकार (Type):</td>
        <td class="val">${_esc(d.paymentKind)}</td>
      </tr>
      <tr>
        <td class="lbl">भुगतान माध्यम (Mode):</td>
        <td class="val">${_esc(d.paymentMode)}</td>
        <td class="lbl">यूटीआर / संदर्भ (Ref/UTR):</td>
        <td class="val">${_esc(d.reference.isNotEmpty ? d.reference : '—')}</td>
      </tr>
      ${d.agentName.isNotEmpty ? '<tr><td class="lbl">प्राप्तकर्ता (Agent):</td><td class="val" colspan="3">${_esc(d.agentName)}</td></tr>' : ''}
    </table>

    <!-- Amount Row -->
    <div class="amount-row">
      <div class="amount-box">
        <span class="lbl">प्राप्त राशि (Amount):</span>
        <span class="num">${_money.format(d.amount)}</span>
      </div>
      <div class="amount-words">
        <span>शब्दों में: <b>${_esc(d.amountInWordsHindi)}</b></span>
      </div>
    </div>

    <!-- Signatures -->
    <div class="tail-row">
      <div class="sign-block">
        <div class="sign-line"></div>
        <div class="sign-lbl">जमाकर्ता हस्ताक्षर</div>
        <div class="sign-sub">(Member Signature)</div>
      </div>
      <div class="sign-block">
        <div class="sign-line"></div>
        <div class="sign-lbl">प्राप्तकर्ता प्रतिनिधि</div>
        <div class="sign-sub">${_esc(d.agentName.isNotEmpty ? d.agentName : 'कार्यालय')}</div>
      </div>
      <div class="sign-block">
        $signMark
        <div class="sign-lbl">अधिकृत हस्ताक्षर</div>
        <div class="sign-sub">(Authorized Signatory)</div>
      </div>
    </div>

    <!-- Footer Note -->
    <div class="footer-text">
      * यह रसीद कंप्यूटर जनरेटेड है। आपका सहयोग समाज कल्याण में समर्पित है। धन्यवाद।
    </div>
  </div>
</div>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>''';
}
