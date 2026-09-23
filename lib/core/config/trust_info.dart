/// The trust's own fixed details, printed on the membership certificate
/// (docs/MEMBERSHIP_CERTIFICATE_PLAN.md §4b).
///
/// These live in code rather than the database on purpose: they change once a
/// year at most, and keeping them out of Supabase costs nothing on the free
/// tier. Changing one means editing this file and redeploying.
///
/// The wording follows the trust's own `सदस्यता प्रपत्र`, including its
/// spelling of चेरीटेबल. Values marked TODO are the ones the client has not
/// sent yet; the certificate prints a blank dotted line wherever a value is
/// empty, so it is safe to ship before they arrive.
class TrustInfo {
  const TrustInfo._();

  /// Printed as the big heading, with [place] after a dash.
  static const nameHindi = 'रुद्रांश चेरीटेबल ट्रस्ट';
  static const place = 'लाखणी';
  static const nameEnglish = 'Rudransh Charitable Trust';

  /// The certificate's big heading. It is spelled as the client's approved
  /// certificate design (`final.png`) writes it, which differs from the
  /// सदस्यता प्रपत्र spelling in [nameHindi] that the receipt uses.
  static const certificateName = 'रुद्रांश चैरिटेबल ट्रस्ट';

  /// Follows [place] under the certificate heading: `लाखणी - गुजरात`.
  static const state = 'गुजरात';

  /// Across the top of the certificate: the first at the left shoulder, the
  /// last at the right, as the approved design has them.
  static const invocations = <String>[
    '॥ श्री गणेशाय नमः ॥',
    '॥ श्री कुलदेवी मातायें नमः ॥',
  ];

  // TODO(client): the real establishment date. Placeholder: the day the
  // scheme opened, per the सदस्यता प्रपत्र.
  static const establishedOn = '01-07-2026';

  /// TODO(client): the trust's real registration number.
  ///
  /// This is deliberately a **placeholder with the right shape, not a
  /// plausible number** — the zeros read as "not filled in yet" at a glance.
  /// Certificates are handed to members, and a made-up number that looked real
  /// would be taken for the trust's actual registration. Replace this before
  /// printing anything a member keeps.
  static const registrationNo = 'F/0000/B.K., GJ/0000/B.K.';

  /// Signs the certificate. Spelled as the trust's own सदस्यता प्रपत्र writes
  /// it; the client gave the name as "shailesh luhar".
  static const presidentName = 'शैलेषभाई वी.लुहार';

  /// `॥ ओफिस ॥` on the सदस्यता प्रपत्र.
  static const headOfficeAddress =
      'ठी. दक्ष कॉम्प्लेक्स, लाखणी, तह. लाखणी, जि. वाव-थराद (गुजरात)';

  /// The three numbers the client picked for the footer: Shaileshbhai,
  /// Ganeshbhai and Kalpeshbhai. The other three on the form are deliberately
  /// left off, to keep the footer to one line as the reference sheet has it.
  static const headOfficePhones = <String>[
    '88299 01246',
    '98259 46742',
    '95863 40736',
  ];

  /// The line across the foot of the certificate.
  static const slogan = 'आपका साथ सहयोग वही समाज का कल्याण';

  /// Images served from the app's own assets, declared in `pubspec.yaml`.
  /// Replacing the logo means dropping a new file in `assets/brand/` — the
  /// image is never embedded in code.
  ///
  /// The certificate frame is the reference certificate's own sheet — border,
  /// corner flourishes, dotted ground — with its header wiped, so the trust's
  /// header is drawn over it (lib/features/certificate/certificate_html.dart).
  static const certificateFrameAsset = 'assets/brand/certificate_frame.jpg';
  static const logoAsset = 'assets/brand/rudransh_logo.png';
  static const shivaAsset = 'assets/brand/shiva.png';

  // TODO(client): drop a signature image in `assets/brand/` and name it here.
  static const signatureAsset = '';

  /// Display face for the heading, bundled as an asset (assets/fonts/README).
  static const headingFontAsset = 'assets/fonts/YatraOne-Regular.ttf';

  static bool get hasLogo => logoAsset.isNotEmpty;
  static bool get hasShiva => shivaAsset.isNotEmpty;
  static bool get hasSignature => signatureAsset.isNotEmpty;
}
