import '../../data/models/models.dart';
import '../router/routes.dart';
import '../utils/formatters.dart';
import 'strings.dart';

/// The language a member reads their screens in.
enum MemberLang { hi, en }

/// Every word on the member screens and the public lookup, in Hindi and
/// English. Admin and agent screens stay English-only ([S]); the member side
/// is the exception the client asked for, Hindi by default.
class MemberText {
  const MemberText(this.lang);

  final MemberLang lang;

  bool get isHindi => lang == MemberLang.hi;

  String _t(String hi, String en) => isHindi ? hi : en;

  // ---- Language switch --------------------------------------------------
  /// The switch shows the language it switches *to*.
  String get switchLabel => _t('English', 'हिंदी');
  String get switchTooltip => _t('Switch to English', 'हिंदी में देखें');

  // ---- Shell and home ---------------------------------------------------
  String get trustName => _t(S.trustNameHindi, S.trustName);
  String get member => _t('सदस्य', 'Member');
  String namaste(String name) => _t('नमस्ते, $name', 'Namaste, $name');
  String get logout => _t('लॉग आउट', S.logout);
  String get toggleTheme => _t('थीम बदलें', S.toggleTheme);

  String get navHome => _t('होम', S.home);
  String get navHomeSub => _t('आपकी सदस्यता', S.memberHomeSub);
  String get navDues => _t('मेरा बकाया', S.myDues);
  String get navDuesSub => _t('अभी क्या जमा करना है', S.myDuesSub);
  String get navPayments => _t('मेरे भुगतान', S.myPayments);
  String get navPaymentsSub => _t('रसीदें और बकाया', S.myPaymentsSub);
  String get navAnnouncements => _t('सूचनाएँ', S.announcements);
  String get navAnnouncementsSub =>
      _t('ट्रस्ट की ओर से सूचनाएँ', 'Notices from the trust');
  String get noAnnouncements => _t('अभी कोई सूचना नहीं है', S.noAnnouncements);

  /// A member navigation item in this language: the same destination, with
  /// its label and sublabel translated.
  NavItem nav(NavItem item) {
    final (label, sub) = switch (item.path) {
      AppRoutes.memberHome => (navHome, navHomeSub),
      AppRoutes.memberDues => (navDues, navDuesSub),
      AppRoutes.memberPayments => (navPayments, navPaymentsSub),
      AppRoutes.memberAnnouncements => (navAnnouncements, navAnnouncementsSub),
      _ => (item.label, item.sublabel),
    };
    return NavItem(
      path: item.path,
      label: label,
      sublabel: sub,
      icon: item.icon,
      activeIcon: item.activeIcon,
    );
  }

  // ---- Lookup -----------------------------------------------------------
  String get lookupTitle => _t('अपनी सदस्यता जाँचें', S.lookupTitle);
  String get lookupSub => _t(
        'अपनी स्थिति देखने के लिए अपना मोबाइल नंबर और आधार के आखिरी 4 अंक डालें।',
        S.lookupSub,
      );
  String get phone => _t('मोबाइल नंबर', S.lookupPhone);
  String get aadhaar4 => _t('आधार के आखिरी 4 अंक', S.lookupAadhaar);
  String get enterPhone =>
      _t('10 अंकों का मोबाइल नंबर डालें।', 'Enter the 10-digit phone number.');
  String get enterAadhaar4 => _t(
        'आधार के आखिरी 4 अंक डालें।',
        'Enter the last 4 digits of your Aadhaar.',
      );
  String get notFound => _t(
        'इन जानकारियों से कोई सदस्यता नहीं मिली। मोबाइल नंबर और आधार अंक '
            'जाँचें, या कार्यालय से पूछें।',
        S.lookupNotFound,
      );
  String get lookupOff => _t(
        'यह सुविधा अभी चालू नहीं है। कृपया कार्यालय से संपर्क करें।',
        'This check is not switched on yet. Please contact the office.',
      );
  String get check => _t('जाँचें', S.lookupSubmit);
  String get checkAnother => _t('दूसरी जाँच करें', S.lookupAgain);
  String get staffSignIn =>
      _t('स्टाफ और एजेंट: साइन इन', 'Staff and agents: sign in');

  /// The lookup's server messages are English; the ones a member can meet
  /// are given in Hindi too. Anything else is shown as it came.
  String serverMessage(String message) {
    if (!isHindi) return message;
    if (message.startsWith('Too many wrong tries')) {
      return 'बहुत बार गलत कोशिश हुई। 15 मिनट बाद फिर कोशिश करें।';
    }
    if (message.startsWith('Please complete the check')) {
      return 'कृपया ऊपर की जाँच पूरी करें और फिर कोशिश करें।';
    }
    if (message.startsWith('Lookup is not available')) {
      return 'यह सुविधा अभी उपलब्ध नहीं है। थोड़ी देर बाद कोशिश करें।';
    }
    if (message.startsWith('Enter the 10-digit')) return enterPhone;
    if (message.startsWith('Enter the last 4')) return enterAadhaar4;
    return message;
  }

  // ---- Membership details ----------------------------------------------
  String get myMembership => _t('मेरी सदस्यता', S.myMembership);
  String get regNo => _t('सदस्यता क्रमांक', S.lookupRegNo);
  String get yojna => _t('योजना', S.yojna);
  String get memberSince => _t('सदस्य कब से', 'Member since');
  String get contribution => _t('सहयोग राशि', 'Contribution');
  String get phoneShort => _t('मोबाइल', 'Phone');
  String get address => _t('पता', 'Address');
  String get nominee => _t('वारिसदार', 'Nominee');
  String get yourAgent => _t('आपके एजेंट', 'Your agent');
  String get nothingOwed => _t('आपका कोई बकाया नहीं है।', S.nothingOwed);
  String youOwe(double amount, int closings) => _t(
        'आपका ${Fmt.money(amount)} बकाया है ($closings क्लोजिंग)। '
            'अपने एजेंट या कार्यालय में जमा करें।',
        'You owe ${Fmt.money(amount)} for $closings closing(s). '
            'Pay your agent or the office.',
      );
  String get printCertificate =>
      _t('प्रमाण पत्र प्रिंट करें', S.printCertificate);
  String get certificateFailed => _t(
        'प्रमाण पत्र नहीं खुल सका। इस साइट के लिए पॉप-अप की अनुमति दें और '
            'फिर से कोशिश करें।',
        S.certificateFailed,
      );

  // ---- Receipts ---------------------------------------------------------
  String get receipts => _t('रसीदें', 'Receipts');
  String get noApprovedReceipts =>
      _t('अभी कोई स्वीकृत रसीद नहीं है।', 'No approved receipts yet.');
  String get noReceipts => _t('अभी कोई रसीद नहीं है।', 'No receipts yet.');
  String get printReceipt => _t('रसीद प्रिंट करें', 'Print receipt');
  String get totalContributed => _t('कुल जमा राशि', 'Total Contributed');
  String get approvedReceipts => _t('स्वीकृत रसीदें', 'Approved Receipts');
  String issued(int n) => _t('$n रसीदें', '$n issued');

  // ---- Dues and UPI -----------------------------------------------------
  String closing(String group) => _t('क्लोजिंग $group', 'Closing $group');
  String get closingDate => _t('क्लोजिंग तिथि', 'Closing date');
  String get amount => _t('राशि', 'Amount');
  String get waitingForApproval =>
      _t('स्वीकृति के लिए भेजा गया', 'Waiting for approval');
  String get sentForApproval => _t(
        'कार्यालय को भेज दिया गया है। जाँच के बाद यह स्वीकृत दिखेगा।',
        S.upiSentForApproval,
      );
  String get payByUpi => _t('UPI से भुगतान करें', S.payByUpi);
  String get payOffline => _t(
        'अपने एजेंट या कार्यालय में जमा करें। ऑनलाइन भुगतान अभी चालू नहीं है।',
        'Pay your agent or the office. Online payment is not switched on yet.',
      );
  String get payTo => _t('इन्हें भुगतान करें', 'Pay to');
  String get payFirst => _t(
        'पहले अपने UPI ऐप से भुगतान करें, फिर नीचे रेफरेंस नंबर डालें।',
        'Pay in your UPI app first, then enter the reference below.',
      );
  String get amountPaid => _t('भुगतान की गई राशि', S.upiAmount);
  String get enterAmount =>
      _t('भुगतान की गई राशि डालें।', 'Enter the amount you paid.');
  String get upiReference => _t('UPI रेफरेंस (UTR)', S.upiReference);
  String get upiReferenceHint =>
      _t('भुगतान के बाद अपने UPI ऐप से', S.upiReferenceHint);
  String get enterUtr => _t(
        'अपने भुगतान ऐप से UPI रेफरेंस (UTR) डालें।',
        'Enter the UPI reference (UTR) from your payment app.',
      );
  String get cancel => _t('रद्द करें', S.cancel);
  String get send => _t('भेजें', S.save);

  // ---- Corrections ------------------------------------------------------
  String get myCorrections => _t('मेरे सुधार अनुरोध', S.myCorrections);
  String get noCorrections =>
      _t('आपने अभी तक कोई सुधार नहीं माँगा है।', S.noCorrections);
  String get requestCorrection =>
      _t('सुधार का अनुरोध करें', S.requestCorrection);
  String get requestCorrectionSub => _t(
        'हर बदलाव लागू होने से पहले कार्यालय उसे जाँचता है।',
        S.requestCorrectionSub,
      );
  String get whatToChange => _t('क्या सुधारना है', S.whatToChange);
  String get newValue => _t('सही जानकारी', S.newValue);
  String get enterNewValue => _t('सही जानकारी डालें।', 'Enter the new value.');

  // ---- Labels for values ------------------------------------------------
  String memberStatus(MemberStatus s) => isHindi
      ? switch (s) {
          MemberStatus.active => 'सक्रिय',
          MemberStatus.inactive => 'निष्क्रिय',
          MemberStatus.closed => 'बंद',
          MemberStatus.pending => 'लंबित',
        }
      : s.label;

  /// A receipt's status; a cancelled one says so whatever its status.
  String paymentStatus(Payment p) => p.isCancelled
      ? _t('रद्द', 'Cancelled')
      : isHindi
          ? switch (p.status) {
              PaymentStatus.paid => 'स्वीकृत',
              PaymentStatus.pending => 'लंबित',
              PaymentStatus.failed => 'असफल',
            }
          : p.status.label;

  String paymentKind(PaymentKind k) => isHindi
      ? switch (k) {
          PaymentKind.registration => 'पंजीकरण शुल्क',
          PaymentKind.contribution => 'सहयोग राशि',
          PaymentKind.closingPayout => 'क्लेम भुगतान',
        }
      : k.label;

  String dueState(DueState s) => isHindi
      ? switch (s) {
          DueState.due => 'बकाया',
          DueState.pending => 'स्वीकृति बाकी',
          DueState.paid => 'जमा',
        }
      : s.label;

  String requestStatus(RequestStatus s) => isHindi
      ? switch (s) {
          RequestStatus.pending => 'कार्यालय में लंबित',
          RequestStatus.approved => 'स्वीकृत',
          RequestStatus.rejected => 'अस्वीकृत',
        }
      : s.label;

  String changeField(ChangeField f) => isHindi
      ? switch (f) {
          ChangeField.primaryPhone => 'मोबाइल नंबर',
          ChangeField.altPhone => 'दूसरा मोबाइल नंबर',
          ChangeField.village => 'गाँव',
          ChangeField.tehsil => 'तहसील',
          ChangeField.district => 'जिला',
          ChangeField.pincode => 'पिन कोड',
          ChangeField.warisName => 'वारिसदार का नाम',
          ChangeField.warisRelation => 'वारिसदार से संबंध',
          ChangeField.name => 'नाम',
          ChangeField.fatherOrHusbandName => 'पिता / पति का नाम',
        }
      : f.label;
}
