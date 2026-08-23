import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';

class ClosingPayStatusPill extends StatelessWidget {
  const ClosingPayStatusPill({super.key, required this.status});

  final ClosingPayStatus status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (status) {
      ClosingPayStatus.paid => (PillTone.success, Icons.check_circle_outline),
      ClosingPayStatus.partial => (PillTone.warning, Icons.timelapse_rounded),
      ClosingPayStatus.unpaid => (PillTone.danger, Icons.pending_outlined),
    };
    return StatusPill(status.label, tone: tone, icon: icon);
  }
}

/// Popup that filters closed cases by settlement status.
class PayStatusFilterButton extends ConsumerWidget {
  const PayStatusFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(closingFilterProvider);

    return PopupMenuButton<ClosingPayStatus?>(
      tooltip: S.payStatus,
      position: PopupMenuPosition.under,
      onSelected: (value) =>
          ref.read(closingFilterProvider.notifier).set(value),
      itemBuilder: (context) => [
        const PopupMenuItem<ClosingPayStatus?>(value: null, child: Text(S.all)),
        for (final s in ClosingPayStatus.values)
          PopupMenuItem<ClosingPayStatus?>(value: s, child: Text(s.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected == null ? c.surface : c.brandSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected == null ? c.borderStrong : c.brand,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_outlined, size: 15, color: c.textSecondary),
            const SizedBox(width: 6),
            Text(
              selected?.label ?? S.payStatus,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected == null ? c.textPrimary : c.brand,
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// The "Closed Cases" table, shared by the dashboard and the closing page.
class ClosingCasesTable extends ConsumerWidget {
  const ClosingCasesTable({
    super.key,
    this.pageSize = 12,
    this.emptyMessage = S.noClosedCases,
    this.showClaimColumn = true,
  });

  final int pageSize;
  final String emptyMessage;
  final bool showClaimColumn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(filteredClosingCasesProvider);
    final members = ref.watch(memberByIdProvider);
    final yojnas = ref.watch(yojnaByIdProvider);
    final async = ref.watch(closingCasesProvider);

    if (async.isLoading && async.value == null) {
      return const LoadingState(height: 180);
    }
    if (async.hasError && async.value == null) {
      return ErrorStateView(
        error: async.error!,
        onRetry: () => ref.invalidate(closingCasesProvider),
      );
    }

    String memberName(ClosingCase c) => members[c.memberId]?.name ?? '—';
    String regNo(ClosingCase c) => members[c.memberId]?.regNo ?? '—';

    return ResponsiveTable<ClosingCase>(
      rows: cases,
      pageSize: pageSize,
      emptyMessage: emptyMessage,
      emptyIcon: Icons.assignment_turned_in_outlined,
      mobileTitle: memberName,
      mobileSubtitle: (c) => regNo(c),
      mobileLeading: (context, c) => AppAvatar(name: memberName(c), size: 36),
      columns: [
        TableCol<ClosingCase>(
          label: S.memberName,
          flex: 2,
          minWidth: 180,
          text: memberName,
          cell: (context, item) => Row(
            children: [
              if (!context.isMobile) ...[
                AppAvatar(name: memberName(item), size: 30),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  memberName(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        TableCol<ClosingCase>(
          label: S.regNo,
          minWidth: 130,
          text: regNo,
          cell: (context, item) => Text(
            regNo(item),
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ),
        TableCol<ClosingCase>(
          label: S.scheme,
          minWidth: 160,
          hideBelow: ScreenSize.desktop,
          text: (item) => yojnas[item.yojnaId]?.name ?? '—',
          cell: (context, item) => Text(
            yojnas[item.yojnaId]?.name ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        TableCol<ClosingCase>(
          label: S.closingDate,
          minWidth: 120,
          text: (item) => Fmt.date(item.closingDate),
          cell: (context, item) => Text(
            Fmt.date(item.closingDate),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        TableCol<ClosingCase>(
          label: S.closingGroup,
          minWidth: 120,
          text: (item) => item.closingGroup,
          cell: (context, item) =>
              StatusPill(item.closingGroup, tone: PillTone.neutral),
        ),
        if (showClaimColumn)
          TableCol<ClosingCase>(
            label: S.claimAmount,
            minWidth: 150,
            hideBelow: ScreenSize.laptop,
            text: (item) => Fmt.money(item.claimAmount),
            cell: (context, item) => _ClaimProgress(item: item),
          ),
        TableCol<ClosingCase>(
          label: S.payStatus,
          minWidth: 110,
          cell: (context, item) => ClosingPayStatusPill(status: item.payStatus),
        ),
      ],
      rowActions: (context, item) => _CaseActions(item: item),
    );
  }
}

class _ClaimProgress extends StatelessWidget {
  const _ClaimProgress({required this.item});

  final ClosingCase item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Fmt.money(item.claimAmount),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: item.progress,
            minHeight: 5,
            backgroundColor: c.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(
              item.progress >= 1 ? c.success : c.brand,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${Fmt.moneyCompact(item.collectedAmount)} collected',
          style: TextStyle(fontSize: 10.5, color: c.textMuted),
        ),
      ],
    );
  }
}

class _CaseActions extends ConsumerWidget {
  const _CaseActions({required this.item});

  final ClosingCase item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.payStatus != ClosingPayStatus.paid)
          IconButton(
            tooltip: S.markPaid,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await ref
                  .read(closingCasesProvider.notifier)
                  .setPayStatus(item, ClosingPayStatus.paid);
              if (context.mounted) showToast(context, 'Marked as paid');
            },
            icon: Icon(Icons.check_circle_outline, size: 18, color: c.success),
          ),
        PopupMenuButton<int>(
          tooltip: S.actions,
          position: PopupMenuPosition.under,
          icon: const Icon(Icons.more_horiz, size: 19),
          onSelected: (value) async {
            switch (value) {
              case 0:
                _showCaseDetails(context, ref, item);
              case 1:
                await ref
                    .read(closingCasesProvider.notifier)
                    .setPayStatus(item, ClosingPayStatus.unpaid);
              case 2:
                final ok = await confirmDialog(context);
                if (!ok) return;
                await ref.read(closingCasesProvider.notifier).remove(item.id);
                if (context.mounted) showToast(context, 'Closing case removed');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 0, child: Text(S.view)),
            if (item.payStatus == ClosingPayStatus.paid)
              const PopupMenuItem(value: 1, child: Text('Mark unpaid')),
            PopupMenuItem(
              value: 2,
              child: Text(S.delete, style: TextStyle(color: c.danger)),
            ),
          ],
        ),
      ],
    );
  }
}

void _showCaseDetails(BuildContext context, WidgetRef ref, ClosingCase item) {
  final member = ref.read(memberByIdProvider)[item.memberId];
  final yojna = ref.read(yojnaByIdProvider)[item.yojnaId];

  AppDialog.show<void>(
    context: context,
    builder: (_) => AppDialog(
      title: member?.name ?? 'Closing case',
      subtitle: member?.regNo,
      icon: Icons.assignment_turned_in_outlined,
      maxWidth: 560,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(label: S.scheme, value: yojna?.name ?? '—'),
          DetailRow(label: S.closingDate, value: Fmt.date(item.closingDate)),
          DetailRow(label: S.closingGroup, value: item.closingGroup),
          DetailRow(label: 'Nominee (वारिसदार)', value: item.nomineeName),
          DetailRow(label: S.claimAmount, value: Fmt.money(item.claimAmount)),
          DetailRow(
            label: 'Collected',
            value: Fmt.money(item.collectedAmount),
          ),
          DetailRow(label: 'Pending', value: Fmt.money(item.pendingAmount)),
          DetailRow(label: S.payStatus, value: item.payStatus.label),
          if (member != null) ...[
            const SizedBox(height: 8),
            DetailRow(label: S.phone, value: Fmt.phone(member.primaryPhone)),
            DetailRow(label: 'पता', value: member.address),
          ],
        ],
      ),
    ),
  );
}
