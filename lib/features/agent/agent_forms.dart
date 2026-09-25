import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/whatsapp.dart';
import '../../data/models/models.dart';
import '../../data/repositories/upload_repository.dart';
import '../../state/agent_providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../receipt/receipt_action.dart';
import '../../widgets/forms/member_photo_picker.dart';

// ---------------------------------------------------------------------------
// Add member
// ---------------------------------------------------------------------------

Future<void> showAgentMemberForm(BuildContext context) => AppDialog.show<void>(
      context: context,
      builder: (_) => const _AgentMemberForm(),
    );

/// New member for admin approval. Aadhaar is optional here; the office can
/// add it later.
class _AgentMemberForm extends ConsumerStatefulWidget {
  const _AgentMemberForm();

  @override
  ConsumerState<_AgentMemberForm> createState() => _AgentMemberFormState();
}

class _AgentMemberFormState extends ConsumerState<_AgentMemberForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _father = TextEditingController();
  final _jati = TextEditingController();
  final _gotra = TextEditingController();
  final _waris = TextEditingController();
  final _warisRelation = TextEditingController();
  final _phone = TextEditingController();
  final _altPhone = TextEditingController();
  final _aadhaar = TextEditingController();
  final _village = TextEditingController();
  final _tehsil = TextEditingController();
  final _district = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _contribution = TextEditingController();

  String? _yojnaId;
  Gender _gender = Gender.male;
  DateTime _joinDate = DateTime.now();
  /// Printed on the membership certificate; optional at sign-up.
  DateTime? _dob;
  String _photoUrl = '';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name, _father, _jati, _gotra, _waris, _warisRelation, _phone,
      _altPhone, _aadhaar, _village, _tehsil, _district, _state, _pincode,
      _contribution,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(agentActionsProvider).addMember(
            Member(
              id: '',
              yojnaId: _yojnaId!,
              regNo: '',
              name: _name.text.trim(),
              fatherOrHusbandName: _father.text.trim(),
              jati: _jati.text.trim(),
              gotra: _gotra.text.trim(),
              dob: _dob,
              warisName: _waris.text.trim(),
              warisRelation: _warisRelation.text.trim(),
              gender: _gender,
              primaryPhone: _phone.text.trim(),
              altPhone: _altPhone.text.trim(),
              aadhaar: _aadhaar.text.trim(),
              village: _village.text.trim(),
              tehsil: _tehsil.text.trim(),
              district: _district.text.trim(),
              state: _state.text.trim(),
              pincode: _pincode.text.trim(),
              joinDate: _joinDate,
              status: MemberStatus.pending,
              photoUrl: _photoUrl,
              contributionAmount: double.tryParse(
                    _contribution.text.trim().replaceAll(',', ''),
                  ) ??
                  0,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, '${_name.text.trim()} sent for approval');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yojnas = ref.watch(agentYojnasProvider).value ?? const <Yojna>[];
    if (_yojnaId == null && yojnas.length == 1) _yojnaId = yojnas.first.id;

    return AppDialog(
      title: S.addMember,
      subtitle: 'The office approves new members and issues the reg number.',
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const ButtonSpinner()
              : const Text('Send for approval'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSection(
              title: S.membershipInfo,
              child: FormGrid(
                items: [
                  GridItem(
                    AppDropdown<String>(
                      label: S.selectProgram,
                      required: true,
                      value: _yojnaId,
                      items: [for (final y in yojnas) y.id],
                      itemLabel: (id) =>
                          yojnas.firstWhere((y) => y.id == id).name,
                      onChanged: (v) => setState(() => _yojnaId = v),
                      validator: (v) => v == null ? S.required : null,
                    ),
                  ),
                  // Members of one Yojna pay different amounts; the office
                  // can correct it when approving.
                  GridItem(AppTextField(
                    label: S.fldContribution,
                    controller: _contribution,
                    required: true,
                    hint: 'e.g. 200',
                    prefixIcon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.amount,
                  )),
                  GridItem(AppDateField(
                    label: S.fldJoinDate,
                    value: _joinDate,
                    lastDate: DateTime.now(),
                    onChanged: (d) => setState(() => _joinDate = d),
                  )),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            FormSection(
              title: S.personalInfo,
              child: FormGrid(
                items: [
                  GridItem(
                    MemberPhotoPicker(
                      url: _photoUrl,
                      onChanged: (u) => setState(() => _photoUrl = u),
                    ),
                  ),
                  GridItem(AppTextField(
                    label: S.fldName,
                    controller: _name,
                    required: true,
                    validator: V.required,
                  )),
                  GridItem(AppTextField(
                    label: S.fldFather,
                    controller: _father,
                    required: true,
                    validator: V.required,
                  )),
                  GridItem(AppTextField(label: S.fldJati, controller: _jati)),
                  GridItem(AppTextField(label: S.fldGotra, controller: _gotra)),
                  GridItem(AppDropdown<Gender>(
                    label: S.fldGender,
                    required: true,
                    value: _gender,
                    items: Gender.values,
                    itemLabel: (g) => g.label,
                    onChanged: (v) => setState(() => _gender = v ?? _gender),
                  )),
                  GridItem(AppTextField(
                    label: S.fldWaris,
                    controller: _waris,
                    required: true,
                    validator: V.required,
                  )),
                  GridItem(AppTextField(
                    label: S.fldWarisRelation,
                    controller: _warisRelation,
                    required: true,
                    validator: V.required,
                  )),
                  GridItem(AppTextField(
                    label: '${S.fldAadhaar} (optional)',
                    controller: _aadhaar,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.aadhaar(),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? null : V.aadhaar(v),
                  )),
                  GridItem(AppDateField(
                    label: S.fldDob,
                    value: _dob,
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                    onChanged: (d) => setState(() => _dob = d),
                  )),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            FormSection(
              title: S.contactInfo,
              child: _ContactFields(
                phone: _phone,
                altPhone: _altPhone,
                village: _village,
                tehsil: _tehsil,
                district: _district,
                state: _state,
                pincode: _pincode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactFields extends StatelessWidget {
  const _ContactFields({
    required this.phone,
    required this.altPhone,
    required this.village,
    required this.tehsil,
    required this.district,
    required this.state,
    required this.pincode,
    this.email,
  });

  final TextEditingController phone;
  final TextEditingController altPhone;
  final TextEditingController village;
  final TextEditingController tehsil;
  final TextEditingController district;
  final TextEditingController state;
  final TextEditingController pincode;

  /// The member's own email, on the Edit contact form only: with it on
  /// their record they sign in to the app without an invite.
  final TextEditingController? email;

  @override
  Widget build(BuildContext context) {
    final email = this.email;
    return FormGrid(
      items: [
        GridItem(AppTextField(
          label: S.fldPrimaryPhone,
          controller: phone,
          required: true,
          keyboardType: TextInputType.phone,
          inputFormatters: Fmts.phone(),
          validator: V.phone,
        )),
        GridItem(AppTextField(
          label: S.fldAltPhone,
          controller: altPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: Fmts.phone(),
          validator: V.optionalPhone,
        )),
        GridItem(AppTextField(label: S.fldVillage, controller: village)),
        GridItem(AppTextField(label: S.fldTehsil, controller: tehsil)),
        GridItem(AppTextField(label: S.fldDistrict, controller: district)),
        GridItem(AppTextField(label: S.fldState, controller: state)),
        GridItem(AppTextField(
          label: S.fldPincode,
          controller: pincode,
          keyboardType: TextInputType.number,
          inputFormatters: Fmts.pincode(),
          validator: V.pincode,
        )),
        if (email != null)
          GridItem(AppTextField(
            label: S.fldMemberEmail,
            controller: email,
            hint: 'name@example.com',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: V.optionalEmail,
          )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit contact
// ---------------------------------------------------------------------------

Future<void> showContactForm(BuildContext context, Member member) =>
    AppDialog.show<void>(
      context: context,
      builder: (_) => _ContactForm(member: member),
    );

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({required this.member});

  final Member member;

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.member.primaryPhone);
  late final _altPhone = TextEditingController(text: widget.member.altPhone);
  late final _village = TextEditingController(text: widget.member.village);
  late final _tehsil = TextEditingController(text: widget.member.tehsil);
  late final _district = TextEditingController(text: widget.member.district);
  late final _state = TextEditingController(text: widget.member.state);
  late final _pincode = TextEditingController(text: widget.member.pincode);
  late final _email = TextEditingController(text: widget.member.email);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _phone, _altPhone, _village, _tehsil, _district, _state, _pincode,
      _email,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(agentActionsProvider).updateContact(
            widget.member.copyWith(
              primaryPhone: _phone.text.trim(),
              altPhone: _altPhone.text.trim(),
              village: _village.text.trim(),
              tehsil: _tehsil.text.trim(),
              district: _district.text.trim(),
              state: _state.text.trim(),
              pincode: _pincode.text.trim(),
              email: _email.text.trim().toLowerCase(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, 'Contact details saved');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: S.editContact,
      subtitle: '${widget.member.name} · name, nominee and Aadhaar changes '
          'go through the office.',
      maxWidth: 720,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const ButtonSpinner() : const Text(S.save),
        ),
      ],
      child: Form(
        key: _formKey,
        child: _ContactFields(
          phone: _phone,
          altPhone: _altPhone,
          village: _village,
          tehsil: _tehsil,
          district: _district,
          state: _state,
          pincode: _pincode,
          email: _email,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Record payment
// ---------------------------------------------------------------------------

/// [closingCaseId] preselects the closing a contribution is for.
Future<void> showAgentPaymentForm(
  BuildContext context, {
  Member? member,
  String? closingCaseId,
}) =>
    AppDialog.show<void>(
      context: context,
      builder: (_) =>
          _AgentPaymentForm(preset: member, presetClosingId: closingCaseId),
    );

class _AgentPaymentForm extends ConsumerStatefulWidget {
  const _AgentPaymentForm({this.preset, this.presetClosingId});

  final Member? preset;
  final String? presetClosingId;

  @override
  ConsumerState<_AgentPaymentForm> createState() => _AgentPaymentFormState();
}

class _AgentPaymentFormState extends ConsumerState<_AgentPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();

  late Member? _member = widget.preset;
  late PaymentKind _kind = _defaultKind(widget.preset);
  PaymentMode _mode = PaymentMode.cash;
  DateTime _date = DateTime.now();
  bool _saving = false;

  String _search = '';
  List<Member> _results = const [];

  /// Closings the member still owes for; null until loaded.
  List<MemberDue>? _dues;
  late String? _closingId = widget.presetClosingId;

  static PaymentKind _defaultKind(Member? m) =>
      m != null && m.status != MemberStatus.active
          ? PaymentKind.registration
          : PaymentKind.contribution;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillAmount();
      _loadDues();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  void _prefillAmount() {
    final member = _member;
    if (member == null || !mounted) return;
    final yojnas = ref.read(agentYojnasProvider).value ?? const <Yojna>[];
    final yojna = yojnas.where((y) => y.id == member.yojnaId).firstOrNull;
    final amount = _kind == PaymentKind.registration
        ? (yojna?.registrationFee ?? 0)
        : member.contributionAmount;
    if (amount > 0) _amount.text = amount.toStringAsFixed(0);
    final due = _selectedDue;
    if (due != null && due.toCollect > 0) {
      _amount.text = due.toCollect.toStringAsFixed(0);
    }
  }

  MemberDue? get _selectedDue =>
      _dues?.where((d) => d.closingCaseId == _closingId).firstOrNull;

  /// Only still-open closings can be picked.
  List<MemberDue> get _openDues =>
      (_dues ?? const <MemberDue>[]).where((d) => d.toCollect > 0).toList();

  bool get _showsClosing =>
      _kind == PaymentKind.contribution &&
      _member?.status == MemberStatus.active;

  /// Picks the oldest closing still to collect, unless one was preset.
  Future<void> _loadDues() async {
    final member = _member;
    if (member == null || member.status != MemberStatus.active) return;
    try {
      final dues = await ref.read(agentActionsProvider).memberDues(member.id);
      if (!mounted || _member?.id != member.id) return;
      setState(() {
        _dues = dues;
        final open = _openDues;
        if (!open.any((d) => d.closingCaseId == _closingId)) {
          _closingId = open.firstOrNull?.closingCaseId;
        }
      });
      _prefillAmount();
    } catch (_) {
      // The form still works without a closing; saving reports real errors.
      if (mounted) setState(() => _dues = const []);
    }
  }

  Future<void> _find(String text) async {
    _search = text;
    if (text.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    try {
      final found = await ref.read(agentActionsProvider).searchMembers(text);
      if (mounted && _search == text) setState(() => _results = found);
    } catch (_) {
      // Keep the previous results; saving reports real errors.
    }
  }

  void _pick(Member m) {
    setState(() {
      _member = m;
      _kind = _defaultKind(m);
      _results = const [];
      _dues = null;
      _closingId = null;
    });
    _prefillAmount();
    _loadDues();
  }

  Future<void> _submit() async {
    final member = _member;
    if (member == null) {
      showToast(context, 'Select a member', error: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final closing = _showsClosing ? _selectedDue : null;
    final payment = Payment(
      id: '',
      receiptNo: '',
      memberId: member.id,
      yojnaId: member.yojnaId,
      amount: double.parse(_amount.text.replaceAll(',', '').trim()),
      date: _date,
      mode: _mode,
      kind: _kind,
      status: PaymentStatus.pending,
      reference: _reference.text.trim(),
      note: _note.text.trim(),
      closingCaseId: closing?.closingCaseId,
      closingGroup: closing?.closingGroup ?? '',
      source: PaymentSource.agent,
    );
    try {
      final receiptNo =
          await ref.read(agentActionsProvider).recordPayment(payment);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final outer = navigator.context;
      navigator.pop();
      if (!outer.mounted) return;
      showReceiptSaved(
        outer,
        member: member,
        payment: payment.copyWith(receiptNo: receiptNo),
      );
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final member = _member;

    return AppDialog(
      title: S.recordPayment,
      subtitle: 'Counts in the trust totals after the office approves it.',
      maxWidth: 720,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const ButtonSpinner() : const Text(S.save),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (member == null) ...[
              AppTextField(
                label: 'Member',
                hint: 'Name, reg no or phone',
                prefixIcon: Icons.search_rounded,
                autofocus: true,
                onChanged: _find,
              ),
              for (final m in _results)
                ListTile(
                  dense: true,
                  title: Text(m.name),
                  subtitle: Text(
                    [m.regNo, Fmt.phone(m.primaryPhone), m.status.label]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                  onTap: () => _pick(m),
                ),
              if (_search.trim().isNotEmpty && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    S.noResults,
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                ),
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(member.name),
                subtitle: Text(
                  [member.regNo, Fmt.phone(member.primaryPhone), member.status.label]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                ),
                trailing: widget.preset == null
                    ? TextButton(
                        onPressed: () => setState(() => _member = null),
                        child: const Text('Change'),
                      )
                    : null,
              ),
            const SizedBox(height: Space.lg),
            FormGrid(
              columnsOverride: context.isMobile ? 1 : 2,
              items: [
                GridItem(AppDropdown<PaymentKind>(
                  label: 'Type',
                  value: _kind,
                  items: const [PaymentKind.contribution, PaymentKind.registration],
                  itemLabel: (k) => k.label,
                  onChanged: (v) {
                    setState(() => _kind = v ?? _kind);
                    _prefillAmount();
                  },
                )),
                if (_showsClosing && _dues != null)
                  GridItem(AppDropdown<String>(
                    key: ValueKey('closing-${member?.id}-${_dues!.length}'),
                    label: S.forClosing,
                    value: _closingId,
                    items: [for (final d in _openDues) d.closingCaseId],
                    itemLabel: (id) {
                      final d = _openDues.firstWhere((d) => d.closingCaseId == id);
                      return '${d.title} · ${Fmt.date(d.closingDate)} · '
                          '${Fmt.money(d.toCollect)}';
                    },
                    includeAllOption: true,
                    allLabel: _openDues.isEmpty
                        ? 'Nothing due'
                        : S.notForClosing,
                    onChanged: (v) {
                      setState(() => _closingId = v);
                      _prefillAmount();
                    },
                  )),
                GridItem(AppTextField(
                  label: S.amount,
                  controller: _amount,
                  required: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: Fmts.amount(),
                  validator: V.amount,
                )),
                GridItem(AppDropdown<PaymentMode>(
                  label: S.mode,
                  value: _mode,
                  items: PaymentMode.manual,
                  itemLabel: (m) => m.label,
                  onChanged: (v) => setState(() => _mode = v ?? _mode),
                )),
                GridItem(AppTextField(
                  label: 'UTR / cheque no',
                  controller: _reference,
                  validator: (v) => _mode != PaymentMode.cash &&
                          (v ?? '').trim().isEmpty
                      ? S.required
                      : null,
                )),
                GridItem(AppDateField(
                  label: S.date,
                  value: _date,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => _date = d),
                )),
                GridItem(AppTextField(label: 'Note', controller: _note)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WhatsApp
// ---------------------------------------------------------------------------

/// Opens WhatsApp with [text] for [phone], or says why it can't.
Future<void> sendOnWhatsApp(
  BuildContext context, {
  required String phone,
  required String text,
}) async {
  final uri = WhatsApp.link(phone, text);
  if (uri == null) {
    showToast(context, S.noPhone, error: true);
    return;
  }
  final opened = await WhatsApp.open(uri);
  if (!opened && context.mounted) {
    showToast(context, S.whatsAppFailed, error: true);
  }
}

/// After recording a payment: the receipt number, and sending it to the member.
Future<void> showReceiptSaved(
  BuildContext context, {
  required Member member,
  required Payment payment,
}) =>
    AppDialog.show<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Receipt ${payment.receiptNo}',
        subtitle: 'Saved · waiting for approval',
        maxWidth: 480,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => printPaymentReceipt(
              dialogContext,
              payment: payment,
              member: member,
            ),
            icon: const Icon(Icons.print_outlined, size: 17),
            label: const Text('Print receipt'),
          ),
          FilledButton.icon(
            onPressed: () => sendOnWhatsApp(
              dialogContext,
              phone: member.primaryPhone,
              text: WhatsApp.receiptMessage(
                memberName: member.name,
                payment: payment,
              ),
            ),
            icon: const Icon(Icons.chat_outlined, size: 17),
            label: const Text(S.shareReceipt),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailRow(label: 'Member', value: member.name),
            DetailRow(label: S.amount, value: Fmt.money(payment.amount)),
            DetailRow(label: 'Type', value: payment.kind.label),
            if (payment.closingGroup.isNotEmpty)
              DetailRow(label: S.forClosing, value: payment.closingGroup),
          ],
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Report closing
// ---------------------------------------------------------------------------

Future<void> showClosingReportForm(BuildContext context, Member member) =>
    AppDialog.show<void>(
      context: context,
      builder: (_) => _ClosingReportForm(member: member),
    );

class _ClosingReportForm extends ConsumerStatefulWidget {
  const _ClosingReportForm({required this.member});

  final Member member;

  @override
  ConsumerState<_ClosingReportForm> createState() => _ClosingReportFormState();
}

class _ClosingReportFormState extends ConsumerState<_ClosingReportForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nominee = TextEditingController(text: widget.member.warisName);
  late final _relation =
      TextEditingController(text: widget.member.warisRelation);
  final _remarks = TextEditingController();

  DateTime _eventDate = DateTime.now();
  String? _fileName;
  Uint8List? _bytes;
  bool _saving = false;
  String _progress = '';

  @override
  void dispose() {
    _nominee.dispose();
    _relation.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _pickCertificate() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: CertificateUploader.allowedExtensions,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      CertificateUploader.check(bytes.length, file.name);
      if (mounted) {
        setState(() {
          _fileName = file.name;
          _bytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bytes = _bytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null) {
      showToast(context, 'Choose the proof document', error: true);
      return;
    }
    final actions = ref.read(agentActionsProvider);
    setState(() {
      _saving = true;
      _progress = 'Uploading certificate…';
    });
    try {
      final url = await actions.uploadCertificate(bytes, fileName);
      if (mounted) setState(() => _progress = 'Sending to the office…');
      await actions.reportClosing(
        ClosingRequest(
          id: '',
          memberId: widget.member.id,
          eventDate: _eventDate,
          nomineeName: _nominee.text.trim(),
          nomineeRelation: _relation.text.trim(),
          certificateUrl: url,
          remarks: _remarks.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, 'Reported · the office will verify it');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.member;

    return AppDialog(
      title: S.reportClosing,
      subtitle: '${m.name}${m.regNo.isEmpty ? '' : ' · ${m.regNo}'}',
      maxWidth: 640,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const ButtonSpinner() : const Text('Send to office'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The office checks the certificate and opens the closing. '
              'Members start paying dues after that.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: Space.lg),
            FormGrid(
              columnsOverride: context.isMobile ? 1 : 2,
              items: [
                GridItem(AppDateField(
                  label: S.eventDate,
                  required: true,
                  value: _eventDate,
                  firstDate: m.joinDate,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => _eventDate = d),
                )),
                GridItem(AppTextField(
                  label: S.fldWaris,
                  controller: _nominee,
                  required: true,
                  validator: V.required,
                )),
                GridItem(AppTextField(
                  label: S.fldWarisRelation,
                  controller: _relation,
                  required: true,
                  validator: V.required,
                )),
                GridItem(AppTextField(label: 'Remarks', controller: _remarks)),
              ],
            ),
            const SizedBox(height: Space.lg),
            FieldLabel(S.proofDocument, required: true),
            Wrap(
              spacing: Space.md,
              runSpacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickCertificate,
                  icon: const Icon(Icons.upload_file_rounded, size: 17),
                  label: Text(_fileName == null ? 'Choose photo or PDF' : 'Change'),
                ),
                Text(
                  _fileName == null
                      ? 'JPG, PNG or PDF, up to 10 MB'
                      : '$_fileName · ${(_bytes!.length / 1024).ceil()} KB',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
            if (_progress.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text(_progress, style: TextStyle(fontSize: 13, color: c.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

