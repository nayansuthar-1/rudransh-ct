import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';

/// Opens the "नया सदस्य जोड़ें" dialog. Pass [existing] to edit instead.
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
  late final TextEditingController _aadhaar;
  late final TextEditingController _village;
  late final TextEditingController _tehsil;
  late final TextEditingController _district;
  late final TextEditingController _pincode;
  final _copyPhone = TextEditingController();

  String? _yojnaId;
  String? _agentId;
  Gender _gender = Gender.male;
  String _relation = 'पुत्र';
  MemberStatus _status = MemberStatus.active;
  DateTime _joinDate = DateTime.now();

  bool _saving = false;
  bool _looking = false;

  static const _relations = ['पुत्र', 'पुत्री', 'पत्नी', 'पति', 'भाई', 'माता', 'अन्य'];

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
    _aadhaar = TextEditingController(text: m?.aadhaar ?? '');
    _village = TextEditingController(text: m?.village ?? '');
    _tehsil = TextEditingController(text: m?.tehsil ?? '');
    _district = TextEditingController(text: m?.district ?? '');
    _pincode = TextEditingController(text: m?.pincode ?? '');

    _yojnaId = m?.yojnaId ?? widget.presetYojnaId;
    _agentId = m?.agentId;
    _gender = m?.gender ?? Gender.male;
    _relation = m?.warisRelation.isNotEmpty == true ? m!.warisRelation : 'पुत्र';
    _status = m?.status ?? MemberStatus.active;
    _joinDate = m?.joinDate ?? DateTime.now();
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
      _aadhaar,
      _village,
      _tehsil,
      _district,
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
        await ref.read(membersProvider.notifier).findByPhone(phone);
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

    setState(() => _saving = true);
    final notifier = ref.read(membersProvider.notifier);

    try {
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.copyWith(
            yojnaId: _yojnaId,
            name: _name.text.trim(),
            fatherOrHusbandName: _father.text.trim(),
            jati: _jati.text.trim(),
            gotra: _gotra.text.trim(),
            warisName: _waris.text.trim(),
            warisRelation: _relation,
            gender: _gender,
            primaryPhone: _primaryPhone.text.trim(),
            altPhone: _altPhone.text.trim(),
            aadhaar: _aadhaar.text.trim(),
            village: _village.text.trim(),
            tehsil: _tehsil.text.trim(),
            district: _district.text.trim(),
            pincode: _pincode.text.trim(),
            agentId: _agentId,
            clearAgent: _agentId == null,
            joinDate: _joinDate,
            status: _status,
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
            warisName: _waris.text.trim(),
            warisRelation: _relation,
            gender: _gender,
            primaryPhone: _primaryPhone.text.trim(),
            altPhone: _altPhone.text.trim(),
            aadhaar: _aadhaar.text.trim(),
            village: _village.text.trim(),
            tehsil: _tehsil.text.trim(),
            district: _district.text.trim(),
            pincode: _pincode.text.trim(),
            agentId: _agentId,
            joinDate: _joinDate,
            status: _status,
          ),
        );
      }

      if (!mounted) return;
      showToast(
        context,
        _isEdit ? 'सदस्य अपडेट किया गया' : 'सदस्य सफलतापूर्वक जोड़ा गया',
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
      icon: Icons.person_add_alt_1_rounded,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancelHi),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(S.submitHi),
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
              icon: Icons.badge_outlined,
              child: FormGrid(
                items: [
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
                      hint: 'जाति',
                      validator: V.required,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldGotra,
                      controller: _gotra,
                      hint: 'गोत्र',
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.fldWaris,
                      required: true,
                      controller: _waris,
                      hint: 'वारिसदार का नाम',
                      validator: V.required,
                    ),
                  ),
                  GridItem(
                    AppDropdown<String>(
                      label: S.fldWarisRelation,
                      required: true,
                      value: _relation,
                      items: _relations,
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
                      itemLabel: (g) => g.hi,
                      onChanged: (v) => setState(() => _gender = v ?? _gender),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            FormSection(
              title: S.contactInfo,
              icon: Icons.call_outlined,
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
                  GridItem(
                    AppTextField(
                      label: S.fldAadhaar,
                      required: true,
                      controller: _aadhaar,
                      hint: '1234 5678 9012',
                      prefixIcon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: Fmts.aadhaar(),
                      validator: V.aadhaar,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            FormSection(
              title: S.addressInfo,
              icon: Icons.location_on_outlined,
              child: FormGrid(
                items: [
                  GridItem(AppTextField(label: S.fldVillage, controller: _village)),
                  GridItem(AppTextField(label: S.fldTehsil, controller: _tehsil)),
                  GridItem(AppTextField(label: S.fldDistrict, controller: _district)),
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
              icon: Icons.assignment_ind_outlined,
              child: FormGrid(
                items: [
                  GridItem(
                    AppDropdown<Agent>(
                      label: S.fldAgent,
                      value: agents.where((a) => a.id == _agentId).firstOrNull,
                      items: agents.where((a) => a.isActive).toList(),
                      itemLabel: (a) => '${a.code} · ${a.name}',
                      includeAllOption: true,
                      allLabel: '— कोई नहीं —',
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
                      items: MemberStatus.values,
                      itemLabel: (s) => s.label,
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                ],
              ),
            ),
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
                prefixIcon: Icon(Icons.call_outlined, size: 18),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 42, minHeight: 40),
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
              label: const Text(S.searchHi),
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
                SizedBox(width: 150, height: 48, child: button),
              ],
            );
          },
        ),
      ],
    );
  }
}
