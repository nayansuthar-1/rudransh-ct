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

/// Builds the printable membership certificate as one self-contained HTML
/// page: a single A4 landscape sheet, using the certificate template image
/// as the background and overlaying field values at their exact positions.
///
/// [baseUrl] is the app's own base URL, used to reach the bundled assets.
String buildCertificateHtml(CertificateData d, {required String baseUrl}) {
  final bgImage = _assetUrl(baseUrl, TrustInfo.certificateBgAsset);

  final amount =
      d.contributionAmount > 0 ? _money.format(d.contributionAmount) : '';

  final memberPhoto = d.photoUrl.isNotEmpty
      ? '<img src="${_esc(d.photoUrl)}" alt="" '
        'style="width:100%;height:100%;object-fit:cover;">'
      : '';

  // ── All field values positioned as percentage coordinates ──
  // These percentages are measured from the 1654×1167 reference image.
  //
  // Each entry: left%, top%, value, [optional width%]
  // The positions target the blank line area AFTER each printed label.

  return '''<!DOCTYPE html>
<html lang="hi">
<head>
<meta charset="utf-8">
<title>प्रमाण पत्र - ${_esc(d.regNo)}</title>
<style>
@page { size: A4 landscape; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
  width: 100%;
  height: 100%;
  background: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

.page {
  position: relative;
  width: 297mm;
  height: 210mm;
  overflow: hidden;
  margin: 0 auto;
}

.page > img.bg {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: fill;
  z-index: 0;
}

/* Each field value overlaid on the image */
.v {
  position: absolute;
  z-index: 1;
  font-family: 'Noto Sans Devanagari', 'Segoe UI', sans-serif;
  font-size: 10pt;
  font-weight: 600;
  color: #1a1a4e;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  line-height: 1.4;
}

/* Photo overlay */
.photo-box {
  position: absolute;
  z-index: 1;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}
.photo-box img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
</head>
<body>
<div class="page">
  <!-- Certificate template background image -->
  <img class="bg" src="$bgImage" alt="">

  <!-- ═══ FIELD VALUES OVERLAID ON THE IMAGE ═══ -->

  <!-- सदस्यता क्रमांक: value -->
  <div class="v" style="left:16.5%; top:29.5%; width:24%;">
    ${_esc(d.regNo)}
  </div>

  <!-- दिनांक: value -->
  <div class="v" style="left:70.5%; top:29.5%; width:18%;">
    ${_esc(_day(d.issuedOn))}
  </div>

  <!-- नाम: value -->
  <div class="v" style="left:8.5%; top:36.5%; width:26%;">
    ${_esc(d.fullName)}
  </div>

  <!-- गोत्र: value -->
  <div class="v" style="left:42%; top:36.5%; width:19%;">
    ${_esc(d.gotra)}
  </div>

  <!-- जाति: value -->
  <div class="v" style="left:8.5%; top:42.5%; width:26%;">
    ${_esc(d.jati)}
  </div>

  <!-- जन्म तारीख: value -->
  <div class="v" style="left:46%; top:42.5%; width:16%;">
    ${_esc(_day(d.dob))}
  </div>

  <!-- मोबाइल नं.: value -->
  <div class="v" style="left:13%; top:48.5%; width:22%;">
    ${_esc(d.phone)}
  </div>

  <!-- गाँव / सिटी: value -->
  <div class="v" style="left:45.5%; top:48.5%; width:16%;">
    ${_esc(d.village)}
  </div>

  <!-- जिला: value -->
  <div class="v" style="left:8.5%; top:54.5%; width:26%;">
    ${_esc(d.district)}
  </div>

  <!-- राज्य: value -->
  <div class="v" style="left:42%; top:54.5%; width:20%;">
    ${_esc(d.state)}
  </div>

  <!-- पता: value -->
  <div class="v" style="left:7.5%; top:60.5%; width:27%;">
    ${_esc(d.address)}
  </div>

  <!-- वारिसदार: value -->
  <div class="v" style="left:43.5%; top:60.5%; width:20%;">
    ${_esc(d.warisName)}
  </div>

  <!-- सम्बन्ध: value -->
  <div class="v" style="left:11%; top:66.5%; width:24%;">
    ${_esc(d.warisRelation)}
  </div>

  <!-- प्रत्येक सहयोग: value -->
  <div class="v" style="left:49%; top:66.5%; width:16%;">
    ${_esc(amount)}
  </div>

  <!-- कार्यकर्ता: value -->
  <div class="v" style="left:11%; top:72.5%; width:24%;">
    ${_esc(d.agentName)}
  </div>

  <!-- नोंध: value -->
  <div class="v" style="left:7.5%; top:78.5%; width:27%;">
    ${_esc(d.payoutNote)}
  </div>

  <!-- Photo (overlaid on the फोटो box area) -->
  <div class="photo-box" style="left:68%; top:35.5%; width:12.5%; height:18%;">
    $memberPhoto
  </div>

</div>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>''';
}
