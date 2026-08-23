import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';
import '../../widgets/stat_card.dart';
import '../closing/closing_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stats = ref.watch(dashboardStatsProvider);
    final yojna = ref.watch(selectedYojnaProvider);
    final membersAsync = ref.watch(membersProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.dashboard,
          subtitle: yojna == null
              ? 'सभी योजनाओं का सारांश'
              : '${yojna.name} · ${S.dashboardSub}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _refreshAll(ref),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(S.refresh),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (membersAsync.isLoading && membersAsync.value == null)
          const LoadingState(height: 140)
        else
          StatGrid(
            children: [
              StatCard(
                label: S.totalMembers,
                value: Fmt.number(stats.totalMembers),
                icon: Icons.groups_rounded,
                tone: PillTone.brand,
                caption:
                    '${S.active}: ${stats.activeMembers} | ${S.inactive}: ${stats.inactiveMembers}',
                onTap: () => context.go(AppRoutes.members),
              ),
              StatCard(
                label: S.closingMembers,
                value: Fmt.number(stats.closedMembers),
                icon: Icons.check_circle_outline_rounded,
                tone: PillTone.success,
                caption: S.closedMembers,
                onTap: () => context.go(AppRoutes.closing),
              ),
              StatCard(
                label: S.totalAgents,
                value: Fmt.number(stats.totalAgents),
                icon: Icons.badge_outlined,
                tone: PillTone.info,
                caption: '${stats.activeAgents} ${S.active.toLowerCase()}',
                onTap: () => context.go(AppRoutes.agents),
              ),
              StatCard(
                label: S.monthCollection,
                value: Fmt.moneyCompact(stats.monthCollection),
                icon: Icons.account_balance_wallet_outlined,
                tone: PillTone.warning,
                delta: stats.collectionDelta,
                caption: Fmt.month(DateTime.now()),
                onTap: () => context.go(AppRoutes.payments),
              ),
            ],
          ),
        const SizedBox(height: 18),

        // ---- Closed cases ---------------------------------------------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: S.closedCases,
                leading: Icon(Icons.verified_outlined, size: 19, color: c.success),
                dense: true,
                actions: [
                  const PayStatusFilterButton(),
                  OutlinedButton.icon(
                    onPressed: () => _refreshAll(ref),
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text(S.refresh),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const ClosingCasesTable(
                pageSize: 6,
                emptyMessage: S.noClosedCases,
                showClaimColumn: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---- Split panels ---------------------------------------------
        _SplitRow(
          left: const _MembersByYojnaCard(),
          right: const _TopAgentsCard(),
        ),
        const SizedBox(height: 18),

        const _RecentPaymentsCard(),
      ],
    );
  }

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(membersProvider);
    ref.invalidate(agentsProvider);
    ref.invalidate(paymentsProvider);
    ref.invalidate(closingCasesProvider);
    ref.invalidate(yojnaListProvider);
  }
}

/// Two panels side by side on wide screens, stacked otherwise.
class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (context.screenWidth < Breakpoints.tablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 18), right],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: left),
          const SizedBox(width: 18),
          Expanded(flex: 2, child: right),
        ],
      ),
    );
  }
}

class _MembersByYojnaCard extends ConsumerWidget {
  const _MembersByYojnaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];
    final counts = ref.watch(membersPerYojnaProvider);
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: S.membersByYojna, dense: true),
          const SizedBox(height: 16),
          if (yojnas.isEmpty)
            const EmptyState(message: S.noResults, compact: true)
          else
            for (final y in yojnas) ...[
              _BarRow(
                label: y.name,
                value: counts[y.id] ?? 0,
                total: total == 0 ? 1 : total,
                color: c.brand,
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fraction = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${Fmt.number(value)}  ·  ${(fraction * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: c.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _TopAgentsCard extends ConsumerWidget {
  const _TopAgentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
    final collections = ref.watch(collectionByAgentProvider);
    final counts = ref.watch(memberCountByAgentProvider);

    final ranked = [...agents]..sort(
        (a, b) => (collections[b.id] ?? 0).compareTo(collections[a.id] ?? 0),
      );
    final top = ranked.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: S.topAgents,
            dense: true,
            actions: [
              TextButton(
                onPressed: () => context.go(AppRoutes.agents),
                child: const Text(S.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (top.isEmpty)
            const EmptyState(message: S.noResults, compact: true)
          else
            for (final a in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    AppAvatar(name: a.name, size: 34),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            '${a.code} · ${counts[a.id] ?? 0} ${S.membersCount.toLowerCase()}',
                            style: TextStyle(fontSize: 11.5, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Fmt.moneyCompact(collections[a.id] ?? 0),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentPaymentsCard extends ConsumerWidget {
  const _RecentPaymentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(scopedPaymentsProvider).take(6).toList();
    final members = ref.watch(memberByIdProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: S.recentPayments,
            dense: true,
            actions: [
              TextButton(
                onPressed: () => context.go(AppRoutes.payments),
                child: const Text(S.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ResponsiveTable<Payment>(
            paginate: false,
            rows: payments,
            emptyMessage: S.noResults,
            mobileTitle: (p) => members[p.memberId]?.name ?? '—',
            mobileSubtitle: (p) => p.receiptNo,
            columns: [
              TableCol<Payment>(
                label: S.memberName,
                flex: 2,
                minWidth: 170,
                text: (p) => members[p.memberId]?.name ?? '—',
                cell: (context, p) => Text(
                  members[p.memberId]?.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TableCol<Payment>(
                label: S.receiptNo,
                minWidth: 110,
                hideBelow: ScreenSize.laptop,
                text: (p) => p.receiptNo,
                cell: (context, p) =>
                    Text(p.receiptNo, style: const TextStyle(fontSize: 13)),
              ),
              TableCol<Payment>(
                label: S.date,
                minWidth: 110,
                text: (p) => Fmt.date(p.date),
                cell: (context, p) => Text(
                  Fmt.date(p.date),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TableCol<Payment>(
                label: S.mode,
                minWidth: 100,
                hideBelow: ScreenSize.laptop,
                text: (p) => p.mode.label,
                cell: (context, p) =>
                    Text(p.mode.label, style: const TextStyle(fontSize: 13)),
              ),
              TableCol<Payment>(
                label: S.status,
                minWidth: 100,
                cell: (context, p) => PaymentStatusPill(status: p.status),
              ),
              TableCol<Payment>(
                label: S.amount,
                minWidth: 110,
                numeric: true,
                text: (p) => Fmt.money(p.amount),
                cell: (context, p) => Text(
                  Fmt.money(p.amount),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared status pill for payments, reused by the payments page.
class PaymentStatusPill extends StatelessWidget {
  const PaymentStatusPill({super.key, required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      PaymentStatus.paid => PillTone.success,
      PaymentStatus.pending => PillTone.warning,
      PaymentStatus.failed => PillTone.danger,
    };
    return StatusPill(status.label, tone: tone);
  }
}
