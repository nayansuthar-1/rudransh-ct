import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
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
    final statsAsync = ref.watch(dashboardStatsProvider);
    final stats = statsAsync.value ?? DashboardStats.empty;
    final yojna = ref.watch(selectedYojnaProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.dashboard,
          subtitle: yojna == null ? 'Summary across all Yojnas' : yojna.name,
          actions: [
            OutlinedButton.icon(
              onPressed: () => _refreshAll(ref),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(S.refresh),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),

        if (statsAsync.isLoading && statsAsync.value == null)
          const AppCard(child: LoadingState(height: 104))
        else if (statsAsync.hasError && statsAsync.value == null)
          AppCard(
            child: ErrorStateView(
              error: statsAsync.error!,
              onRetry: () => ref.invalidate(dashboardStatsProvider),
            ),
          )
        else
          StatGrid(
            children: [
              StatCard(
                label: S.totalMembers,
                value: Fmt.number(stats.totalMembers),
                icon: Icons.groups_outlined,
                accent: StatAccent.blue,
                caption:
                    '${Fmt.number(stats.activeMembers)} active · ${Fmt.number(stats.inactiveMembers)} inactive',
                onTap: () => context.go(AppRoutes.members),
              ),
              StatCard(
                label: S.closingMembers,
                value: Fmt.number(stats.closedMembers),
                icon: Icons.assignment_turned_in_outlined,
                accent: StatAccent.purple,
                caption: S.closedMembers,
                onTap: () => context.go(AppRoutes.closing),
              ),
              StatCard(
                label: S.totalAgents,
                value: Fmt.number(stats.totalAgents),
                icon: Icons.badge_outlined,
                accent: StatAccent.teal,
                caption: '${Fmt.number(stats.activeAgents)} active',
                onTap: () => context.go(AppRoutes.agents),
              ),
              StatCard(
                label: S.monthCollection,
                value: Fmt.moneyCompact(stats.monthCollection),
                icon: Icons.currency_rupee_rounded,
                accent: StatAccent.green,
                delta: stats.collectionDelta,
                caption: Fmt.month(DateTime.now()),
                onTap: () => context.go(AppRoutes.payments),
              ),
            ],
          ),
        const SizedBox(height: Space.xxl),

        // ---- Closed cases ---------------------------------------------
        const SectionHeader(
          title: S.closedCases,
          dense: true,
          actions: [PayStatusFilterButton()],
        ),
        const SizedBox(height: Space.md),
        const AppCard(
          child: ClosingCasesTable(
            pageSize: 6,
            emptyMessage: S.noClosedCases,
            showClaimColumn: false,
          ),
        ),
        const SizedBox(height: Space.xxl),

        // ---- Split panels ---------------------------------------------
        const _SplitRow(
          left: _MembersByYojnaSection(),
          right: _TopAgentsSection(),
        ),
        const SizedBox(height: Space.xxl),

        const _RecentPaymentsSection(),
      ],
    );
  }

  void _refreshAll(WidgetRef ref) {
    // Reloads every server-backed view (stats, pages, totals).
    ref.read(dataRevisionProvider.notifier).bump();
    ref.invalidate(agentsProvider);
    ref.invalidate(closingCasesProvider);
    ref.invalidate(yojnaListProvider);
  }
}

/// Two sections side by side on wide screens, stacked otherwise.
class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (context.screenWidth < Breakpoints.tablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: Space.xxl), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 24),
        Expanded(child: right),
      ],
    );
  }
}

class _MembersByYojnaSection extends ConsumerWidget {
  const _MembersByYojnaSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];
    final counts =
        ref.watch(membersPerYojnaProvider).value ?? const <String, int>{};
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Height matches a header with a text button, so both columns align.
        const SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SectionHeader(title: S.membersByYojna, dense: true),
          ),
        ),
        const SizedBox(height: Space.md),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: yojnas.isEmpty
              ? const EmptyState(message: S.noResults, compact: true)
              : Column(
                  children: [
                    for (var i = 0; i < yojnas.length; i++)
                      _BarRow(
                        label: yojnas[i].name,
                        value: counts[yojnas[i].id] ?? 0,
                        total: total,
                        divider: i < yojnas.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.divider,
  });

  final String label;
  final int value;
  final int total;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fraction = total == 0 ? 0.0 : value / total;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.border)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Fmt.number(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    fontFeatures: kTabular,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(fraction * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
                      fontFeatures: kTabular,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: c.brandSoft.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation(c.brand),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopAgentsSection extends ConsumerWidget {
  const _TopAgentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
    final collections =
        ref.watch(collectionByAgentProvider).value ?? const <String, double>{};
    final counts =
        ref.watch(memberCountByAgentProvider).value ?? const <String, int>{};

    final ranked = [...agents]..sort(
        (a, b) => (collections[b.id] ?? 0).compareTo(collections[a.id] ?? 0),
      );
    final top = ranked.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: SectionHeader(
            title: S.topAgents,
            dense: true,
            actions: [
              TextButton(
                onPressed: () => context.go(AppRoutes.agents),
                child: const Text(S.viewAll),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: top.isEmpty
              ? const EmptyState(message: S.noResults, compact: true)
              : Column(
                  children: [
                    for (var i = 0; i < top.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          border: i == top.length - 1
                              ? null
                              : Border(bottom: BorderSide(color: c.border)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textMuted,
                                  fontFeatures: kTabular,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    top[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${top[i].code} · ${counts[top[i].id] ?? 0} ${S.membersCount.toLowerCase()}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Fmt.moneyCompact(collections[top[i].id] ?? 0),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                                fontFeatures: kTabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecentPaymentsSection extends ConsumerWidget {
  const _RecentPaymentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(recentPaymentsProvider).value ?? PaymentPage.empty;
    final payments = page.items;
    final members = page.members;

    return Column(
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
        const SizedBox(height: Space.md),
        AppCard(
          child: ResponsiveTable<Payment>(
            paginate: false,
            rows: payments,
            emptyMessage: S.noResults,
            mobileTitle: (p) => members[p.memberId]?.name ?? '—',
            mobileSubtitle: (p) => '${p.receiptNo} · ${Fmt.date(p.date)}',
            mobileTrailing: (context, p) => Text(
              Fmt.money(p.amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
                fontFeatures: kTabular,
              ),
            ),
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
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              TableCol<Payment>(
                label: S.receiptNo,
                minWidth: 110,
                hideBelow: ScreenSize.laptop,
                showOnMobile: false,
                text: (p) => p.receiptNo,
                cell: (context, p) => Text(p.receiptNo),
              ),
              TableCol<Payment>(
                label: S.date,
                minWidth: 110,
                showOnMobile: false,
                text: (p) => Fmt.date(p.date),
                cell: (context, p) => Text(Fmt.date(p.date)),
              ),
              TableCol<Payment>(
                label: S.mode,
                minWidth: 100,
                hideBelow: ScreenSize.laptop,
                text: (p) => p.mode.label,
                cell: (context, p) => Text(p.mode.label),
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
                showOnMobile: false,
                text: (p) => Fmt.money(p.amount),
                cell: (context, p) => Text(
                  Fmt.money(p.amount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
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
