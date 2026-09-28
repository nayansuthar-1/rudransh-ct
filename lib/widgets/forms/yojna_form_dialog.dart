import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';

Future<void> showYojnaFormDialog(BuildContext context, {Yojna? existing}) {
  return AppDialog.show<void>(
    context: context,
    builder: (_) => YojnaFormDialog(existing: existing),
  );
}

class YojnaFormDialog extends ConsumerStatefulWidget {
  const YojnaFormDialog({super.key, this.existing});

  final Yojna? existing;

  @override
  ConsumerState<YojnaFormDialog> createState() => _YojnaFormDialogState();
}

class _YojnaFormDialogState extends ConsumerState<YojnaFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _description;
  late final TextEditingController _shortName;
  late final TextEditingController _claim;
  late final TextEditingController _registration;

  /// Printed as योजना प्रारंभ on the membership certificate.
  DateTime? _startDate;
  late bool _isActive;
  late List<YojnaAgeSlab> _slabs;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final y = widget.existing;
    _name = TextEditingController(text: y?.name ?? '');
    _code = TextEditingController(text: y?.code ?? '');
    _description = TextEditingController(text: y?.description ?? '');
    _shortName = TextEditingController(text: y?.shortName ?? '');
    _claim = TextEditingController(
      text: y == null || y.claimAmount <= 0 ? '' : _num(y.claimAmount),
    );
    _registration = TextEditingController(
      text: y == null || y.registrationFee <= 0 ? '' : _num(y.registrationFee),
    );
    _startDate = y?.startDate;
    _isActive = y?.isActive ?? true;
    _slabs = [
      if (y != null && y.ageSlabs.isNotEmpty)
        ...y.ageSlabs
      else if (y != null)
        ...Yojna.defaultSlabsFor('${y.name} ${y.code}')
      else
        ...Yojna.defaultSlabsFor('SSY')
    ];
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _description,
      _shortName,
      _claim,
      _registration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final notifier = ref.read(yojnaListProvider.notifier);

    double parse(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

    try {
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.copyWith(
            name: _name.text.trim(),
            code: _code.text.trim().toUpperCase(),
            description: _description.text.trim(),
            shortName: _shortName.text.trim(),
            claimAmount: parse(_claim),
            registrationFee: parse(_registration),
            startDate: _startDate,
            clearStartDate: _startDate == null,
            isActive: _isActive,
            ageSlabs: _slabs,
          ),
        );
      } else {
        await notifier.add(
          Yojna(
            id: '',
            name: _name.text.trim(),
            code: _code.text.trim().toUpperCase(),
            description: _description.text.trim(),
            shortName: _shortName.text.trim(),
            claimAmount: parse(_claim),
            registrationFee: parse(_registration),
            startDate: _startDate,
            isActive: _isActive,
            createdAt: DateTime.now(),
            ageSlabs: _slabs,
          ),
        );
      }

      if (!mounted) return;
      showToast(context, _isEdit ? 'Yojna updated' : 'Yojna created');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: _isEdit ? 'Edit Yojna' : 'New Yojna',
      subtitle: _isEdit ? widget.existing!.code : 'Create a new scheme',
      maxWidth: 720,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const ButtonSpinner()
              : const Text(S.save),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormGrid(
              columnsOverride: MediaQuery.sizeOf(context).width < 680 ? 1 : 2,
              items: [
                GridItem(
                  AppTextField(
                    label: 'Yojna name',
                    required: true,
                    controller: _name,
                    hint: 'e.g. Suraksha Sahyog Yojna',
                    validator: V.required,
                    // Keeps the certificate preview below current.
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'Code',
                    required: true,
                    controller: _code,
                    hint: 'SSY',
                    validator: V.required,
                  ),
                ),
                GridItem.full(
                  AppTextField(
                    label: 'Description',
                    controller: _description,
                    maxLines: 2,
                    hint: 'Short description of the Yojna',
                  ),
                ),
                // प्रत्येक <this> सहयोग राशि on the membership certificate.
                GridItem(
                  AppTextField(
                    label: 'Name on certificate',
                    controller: _shortName,
                    hint: 'e.g. शादी — blank uses the Yojna name',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // योजना प्रारंभ on the membership certificate.
                GridItem(
                  AppDateField(
                    label: 'Scheme start date',
                    value: _startDate,
                    firstDate: DateTime(2020),
                    onChanged: (d) => setState(() => _startDate = d),
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'Claim amount (₹) (optional)',
                    controller: _claim,
                    hint: 'Leave blank / filled at claim time',
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.optionalAmount,
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'Base Registration fee (₹) (fallback)',
                    controller: _registration,
                    hint: 'e.g. 1100 if no age slab matches',
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.optionalAmount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CertificateLabelPreview(
              label: Yojna.certificateLabel(
                name: _name.text,
                shortName: _shortName.text,
              ),
            ),
            const SizedBox(height: 16),
            _buildAgeSlabsSection(context),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Active', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Only active schemes appear in the member form',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeSlabsSection(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Age Slabs (आयु अनुसार जुड़ने की फीस व सहयोग राशि)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Auto-fills joining fee & contribution in Member form from Date of Birth',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    final lastMax = _slabs.isNotEmpty ? _slabs.last.maxAge : 0;
                    _slabs.add(
                      YojnaAgeSlab(
                        minAge: lastMax > 0 ? lastMax + 1 : 0,
                        maxAge: lastMax > 0 ? lastMax + 5 : 5,
                        registrationFee: 0,
                        contributionAmount: 0,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add Slab'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.auto_fix_high, size: 14),
                label: const Text(
                  'Preset: Shadi Sahyog (शादी)',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () => setState(() {
                  _slabs = [
                    const YojnaAgeSlab(minAge: 0, maxAge: 5, registrationFee: 0, contributionAmount: 50),
                    const YojnaAgeSlab(minAge: 6, maxAge: 10, registrationFee: 1100, contributionAmount: 100),
                    const YojnaAgeSlab(minAge: 11, maxAge: 15, registrationFee: 1500, contributionAmount: 200),
                    const YojnaAgeSlab(minAge: 16, maxAge: 21, registrationFee: 2100, contributionAmount: 300),
                    const YojnaAgeSlab(minAge: 22, maxAge: 24, registrationFee: 3100, contributionAmount: 400),
                  ];
                }),
              ),
              ActionChip(
                avatar: const Icon(Icons.auto_fix_high, size: 14),
                label: const Text(
                  'Preset: Suraksha Sahyog (सुरक्षा)',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () => setState(() {
                  _slabs = [
                    const YojnaAgeSlab(minAge: 25, maxAge: 50, registrationFee: 1100, contributionAmount: 300),
                    const YojnaAgeSlab(minAge: 51, maxAge: 55, registrationFee: 1500, contributionAmount: 400),
                    const YojnaAgeSlab(minAge: 56, maxAge: 60, registrationFee: 2100, contributionAmount: 500),
                    const YojnaAgeSlab(minAge: 61, maxAge: 70, registrationFee: 3100, contributionAmount: 500),
                    const YojnaAgeSlab(minAge: 71, maxAge: 120, registrationFee: 3500, contributionAmount: 500, label: '70+ Joint'),
                  ];
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_slabs.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: c.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No custom slabs added. Standard slabs for this Yojna will apply automatically, or click a preset above.',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 120, child: Text('Age Range (आयु)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Reg. Fee (जुड़ने की फीस)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Contribution (सहयोग/किश्त)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  const SizedBox(width: 100, child: Text('Label (optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < _slabs.length; i++)
              _SlabRowEditor(
                key: ValueKey('slab_${i}_${_slabs[i].minAge}_${_slabs[i].maxAge}'),
                slab: _slabs[i],
                onChanged: (updated) => setState(() => _slabs[i] = updated),
                onDelete: () => setState(() => _slabs.removeAt(i)),
              ),
          ],
        ],
      ),
    );
  }
}

class _SlabRowEditor extends StatefulWidget {
  const _SlabRowEditor({
    super.key,
    required this.slab,
    required this.onChanged,
    required this.onDelete,
  });

  final YojnaAgeSlab slab;
  final ValueChanged<YojnaAgeSlab> onChanged;
  final VoidCallback onDelete;

  @override
  State<_SlabRowEditor> createState() => _SlabRowEditorState();
}

class _SlabRowEditorState extends State<_SlabRowEditor> {
  late final TextEditingController _minAge;
  late final TextEditingController _maxAge;
  late final TextEditingController _regFee;
  late final TextEditingController _contribution;
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    _minAge = TextEditingController(text: widget.slab.minAge.toString());
    _maxAge = TextEditingController(text: widget.slab.maxAge.toString());
    _regFee = TextEditingController(
      text: widget.slab.registrationFee == widget.slab.registrationFee.roundToDouble()
          ? widget.slab.registrationFee.toInt().toString()
          : widget.slab.registrationFee.toString(),
    );
    _contribution = TextEditingController(
      text: widget.slab.contributionAmount == widget.slab.contributionAmount.roundToDouble()
          ? widget.slab.contributionAmount.toInt().toString()
          : widget.slab.contributionAmount.toString(),
    );
    _label = TextEditingController(text: widget.slab.label);
  }

  @override
  void dispose() {
    _minAge.dispose();
    _maxAge.dispose();
    _regFee.dispose();
    _contribution.dispose();
    _label.dispose();
    super.dispose();
  }

  void _notify() {
    final min = int.tryParse(_minAge.text.trim()) ?? 0;
    final max = int.tryParse(_maxAge.text.trim()) ?? 100;
    final reg = double.tryParse(_regFee.text.replaceAll(',', '').trim()) ?? 0;
    final cont = double.tryParse(_contribution.text.replaceAll(',', '').trim()) ?? 0;
    widget.onChanged(
      widget.slab.copyWith(
        minAge: min,
        maxAge: max,
        registrationFee: reg,
        contributionAmount: cont,
        label: _label.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAge,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'Min',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('–', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxAge,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'Max',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _regFee,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => _notify(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _contribution,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => _notify(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _label,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: 'e.g. 70+',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => _notify(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
}

/// How the certificate's सहयोग राशि label will read, so the office sees the
/// Hindi a Hinglish name turns into and can fix it in "Name on certificate".
class _CertificateLabelPreview extends StatelessWidget {
  const _CertificateLabelPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Prints on the certificate as:  ',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
            TextSpan(
              text: '$label: ₹ ___',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
