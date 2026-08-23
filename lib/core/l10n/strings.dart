/// Centralised UI copy. The panel is Hindi-first with English support labels,
/// mirroring the reference screens. Swap this class for `intl` ARB files when
/// a second locale is needed.
class S {
  const S._();

  // Brand
  static const appName = 'SamratCT';
  static const appSubtitle = 'Admin Panel';
  static const trustName = 'सम्राट चैरिटेबल ट्रस्ट';

  // Navigation
  static const mainMenu = 'MAIN MENU';
  static const system = 'SYSTEM';
  static const dashboard = 'Dashboard';
  static const dashboardSub = 'Overview & analytics';
  static const members = 'Members';
  static const membersSub = 'Manage members';
  static const agents = 'Agents';
  static const agentsSub = 'Agent management';
  static const yojna = 'Yojna';
  static const yojnaSub = 'Schemes & programs';
  static const closingPayments = 'Closing Payments';
  static const closingPaymentsSub = 'Claim settlements';
  static const payments = 'Payments';
  static const paymentsSub = 'Payment history';

  // Top bar
  static const home = 'Home';
  static const addPayment = 'Add Payment';
  static const addAgent = 'Add Agent';
  static const addMemberHi = 'नया सदस्य जोड़ें';
  static const requests = 'Requests';
  static const online = 'Online';
  static const logout = 'Logout';
  static const toggleTheme = 'Toggle theme';
  static const selectYojna = 'योजना चुनें';

  // Dashboard
  static const totalMembers = 'Total Members';
  static const closingMembers = 'Closing Members';
  static const totalAgents = 'Total Agents';
  static const monthCollection = 'This Month';
  static const active = 'Active';
  static const inactive = 'Inactive';
  static const closedMembers = 'Closed Members';
  static const agentsLabel = 'Agents';
  static const collected = 'Collected';
  static const closedCases = 'Closed Cases';
  static const noClosedCases = 'No closed cases found';
  static const payStatus = 'Pay Status';
  static const refresh = 'Refresh';
  static const recentPayments = 'Recent Payments';
  static const membersByYojna = 'Members by Yojna';
  static const topAgents = 'Top Agents';
  static const viewAll = 'View all';

  // Table headers
  static const memberName = 'Member Name';
  static const regNo = 'Reg No';
  static const closingDate = 'Closing Date';
  static const closingGroup = 'Closing Group';
  static const actions = 'Actions';
  static const name = 'Name';
  static const phone = 'Phone';
  static const status = 'Status';
  static const amount = 'Amount';
  static const date = 'Date';
  static const mode = 'Mode';
  static const receiptNo = 'Receipt No';
  static const agent = 'Agent';
  static const area = 'Area';
  static const code = 'Code';
  static const joinedOn = 'Joined';
  static const commission = 'Commission';
  static const membersCount = 'Members';
  static const scheme = 'Yojna';
  static const claimAmount = 'Claim Amount';

  // Actions
  static const add = 'Add';
  static const edit = 'Edit';
  static const view = 'View';
  static const delete = 'Delete';
  static const save = 'Save';
  static const cancel = 'Cancel';
  static const cancelHi = 'रद्द करें';
  static const submitHi = 'जमा करें';
  static const searchHi = 'खोजें';
  static const search = 'Search';
  static const clearFilters = 'Clear filters';
  static const markPaid = 'Mark Paid';
  static const all = 'All';
  static const confirmDelete = 'Delete this record?';
  static const confirmDeleteBody =
      'This action cannot be undone. The record will be removed permanently.';

  // Add member form (mirrors the reference dialog)
  static const addMemberTitle = 'नया सदस्य जोड़ें';
  static const editMemberTitle = 'सदस्य संपादित करें';
  static const selectProgram = 'कार्यक्रम/योजना का चयन करें';
  static const copyFromExisting = 'मौजूदा सदस्य से कॉपी करें';
  static const copyFromExistingHint = 'मौजूदा सदस्य का फ़ोन नंबर दर्ज करें';
  static const personalInfo = 'व्यक्तिगत जानकारी';
  static const contactInfo = 'संपर्क जानकारी';
  static const addressInfo = 'पता जानकारी';
  static const membershipInfo = 'सदस्यता जानकारी';
  static const fldName = 'नाम';
  static const fldNameHint = 'पूरा नाम';
  static const fldFather = 'पिता/पति का नाम';
  static const fldJati = 'जाति (Jati)';
  static const fldGotra = 'गोत्र (Gotra) (वैकल्पिक)';
  static const fldWaris = 'वारिसदार का नाम';
  static const fldWarisRelation = 'वारिस से संबंध';
  static const fldGender = 'Gender/लिंग';
  static const fldPrimaryPhone = 'प्राथमिक फ़ोन';
  static const fldAltPhone = 'वैकल्पिक फ़ोन (Optional)';
  static const fldAadhaar = 'आधार संख्या';
  static const fldVillage = 'गाँव/शहर';
  static const fldTehsil = 'तहसील';
  static const fldDistrict = 'ज़िला';
  static const fldPincode = 'पिन कोड';
  static const fldAgent = 'एजेंट';
  static const fldJoinDate = 'सदस्यता तिथि';

  // Genders
  static const male = 'पुरुष';
  static const female = 'महिला';
  static const other = 'अन्य';

  // Validation
  static const required = 'यह फ़ील्ड आवश्यक है';
  static const invalidPhone = '10 अंकों का वैध फ़ोन नंबर दर्ज करें';
  static const invalidAadhaar = '12 अंकों की आधार संख्या दर्ज करें';
  static const invalidEmail = 'वैध ईमेल दर्ज करें';
  static const invalidAmount = 'वैध राशि दर्ज करें';
  static const noResults = 'कोई परिणाम नहीं मिला';
  static const memberNotFound = 'इस नंबर से कोई सदस्य नहीं मिला';
  static const memberCopied = 'सदस्य की जानकारी कॉपी की गई';

  // Auth
  static const signIn = 'Sign in';
  static const signInSubtitle = 'Admin access only';
  static const emailLabel = 'Email address';
  static const emailHint = 'admin@example.com';
  static const sendOtp = 'Send OTP';
  static const otpLabel = 'One-time password';
  static const otpSentTo = 'We sent a 6-digit code to';
  static const verify = 'Verify & continue';
  static const changeEmail = 'Change email';
  static const resendOtp = 'Resend code';
}
