import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

/// What agents submitted and an admin must decide on
/// (IMPLEMENTATION_PLAN Phase 12).
class ApprovalsPage extends ConsumerWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalQueueProvider);
    final queue = async.value;

    return PageBody(
      maxWidth: 960,
      children: [
        const SectionHeader(title: S.approvals, subtitle: S.approvalsSub),
        const SizedBox(height: Space.xl),
        if (queue == null && async.hasError)
          AppCard(
            child: ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(approvalQueueProvider),
            ),
          )
        else if (queue == null)
          const AppCard(child: LoadingState())
        else if (queue.count == 0)
          const AppCard(
            child: EmptyState(
              message: S.nothingToApprove,
              icon: Icons.task_alt_rounded,
            ),
          )
        else ...[
          _Section(
            title: S.newMembers,
            children: [
              for (final m in queue.members) _MemberRow(member: m),
            ],
          ),
          _Section(
            title: S.paymentsToApprove,
            children: [
              for (final p in queue.payments.items)
                _PaymentRow(
                  payment: p,
                  member: queue.payments.members[p.memberId],
                ),
            ],
          ),
          _Section(
            title: S.deathReports,
            children: [
              for (final r in queue.deathReports) _DeathReportRow(report: r),
            ],
          ),
          _Section(
            title: S.cancelRequests,
            children: [
              for (final p in queue.cancelRequests.items)
                _CancelRequestRow(
                  payment: p,
                  member: queue.cancelRequests.members[p.memberId],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: '$title (${children.length})', dense: true),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title, detail lines and action buttons; buttons wrap below on phones.
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.title,
    required this.lines,
    required this.actions,
  });

  final String title;
  final List<String> lines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.lg,
        runSpacing: Space.md,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                for (final line in lines.where((l) => l.trim().isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Wrap(spacing: Space.sm, runSpacing: Space.sm, children: actions),
        ],
      ),
    );
  }
}

String _agentLine(WidgetRef ref, String? agentId) {
  final agent = ref.watch(agentByIdProvider)[agentId];
  return agent == null ? '' : 'Agent: ${agent.name} (${agent.code})';
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = member;
    final yojna = ref.watch(yojnaByIdProvider)[m.yojnaId];
    final actions = ref.read(approvalActionsProvider);

    return _QueueRow(
      title: m.name,
      lines: [
        [yojna?.name ?? '', Fmt.phone(m.primaryPhone), m.address]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        [
          if (m.fatherOrHusbandName.isNotEmpty)
            'Father/husband: ${m.fatherOrHusbandName}',
          if (m.warisName.isNotEmpty)
            'Nominee: ${m.warisName} (${m.warisRelation})',
        ].join(' · '),
        [_agentLine(ref, m.agentId), 'Joined ${Fmt.date(m.joinDate)}']
            .where((s) => s.isNotEmpty)
            .join(' · '),
      ],
      actions: [
        OutlinedButton(
          onPressed: () async {
            final reason = await reasonDialog(
              context,
              title: 'Reject ${m.name}?',
              message: 'The member stays on record as Inactive, without a '
                  'registration number. Their pending payments are rejected.',
            );
            if (reason == null || !context.mounted) return;
            await runWithToast(
              context,
              () => actions.rejectMember(m.id, reason),
              success: 'Member rejected',
            );
          },
          child: const Text(S.reject),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final regNo = await actions.approveMember(m.id);
              if (context.mounted) showToast(context, 'Approved · $regNo');
            } catch (e) {
              if (context.mounted) showToast(context, '$e', error: true);
            }
          },
          child: const Text(S.approve),
        ),
      ],
    );
  }
}

String _paymentTitle(Payment p) =>
    '${p.receiptNo} · ${Fmt.money(p.amount)} · ${p.mode.label}'
    '${p.reference.isEmpty ? '' : ' (${p.reference})'}';

String _memberLine(Payment p, MemberRef? member) => [
      member?.name ?? '',
      member?.regNo ?? '',
      p.kind.label,
      Fmt.date(p.date),
    ].where((s) => s.isNotEmpty).join(' · ');

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow({required this.payment, required this.member});

  final Payment payment;
  final MemberRef? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    final actions = ref.read(approvalActionsProvider);

    return _QueueRow(
      title: _paymentTitle(p),
      lines: [
        _memberLine(p, member),
        _agentLine(ref, p.agentId),
        if (p.note.isNotEmpty) 'Note: ${p.note}',
      ],
      actions: [
        OutlinedButton(
          onPressed: () async {
            final reason = await reasonDialog(
              context,
              title: 'Reject ${p.receiptNo}?',
              message: 'It stays on record as Failed and never counts in '
                  'totals. The agent sees your reason.',
            );
            if (reason == null || !context.mounted) return;
            await runWithToast(
              context,
              () => actions.rejectPayment(p.id, reason),
              success: 'Payment rejected',
            );
          },
          child: const Text(S.reject),
        ),
        FilledButton(
          onPressed: () => runWithToast(
            context,
            () => actions.approvePayment(p.id),
            success: 'Payment approved',
          ),
          child: const Text(S.approve),
        ),
      ],
    );
  }
}

class _CancelRequestRow extends ConsumerWidget {
  const _CancelRequestRow({required this.payment, required this.member});

  final Payment payment;
  final MemberRef? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final p = payment;
    final actions = ref.read(approvalActionsProvider);
    final isOwner = ref.watch(currentUserProvider).isOwner;

    return _QueueRow(
      title: _paymentTitle(p),
      lines: [
        _memberLine(p, member),
        [_agentLine(ref, p.agentId), p.status.label]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        'Reason: ${p.cancelRequestReason}',
      ],
      actions: [
        OutlinedButton(
          onPressed: () => runWithToast(
            context,
            () => actions.declineCancelRequest(p.id),
            success: 'Request declined',
          ),
          child: const Text(S.decline),
        ),
        if (isOwner)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = await reasonDialog(
                context,
                title: '${S.cancelReceipt} ${p.receiptNo}?',
                message: 'The receipt stays on record but leaves every total.',
                confirmLabel: S.cancelReceipt,
              );
              if (reason == null || !context.mounted) return;
              await runWithToast(
                context,
                () => actions.cancelPayment(p.id, reason),
                success: 'Receipt cancelled',
              );
            },
            child: const Text(S.cancelReceipt),
          ),
      ],
    );
  }
}

class _DeathReportRow extends ConsumerWidget {
  const _DeathReportRow({required this.report});

  final ClosingRequest report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = report;
    final yojna = ref.watch(yojnaByIdProvider)[r.yojnaId];
    final actions = ref.read(approvalActionsProvider);

    return _QueueRow(
      title: [r.memberName, r.memberRegNo].where((s) => s.isNotEmpty).join(' · '),
      lines: [
        [yojna?.name ?? '', '${S.dateOfDeath}: ${Fmt.date(r.dateOfDeath)}']
            .where((s) => s.isNotEmpty)
            .join(' · '),
        if (r.nomineeName.isNotEmpty)
          'Nominee: ${r.nomineeName}'
              '${r.nomineeRelation.isEmpty ? '' : ' (${r.nomineeRelation})'}',
        _agentLine(ref, r.agentId),
        if (r.remarks.isNotEmpty) 'Remarks: ${r.remarks}',
      ],
      actions: [
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(r.certificateUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text(S.deathCertificate),
        ),
        OutlinedButton(
          onPressed: () async {
            final reason = await reasonDialog(
              context,
              title: 'Reject the report for ${r.memberName}?',
              message: 'The member stays active. The agent sees your reason.',
            );
            if (reason == null || !context.mounted) return;
            await runWithToast(
              context,
              () => actions.rejectDeathReport(r.id, reason),
              success: 'Report rejected',
            );
          },
          child: const Text(S.reject),
        ),
        FilledButton(
          onPressed: () => AppDialog.show<void>(
            context: context,
            builder: (_) => _CreateClosingDialog(report: r),
          ),
          child: const Text(S.createClosing),
        ),
      ],
    );
  }
}

/// Approves a death report: asks for the closing group and claim amount.
class _CreateClosingDialog extends ConsumerStatefulWidget {
  const _CreateClosingDialog({required this.report});

  final ClosingRequest report;

  @override
  ConsumerState<_CreateClosingDialog> createState() =>
      _CreateClosingDialogState();
}

class _CreateClosingDialogState extends ConsumerState<_CreateClosingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _group;
  late final TextEditingController _claim;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    // Suggest the newest group in the same Yojna.
    final cases = (ref.read(closingCasesProvider).value ?? const <ClosingCase>[])
        .where((c) => c.yojnaId == r.yojnaId && c.closingGroup.isNotEmpty)
        .toList()
      ..sort((a, b) => b.closingDate.compareTo(a.closingDate));
    _group = TextEditingController(text: cases.firstOrNull?.closingGroup ?? '');
    final claim = ref.read(yojnaByIdProvider)[r.yojnaId]?.claimAmount;
    _claim = TextEditingController(
      text: claim == null ? '' : claim.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _group.dispose();
    _claim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(approvalActionsProvider).approveDeathReport(
            widget.report.id,
            closingGroup: _group.text.trim(),
            claimAmount: double.tryParse(_claim.text.replaceAll(',', '').trim()),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, 'Closing created for ${widget.report.memberName}');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return AppDialog(
      title: S.createClosing,
      subtitle: '${r.memberName} · ${S.dateOfDeath} ${Fmt.date(r.dateOfDeath)}',
      maxWidth: 560,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const ButtonSpinner() : const Text(S.createClosing),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The member is marked Closed. Every active member of the Yojna '
              'who joined before this date owes a contribution for the group.',
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
            const SizedBox(height: Space.lg),
            FormGrid(
              columnsOverride: MediaQuery.sizeOf(context).width < 680 ? 1 : 2,
              items: [
                GridItem(AppTextField(
                  label: S.closingGroup,
                  controller: _group,
                  required: true,
                  hint: 'Group-14',
                  validator: V.required,
                )),
                GridItem(AppTextField(
                  label: '${S.claimAmount} (₹)',
                  controller: _claim,
                  required: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: Fmts.amount(),
                  validator: V.required,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

