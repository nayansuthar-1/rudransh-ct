import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';

/// Opens the "Add Member" dialog. Pass [existing] to edit instead.
Future<void> showMemberFormDialog(
  BuildContext context, {
  Member? existing,
  String? presetYojnaId,
}) {
  return AppDialog.show<void>(
    context: context,
    builder: (_) => MemberFormDialog(
      existing: existing,
      presetYojnaId: presetYojnaId,
    ),
  );
}

class MemberFormDialog extends ConsumerStatefulWidget {
  const MemberFormDialog({super.key, this.existing, this.presetYojnaId});

  final Member? existing;
  final String? presetYojnaId;

  @override
  ConsumerState<MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends ConsumerState<MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _father;
  late final TextEditingController _jati;
  late final TextEditingController _gotra;
  late final TextEditingController _waris;
  late final TextEditingController _primaryPhone;
  late final TextEditingController _altPhone;
  late final TextEditingController _email;
  late final TextEditingController _aadhaar;
  late final TextEditingController _village;
  late final TextEditingController _tehsil;
  late final TextEditingController _district;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  final _copyPhone = TextEditingController();

  String? _yojnaId;
  String? _agentId;
  Gender _gender = Gender.male;
  DateTime? _dob;
  String _relation = 'Son';
  MemberStatus _status = MemberStatus.active;
  DateTime _joinDate = DateTime.now();
  String _photoUrl = '';

  bool _saving = false;
  bool _looking = false;

  /// Recorded on the member row when they are first enrolled
  /// (IMPLEMENTATION_PLAN §7). Only asked on a new member.
  bool _consent = false;

  static const _relations = [
    'Son',
    'Daughter',
    'Wife',
    'Husband',
    'Brother',
    'Mother',
    'Father',
    'Other',
  ];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _father = TextEditingController(text: m?.fatherOrHusbandName ?? '');
    _jati = TextEditingController(text: m?.jati ?? '');
    _gotra = TextEditingController(text: m?.gotra ?? '');
    _waris = TextEditingController(text: m?.warisName ?? '');
    _primaryPhone = TextEditingController(text: m?.primaryPhone ?? '');
    _altPhone = TextEditingController(text: m?.altPhone ?? '');
    _email = TextEditingController(text: m?.email ?? '');
    _aadhaar = TextEditingController(text: m?.aadhaar ?? '');
    _village = TextEditingController(text: m?.village ?? '');
    _tehsil = TextEditingController(text: m?.tehsil ?? '');
    _district = TextEditingController(text: m?.district ?? '');
    _state = TextEditingController(text: m?.state ?? '');
    _pincode = TextEditingController(text: m?.pincode ?? '');

    _yojnaId = m?.yojnaId ?? widget.presetYojnaId;
    _agentId = m?.agentId;
    _gender = m?.gender ?? Gender.male;
    _dob = m?.dob;
    _relation = m?.warisRelation.isNotEmpty == true ? m!.warisRelation : 'Son';
    _status = m?.status ?? MemberStatus.active;
    _joinDate = m?.joinDate ?? DateTime.now();
    _photoUrl = m?.photoUrl ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _father,
      _jati,
      _gotra,
      _waris,
      _primaryPhone,
      _altPhone,
      _email,
      _aadhaar,
      _village,
      _tehsil,
      _district,
      _state,
      _pincode,
      _copyPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _copyFromExisting() async {
    final phone = _copyPhone.text.trim();
    if (phone.length < 10) {
      showToast(context, S.invalidPhone, error: true);
      return;
    }
    setState(() => _looking = true);
    final found =
        await ref.read(memberActionsProvider).findByPhone(phone);
    if (!mounted) return;
    setState(() => _looking = false);

    if (found == null) {
      showToast(context, S.memberNotFound, error: true);
      return;
    }

    // Copy household details but leave identity fields for the new person.
    setState(() {
      _father.text = found.fatherOrHusbandName;
      _jati.text = found.jati;
      _gotra.text = found.gotra;
      _village.text = found.village;
      _tehsil.text = found.tehsil;
      _district.text = found.district;
      _state.text = found.state;
      _pincode.text = found.pincode;
      _agentId = found.agentId;
      _primaryPhone.text = found.primaryPhone;
    });
    showToast(context, '${S.memberCopied}: ${found.name}');
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_yojnaId == null) {
      showToast(context, S.selectProgram, error: true);
      return;
    }
    if (!_isEdit && !_consent) {
      showToast(context, S.consentRequired, error: true);
      return;
    }

    setState(() => _saving = true);
    final notifier = ref.read(memberActionsProvider);

    try {
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.copyWith(
            yojnaId: _yojnaId,
            name: _name.text.trim(),
            fatherOrHusbandName: _father.text.trim(),
            jati: _jati.text.trim(),
            gotra: _gotra.text.trim(),
            dob: _dob,
            clearDob: _dob == null,
            warisName: _waris.text.trim(),
            warisRelation: _relation,
            gender: _gender,
            primaryPhone: _primaryPhone.text.trim(),
            altPhone: _altPhone.text.trim(),
            email: _email.text.trim().toLowerCase(),
            aadhaar: _aadhaar.text.trim(),
            village: _village.text.trim(),
            tehsil: _tehsil.text.trim(),
            district: _district.text.trim(),
            state: _state.text.trim(),
            pincode: _pincode.text.trim(),
            agentId: _agentId,
            clearAgent: _agentId == null,
            joinDate: _joinDate,
            status: _status,
            photoUrl: _photoUrl,
          ),
        );
      } else {
        final regNo = await notifier.nextRegNo(_yojnaId!);
        await notifier.add(
          Member(
            id: '',
            yojnaId: _yojnaId!,
            regNo: regNo,
            name: _name.text.trim(),
            fatherOrHusbandName: _father.text.trim(),
            jati: _jati.text.trim(),
            gotra: _gotra.text.trim(),
            dob: _dob,
            warisName: _waris.text.trim(),
            warisRelation: _relation,
            gender: _gender,
            primaryPhone: _primaryPhone.text.trim(),
            altPhone: _altPhone.text.trim(),
            email: _email.text.trim().toLowerCase(),
            aadhaar: _aadhaar.text.trim(),
            village: _village.text.trim(),
            tehsil: _tehsil.text.trim(),
            district: _district.text.trim(),
            state: _state.text.trim(),
            pincode: _pincode.text.trim(),
            agentId: _agentId,
            joinDate: _joinDate,
            status: _status,
            consentAt: DateTime.now(),
            photoUrl: _photoUrl,
          ),
        );
      }

      if (!mounted) return;
      showToast(
        context,
        _isEdit ? 'Member updated' : 'Member added',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];
    final agents = ref.watch(agentsProvider).value ?? const <Agent>[];

    return AppDialog(
      title: _isEdit ? S.editMemberTitle : S.addMemberTitle,
      subtitle: _isEdit ? widget.existing!.regNo : null,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const ButtonSpinner()
              : const Text(S.submit),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<Yojna>(
              label: S.selectProgram,
              required: true,
              value: yojnas.where((y) => y.id == _yojnaId).firstOrNull,
              items: yojnas.where((y) => y.isActive || y.id == _yojnaId).toList(),
              itemLabel: (y) => y.name,
              hint: S.selectYojna,
              validator: (v) => v == null ? S.required : null,
              onChanged: (v) => setState(() => _yojnaId = v?.id),
            ),
            const SizedBox(height: 18),

            if (!_isEdit) ...[
              _copyBlock(context),
              const SizedBox(height: 20),
              Divider(color: c.border),
              const SizedBox(height: 18),
            ],

            FormSection(
              title: S.personalInfo,
              child: FormGrid(
                items: [
                  GridItem(
                    _photoPicker(),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldName,
                      required: true,
                      controller: _name,
                      hint: S.fldNameHint,
                      validator: V.required,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldFather,
                      required: true,
                      controller: _father,
                      hint: S.fldFather,
                      validator: V.required,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldJati,
                      required: true,
                      controller: _jati,
                      hint: 'Jati',
                      validator: V.required,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldGotra,
                      controller: _gotra,
                      hint: 'Gotra',
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldWaris,
                      required: true,
                      controller: _waris,
                      hint: 'Nominee name',
                      validator: V.required,
                    ),
                  ),
                  GridItem(
                    AppDropdown<String>(
                      label: S.fldWarisRelation,
                      required: true,
                      value: _relation,
                      // Keep a value saved before the list changed (older
                      // records store Hindi relations) selectable.
                      items: _relations.contains(_relation)
                          ? _relations
                          : [_relation, ..._relations],
                      itemLabel: (r) => r,
                      onChanged: (v) =>
                          setState(() => _relation = v ?? _relation),
                    ),
                  ),
                  GridItem(
                    AppDropdown<Gender>(
                      label: S.fldGender,
                      required: true,
                      value: _gender,
                      items: Gender.values,
                      itemLabel: (g) => g.label,
                      onChanged: (v) => setState(() => _gender = v ?? _gender),
                    ),
                  ),
                  // Printed on the membership certificate.
                  GridItem(
                    AppDateField(
                      label: S.fldDob,
                      value: _dob,
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                      onChanged: (d) => setState(() => _dob = d),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            FormSection(
              title: S.contactInfo,
              child: FormGrid(
                items: [
                  GridItem(
                    AppTextField(
                      label: S.fldPrimaryPhone,
                      required: true,
                      controller: _primaryPhone,
                      hint: '98765 43210',
                      prefixIcon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: Fmts.phone(),
                      validator: V.phone,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldAltPhone,
                      controller: _altPhone,
                      hint: '—',
                      prefixIcon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: Fmts.phone(),
                      validator: V.optionalPhone,
                    ),
                  ),
                  // Lets the member sign in with it, without an invite.
                  GridItem(
                    AppTextField(
                      label: S.fldMemberEmail,
                      controller: _email,
                      hint: 'name@example.com',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: V.optionalEmail,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldAadhaar,
                      // On an edit the number cannot be shown: it is encrypted
                      // and only an owner can fetch it (§7). Leaving the box
                      // empty keeps whatever is on record.
                      required: !_isEdit,
                      controller: _aadhaar,
                      hint: _isEdit
                          ? '${Fmt.aadhaarFromLast4(widget.existing!.aadhaarLast4)}'
                              ' — leave blank to keep'
                          : '1234 5678 9012',
                      prefixIcon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: Fmts.aadhaar(),
                      validator: (v) => _isEdit && (v ?? '').trim().isEmpty
                          ? null
                          : V.aadhaar(v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            FormSection(
              title: S.addressInfo,
              child: FormGrid(
                items: [
                  GridItem(AppTextField(label: S.fldVillage, controller: _village)),
                  GridItem(AppTextField(label: S.fldTehsil, controller: _tehsil)),
                  GridItem(AppTextField(label: S.fldDistrict, controller: _district)),
                  GridItem(AppTextField(label: S.fldState, controller: _state)),
                  GridItem(
                    AppTextField(
                      label: S.fldPincode,
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      inputFormatters: Fmts.pincode(),
                      validator: V.pincode,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            FormSection(
              title: S.membershipInfo,
              child: FormGrid(
                items: [
                  GridItem(
                    AppDropdown<Agent>(
                      label: S.fldAgent,
                      value: agents.where((a) => a.id == _agentId).firstOrNull,
                      items: agents.where((a) => a.isActive).toList(),
                      itemLabel: (a) => '${a.code} · ${a.name}',
                      includeAllOption: true,
                      allLabel: '— None —',
                      onChanged: (v) => setState(() => _agentId = v?.id),
                    ),
                  ),
                  GridItem(
                    AppDateField(
                      label: S.fldJoinDate,
                      value: _joinDate,
                      onChanged: (d) => setState(() => _joinDate = d),
                    ),
                  ),
                  GridItem(
                    AppDropdown<MemberStatus>(
                      label: S.status,
                      value: _status,
                      // Pending is set by agents and cleared by approval.
                      items: MemberStatus.values
                          .where((s) =>
                              s != MemberStatus.pending ||
                              widget.existing?.status == MemberStatus.pending)
                          .toList(),
                      itemLabel: (s) => s.label,
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: Space.lg),
              _ConsentTile(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _copyBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(S.copyFromExisting),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 460;
            final field = TextField(
              controller: _copyPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: Fmts.phone(),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (_) => _copyFromExisting(),
              decoration: const InputDecoration(
                hintText: S.copyFromExistingHint,
                prefixIcon: Icon(Icons.call_outlined, size: 17),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 38, minHeight: 38),
              ),
            );
            final button = OutlinedButton.icon(
              onPressed: _looking ? null : _copyFromExisting,
              icon: _looking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 16),
              label: const Text(S.search),
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 10), button],
              );
            }
            return Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 12),
                SizedBox(width: 140, child: button),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _photoPicker() {
    final c = context.colors;
    final hasPhoto = _photoUrl.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Member Photo'),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final file = await FilePicker.pickFile(
              type: FileType.image,
            );
            if (file != null) {
              final bytes = await file.readAsBytes();
              final b64 = base64Encode(bytes);
              setState(() {
                _photoUrl = 'data:image/jpeg;base64,$b64';
              });
            }
          },
          borderRadius: BorderRadius.circular(Radii.panel),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(Radii.panel),
              color: c.surfaceMuted,
            ),
            child: hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.panel),
                    child: Image.memory(
                      base64Decode(_photoUrl.split(',').last),
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: c.textSecondary, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add photo',
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
        if (hasPhoto)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _photoUrl = ''),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

/// Consent to the trust holding the member's details (IMPLEMENTATION_PLAN §7,
/// DPDP Act 2023). Asked once, when the member is enrolled; the time is stored
/// on the member row.
class _ConsentTile extends StatelessWidget {
  const _ConsentTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // `tileColor` rather than a wrapping DecoratedBox: a ListTile paints its
    // ink on the nearest Material, and a coloured box in between hides it.
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      tileColor: c.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.panel),
        side: BorderSide(color: c.border),
      ),
      title: const Text(S.consentTitle, style: TextStyle(fontSize: 14)),
      subtitle: Text(
        S.consentBody,
        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
      ),
    );
  }
}
