/// Centralised UI copy: English, with the trust's own Hinglish terms (Yojna,
/// Jati, Gotra, Waris) where staff already use them. Swap this class for
/// `intl` ARB files if a second locale is needed.
class S {
  const S._();

  // Brand
  static const appName = 'Rudransh CT';
  static const trustName = 'Rudransh Charitable Trust';

  /// Used in WhatsApp messages to members, which are in Hindi.
  static const trustNameHindi = 'रुद्रांश चैरिटेबल ट्रस्ट';

  // Navigation
  static const mainMenu = 'Menu';
  static const system = 'Account';
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
  static const approvals = 'Approvals';
  static const approvalsSub = 'Agent submissions';

  // Top bar
  static const home = 'Home';
  static const addPayment = 'Add Payment';
  static const addAgent = 'Add Agent';
  static const addMember = 'Add Member';
  static const requests = 'Requests';
  static const online = 'Online';

  // Notifications and announcements (Phase 14)
  static const notifications = 'Notifications';
  static const noNotifications = 'Nothing new';
  static const noNotificationsHint =
      'Approvals, new closings and moved members show up here.';
  static const markAllRead = 'Mark all read';
  static const announcements = 'Announcements';
  static const announcementsSub = 'Notices for agents and members';
  static const newAnnouncement = 'New announcement';
  static const noAnnouncements = 'No announcements yet';
  static const noAnnouncementsHint =
      'Post a notice and every agent and member will see it.';
  static const forEveryYojna = 'Every Yojna';
  static const announcementTitle = 'Title';
  static const announcementBody = 'Message';
  static const post = 'Post';

  // Member portal (Phase 15)
  static const lookupTitle = 'Check your membership';
  static const lookupSub =
      'Enter your phone number and the last 4 digits of your Aadhaar to see your standing.';
  static const lookupRegNo = 'Registration number';
  static const lookupPhone = 'Phone number';
  static const lookupAadhaar = 'Last 4 digits of Aadhaar';
  static const lookupSubmit = 'Check';
  static const lookupNotFound =
      'No membership matches those details. Check the phone number and Aadhaar digits, or ask the office.';
  static const lookupAgain = 'Check another';
  static const myMembership = 'My membership';
  static const myMembershipSub = 'Your record with the trust';
  static const myDues = 'My dues';
  static const myDuesSub = 'What you owe right now';
  static const myClosingCase = 'Family claim';
  static const nothingOwed = 'You are up to date. Nothing to pay.';
  static const payByUpi = 'Pay by UPI';
  static const upiReference = 'UPI reference (UTR)';
  static const upiReferenceHint = 'From your payment app, after paying';
  static const upiAmount = 'Amount paid';
  static const upiSentForApproval =
      'Sent to the office. It will show as approved once they check it.';
  static const requestCorrection = 'Ask for a correction';
  static const requestCorrectionSub =
      'The office checks every change before it is applied.';
  static const whatToChange = 'What to correct';
  static const newValue = 'Correct value';
  static const myCorrections = 'My corrections';
  static const noCorrections = 'You have not asked for any corrections.';
  static const changeRequests = 'Corrections';
  static const changeRequestsSub = 'Members asking to fix their details';
  static const noChangeRequests = 'No corrections waiting.';

  static const logout = 'Logout';
  static const toggleTheme = 'Toggle theme';
  static const selectYojna = 'Select Yojna';

  // Dashboard
  static const totalMembers = 'Total Members';
  static const closingMembers = 'Closing Members';
  static const totalAgents = 'Total Agents';
  static const monthCollection = 'This Month';
  static const active = 'Active';
  static const inactive = 'Inactive';
  static const closedMembers = 'Members with a closing';
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
  static const show = 'Show';

  // Consent and privacy (§7)
  static const consentTitle = 'The member agrees to the trust keeping these details';
  static const consentBody =
      'Name, phone, address, nominee and Aadhaar are kept to run the Yojna and '
      'settle claims. Tick only after telling the member.';
  static const consentRequired =
      'Tick the consent box before saving a new member.';
  static const exportData = 'Export data';
  static const eraseData = 'Erase data';
  static const delete = 'Delete';
  static const save = 'Save';
  static const cancel = 'Cancel';
    static const submit = 'Save Member';
    static const search = 'Search';
  static const clearFilters = 'Clear filters';
  static const markPaid = 'Mark Paid';
  static const all = 'All';
  static const confirmDelete = 'Delete this record?';
  static const confirmDeleteBody =
      'This action cannot be undone. The record will be removed permanently.';

  // Add member form
  static const addMemberTitle = 'Add Member';
  static const editMemberTitle = 'Edit Member';
  static const selectProgram = 'Yojna';
  static const copyFromExisting = 'Copy details from an existing member';
  static const copyFromExistingHint = 'Existing member\'s phone number';
  static const personalInfo = 'Personal details';
  static const contactInfo = 'Contact details';
  static const addressInfo = 'Address';
  static const membershipInfo = 'Membership';
  static const fldName = 'Full name';
  static const fldNameHint = 'e.g. Ramesh Kumar';
  static const fldFather = 'Father / husband name';
  static const fldJati = 'Jati';
  static const fldGotra = 'Gotra (optional)';
  static const fldWaris = 'Nominee (Waris) name';
  static const fldWarisRelation = 'Relation to nominee';
  static const fldGender = 'Gender';
  static const fldDob = 'Date of birth';
  static const fldPrimaryPhone = 'Phone';
  static const fldAltPhone = 'Alternate phone (optional)';
  static const fldMemberEmail = 'Email (optional)';
  static const fldAadhaar = 'Aadhaar number';
  static const fldVillage = 'Village / city';
  static const fldTehsil = 'Tehsil';
  static const fldDistrict = 'District';
  static const fldState = 'State';
  static const fldPincode = 'PIN code';
  static const fldAgent = 'Agent';
  static const fldJoinDate = 'Joining date';
  static const fldContribution = 'Contribution per closing (₹)';

  // Genders
  static const male = 'Male';
  static const female = 'Female';
  static const other = 'Other';

  // Validation
  static const required = 'This field is required';
  static const invalidPhone = 'Enter a valid 10-digit phone number';
  static const invalidAadhaar = 'Enter the 12-digit Aadhaar number';
  static const invalidEmail = 'Enter a valid email address';
  static const invalidAmount = 'Enter a valid amount';
  static const noResults = 'No results found';
  static const memberNotFound = 'No member found with this phone number';
  static const memberCopied = 'Member details copied';

  // Auth
  static const signIn = 'Sign in';
  static const officeSignIn = 'Office sign in';
  static const officeSignInSub = 'Trust office only';
  static const officeAndAgentsSub = 'Trust office and agents';
  static const agentSignIn = 'Agent sign in';
  static const agentSignInSub = "For the trust's agents";
  static const checkEmail = 'Check your email';
  static const otpHint = '6-digit code';
  static const enterOtp = 'Enter the 6-digit code';
  static const allYojnas = 'All Yojnas';
  static const searchMembers = 'Search members by name, reg no or phone';
  static const emailLabel = 'Email address';
  static const emailHint = 'admin@example.com';
  static const sendOtp = 'Send OTP';
  static const otpLabel = 'One-time password';
  static const otpSentTo = 'We sent a 6-digit code to';
  static const verify = 'Verify & continue';
  static const changeEmail = 'Change email';
  static const resendOtp = 'Resend code';
  static const checkingAccess = 'Checking your access…';
  static const retry = 'Retry';

  // Agent and member screens
  static const agentHomeSub = 'Your work at a glance';
  static const myMembers = 'My Members';
  static const myMembersSub = 'Members you enrolled';
  static const collections = 'Collections';
  static const collectionsSub = 'Receipts you issued';
  static const memberHomeSub = 'Your membership';
  static const myPayments = 'My Payments';
  static const myPaymentsSub = 'Receipts and dues';
  static const comingSoon =
      'This section is being prepared and will be available soon.';

  // App access (invites)
  static const inviteToApp = 'Invite to app';
  static const exportCsv = 'Export CSV';
  static const appAccess = 'App access';
  static const accessNone = 'Not invited';
  static const accessActive = 'Invited';
  static const accessOff = 'Turned off';
  static const inviteNeedsEmail = "Add the agent's email address first.";
  static const inviteSent = 'Invite email sent';
  static const inviteNoEmailTitle = 'Access given, no email sent';
  static String inviteNoEmail(String loginUrl) =>
      'This email address already had a login, so it now opens this '
      'person\'s screens and no invite email was sent. Tell them to open '
      '$loginUrl, enter this email and type the 6-digit code they receive.';
  static const ok = 'OK';

  // Approvals
  static const newMembers = 'New members';
  static const paymentsToApprove = 'Payments to approve';
  static const cancelRequests = 'Cancel requests';
  static const approve = 'Approve';
  static const reject = 'Reject';
  static const decline = 'Decline';
  static const cancelReceipt = 'Cancel receipt';
  static const cancelled = 'Cancelled';
  static const reason = 'Reason';
  static const nothingToApprove = 'Nothing is waiting for approval.';
  static const moveMembers = 'Move members';

  // Agent screens
  static const recordPayment = 'Record Payment';
  static const editContact = 'Edit contact';
  static const requestCancel = 'Request cancel';
  static const waitingApproval = 'Waiting for approval';
  static const approvedThisMonth = 'Approved this month';
  static const cancelRequested = 'Cancel requested';

  // Dues and closing reports (Phase 13)
  static const dues = 'Dues';
  static const duesSub = 'Contributions per closing';
  static const officeDuesSub = 'Who owes, per member';
  static const closing = 'Closing';
  static const forClosing = 'For closing';
  static const notForClosing = 'Not for a closing';
  static const toCollect = 'To collect';
  static const sendReminder = 'Send reminder';
  static const shareReceipt = 'Send receipt';
  static const reportClosing = 'Report closing';
  static const closingReports = 'Closing reports';
  static const eventDate = 'Event date';
  static const proofDocument = 'Proof document';
  static const createClosing = 'Create closing';
  static const noPhone = 'This member has no valid phone number.';
  static const whatsAppFailed = 'Could not open WhatsApp.';

  // Cash handovers and commission (Phase 16)
  static const cashInHand = 'Cash in hand';
  static const cashInHandSub = 'Approved cash you have not handed over yet';
  static const handover = 'Hand over cash';
  static const handovers = 'Cash handovers';
  static const handoversSub = 'Cash agents say they handed to the office';
  static const handoverWaiting = 'Waiting to be confirmed';
  static const declareHandover = 'Declare handover';
  static const confirmHandover = 'Confirm received';
  static const handoverNote = 'Note for the office';
  static const receiptsInHandover = 'Receipts';
  static const noOpenCash = 'No approved cash is waiting to be handed over.';
  static const handoverDeclared = 'Handover declared. The office will confirm it.';
  static const handoverConfirmed = 'Handover confirmed.';
  static const commissionSub = 'Monthly commission per agent';
  static const myCommission = 'My commission';
  static const thisMonthCommission = "This month's commission";
  static const collectedInMonth = 'Collected';
  static const commissionPaid = 'Paid';
  static const commissionUnpaid = 'Not paid yet';
  static const markCommissionPaid = 'Mark paid';
  static const commissionReference = 'Reference';
  static const amountPaid = 'Amount paid';
  static const commissionDiffers =
      'What was paid no longer matches what is owed.';
  static const ownerOnlyCommission = 'Only an owner can mark commission paid.';

  // Membership certificate (docs/MEMBERSHIP_CERTIFICATE_PLAN.md)
  static const printCertificate = 'Print certificate';
  static const certificateNeedsRegNo =
      'This member needs a registration number before a certificate can be printed.';
  static const certificateFailed =
      'Could not open the certificate. Allow pop-ups for this site and try again.';
  static const certificateSheetNote = 'Two certificates fit on one A4 sheet.';
  static const certificateKeep = 'Keep for next';
  static const certificatePrintNow = 'Print now';
  static const certificatePrintOne = 'Print this only';
  static const certificatePrintBoth = 'Print both';
  static const certificateKept =
      'Kept. Print the next member\'s certificate to put both on one sheet.';
}
