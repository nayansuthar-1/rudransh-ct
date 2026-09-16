import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/forms/payment_form_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/stat_card.dart';
import 'closing_widgets.dart';

class ClosingPaymentsPage extends ConsumerWidget {
  const ClosingPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(scopedClosingCasesProvider);
    final yojna = ref.watch(selectedYojnaProvider);

    final totalClaim = cases.sumOf((c) => c.claimAmount);
    final collected = cases.sumOf((c) => c.collectedAmount);
    final pending = cases.sumOf((c) => c.pendingAmount);
    final unpaid =
        cases.where((c) => c.payStatus != ClosingPayStatus.paid).length;

    return PageBody(
      children: [
        SectionHeader(
          title: S.closingPayments,
          subtitle: yojna?.name ?? S.allYojnas,
          actions: [
            FilledButton.icon(
              onPressed: () => showClosingCaseDialog(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('New closing'),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        StatGrid(
          children: [
            StatCard(
              label: 'Total claims',
              value: Fmt.moneyCompact(totalClaim),
              icon: Icons.assignment_outlined,
              accent: StatAccent.blue,
              caption: '${cases.length} cases',
            ),
            StatCard(
              label: 'Collected',
              value: Fmt.moneyCompact(collected),
              icon: Icons.savings_outlined,
              accent: StatAccent.green,
              caption: totalClaim == 0
                  ? null
                  : '${(collected / totalClaim * 100).toStringAsFixed(0)}% of claims',
            ),
            StatCard(
              label: 'Pending',
              value: Fmt.moneyCompact(pending),
              icon: Icons.hourglass_bottom_rounded,
              accent: StatAccent.amber,
              caption: '$unpaid unsettled',
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        const SectionHeader(
          title: S.closedCases,
          dense: true,
          actions: [PayStatusFilterButton()],
        ),
        const SizedBox(height: Space.md),
        const AppCard(child: ClosingCasesTable()),
      ],
    );
  }
}

/// Raises a new closing case against an existing member.
Future<void> showClosingCaseDialog(BuildContext context) {
  return AppDialog.show<void>(
    context: context,
    builder: (_) => const _ClosingCaseDialog(),
  );
}

class _ClosingCaseDialog extends ConsumerStatefulWidget {
  const _ClosingCaseDialog();

  @override
  ConsumerState<_ClosingCaseDialog> createState() => _ClosingCaseDialogState();
}

class _ClosingCaseDialogState extends ConsumerState<_ClosingCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _group = TextEditingController(text: 'Group-1');
  final _claim = TextEditingController();
  final _remarks = TextEditingController();

  Member? _member;
  DateTime _closingDate = DateTime.now();
  ClosingPayStatus _status = ClosingPayStatus.unpaid;
  bool _saving = false;

  @override
  void dispose() {
    _group.dispose();
    _claim.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _pickMember(Member member) {
    final yojna = ref.read(yojnaByIdProvider)[member.yojnaId];
    setState(() {
      _member = member;
      if (_claim.text.trim().isEmpty && yojna != null) {
        _claim.text = yojna.claimAmount.toStringAsFixed(0);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final member = _member;
    if (member == null) {
      showToast(context, 'Select a member', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(closingCasesProvider.notifier).add(
            ClosingCase(
              id: '',
              memberId: member.id,
              yojnaId: member.yojnaId,
              closingDate: _closingDate,
              closingGroup: _group.text.trim(),
              claimAmount:
                  double.tryParse(_claim.text.replaceAll(',', '').trim()) ?? 0,
              payStatus: _status,
              nomineeName: member.warisName,
              remarks: _remarks.text.trim(),
            ),
          );
      if (!mounted) return;
      showToast(context, 'Closing case created');
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

    return AppDialog(
      title: 'New Closing Case',
      subtitle: 'Raise a claim for a member',
      maxWidth: 640,
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
            MemberPickerField(
              search: (text) => ref
                  .read(memberActionsProvider)
                  .search(text, excludeClosed: true),
              selected: _member,
              onSelected: _pickMember,
              onCleared: () => setState(() => _member = null),
            ),
            if (_member != null) ...[
              const SizedBox(height: 8),
              Text(
                'Nominee: ${_member!.warisName} (${_member!.warisRelation})',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ],
            const SizedBox(height: 18),
            FormGrid(
              columnsOverride: MediaQuery.sizeOf(context).width < 680 ? 1 : 2,
              items: [
                GridItem(
                  AppDateField(
                    label: S.closingDate,
                    required: true,
                    value: _closingDate,
                    onChanged: (d) => setState(() => _closingDate = d),
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: S.closingGroup,
                    required: true,
                    controller: _group,
                    hint: 'Group-14',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? S.required : null,
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: '${S.claimAmount} (₹)',
                    required: true,
                    controller: _claim,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? S.required : null,
                  ),
                ),
                GridItem(
                  AppDropdown<ClosingPayStatus>(
                    label: S.payStatus,
                    value: _status,
                    items: ClosingPayStatus.values,
                    itemLabel: (s) => s.label,
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ),
                GridItem.full(
                  AppTextField(
                    label: 'Remarks',
                    controller: _remarks,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
