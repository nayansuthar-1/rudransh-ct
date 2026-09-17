import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/agent_providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/inputs.dart';

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
  final _pincode = TextEditingController();

  String? _yojnaId;
  Gender _gender = Gender.male;
  DateTime _joinDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name, _father, _jati, _gotra, _waris, _warisRelation, _phone,
      _altPhone, _aadhaar, _village, _tehsil, _district, _pincode,
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
              warisName: _waris.text.trim(),
              warisRelation: _warisRelation.text.trim(),
              gender: _gender,
              primaryPhone: _phone.text.trim(),
              altPhone: _altPhone.text.trim(),
              aadhaar: _aadhaar.text.trim(),
              village: _village.text.trim(),
              tehsil: _tehsil.text.trim(),
              district: _district.text.trim(),
              pincode: _pincode.text.trim(),
              joinDate: _joinDate,
              status: MemberStatus.pending,
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
              title: S.personalInfo,
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
              title: S.contactInfo,
              child: _ContactFields(
                phone: _phone,
                altPhone: _altPhone,
                village: _village,
                tehsil: _tehsil,
                district: _district,
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
    required this.pincode,
  });

  final TextEditingController phone;
  final TextEditingController altPhone;
  final TextEditingController village;
  final TextEditingController tehsil;
  final TextEditingController district;
  final TextEditingController pincode;

  @override
  Widget build(BuildContext context) {
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
        GridItem(AppTextField(
          label: S.fldPincode,
          controller: pincode,
          keyboardType: TextInputType.number,
          inputFormatters: Fmts.pincode(),
          validator: V.pincode,
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
  late final _pincode = TextEditingController(text: widget.member.pincode);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_phone, _altPhone, _village, _tehsil, _district, _pincode]) {
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
              pincode: _pincode.text.trim(),
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
          pincode: _pincode,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Record payment
// ---------------------------------------------------------------------------

Future<void> showAgentPaymentForm(BuildContext context, {Member? member}) =>
    AppDialog.show<void>(
      context: context,
      builder: (_) => _AgentPaymentForm(preset: member),
    );

class _AgentPaymentForm extends ConsumerStatefulWidget {
  const _AgentPaymentForm({this.preset});

  final Member? preset;

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

  static PaymentKind _defaultKind(Member? m) =>
      m != null && m.status != MemberStatus.active
          ? PaymentKind.registration
          : PaymentKind.contribution;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillAmount());
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
    if (yojna == null) return;
    final amount = _kind == PaymentKind.registration
        ? yojna.registrationFee
        : yojna.contributionAmount;
    if (amount > 0) _amount.text = amount.toStringAsFixed(0);
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
    });
    _prefillAmount();
  }

  Future<void> _submit() async {
    final member = _member;
    if (member == null) {
      showToast(context, 'Select a member', error: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final receiptNo = await ref.read(agentActionsProvider).recordPayment(
            Payment(
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
              source: PaymentSource.agent,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, 'Saved · $receiptNo · waiting for approval');
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
                  items: PaymentMode.values,
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
