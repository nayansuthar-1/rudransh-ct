import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/member_lang.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primitives.dart';
import '../../widgets/stat_card.dart';
import 'member_pages.dart';
import 'member_widgets.dart';

/// Member landing page: their card, where they stand, shortcuts, and what is
/// new, so "do I owe anything?" is answered before they scroll.
class MemberHomePage extends StatelessWidget {
  const MemberHomePage({super.key});

  @override
  Widget build(BuildContext context) => const _PortalHome();
}

class _PortalHome extends ConsumerWidget {
  const _PortalHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final t = ref.watch(memberTextProvider);
    final async = ref.watch(myMembershipProvider);
    final m = async.value;
    final dues = ref.watch(myDuesProvider).value;
    final payments = ref.watch(myPaymentsProvider).value;
    final notices = ref.watch(announcementsProvider).value;
    final now = DateTime.now();

    return PageBody(
      maxWidth: 880,
      children: [
        SectionHeader(
          title: t.greeting(_firstName(m?.name ?? user.name), now.hour),
          subtitle: '${t.trustName} · ${Fmt.date(now)}',
        ),
        const SizedBox(height: Space.xl),
        if (m == null && async.hasError)
          AppCard(
            child: ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(myMembershipProvider),
            ),
          )
        else if (m == null)
          const AppCard(child: LoadingState(height: 200))
        else
          MemberIdCard(m),
        if (dues != null) ...[
          const SizedBox(height: Space.md),
          StandingBanner(dues),
        ],
        const SizedBox(height: Space.lg),
        QuickActions([
          QuickAction(
            Icons.event_note_outlined,
            t.navDues,
            StatAccent.amber,
            () => context.go(AppRoutes.memberDues),
          ),
          QuickAction(
            Icons.receipt_long_outlined,
            t.receipts,
            StatAccent.green,
            () => context.go(AppRoutes.memberPayments),
          ),
          QuickAction(
            Icons.workspace_premium_outlined,
            t.certificate,
            StatAccent.blue,
            m == null || m.regNo.isEmpty
                ? null
                : () => printMyCertificate(context, m, t),
          ),
          QuickAction(
            Icons.campaign_outlined,
            t.navAnnouncements,
            StatAccent.purple,
            () => context.go(AppRoutes.memberAnnouncements),
          ),
          QuickAction(
            Icons.edit_note_rounded,
            t.correction,
            StatAccent.teal,
            () => showCorrectionDialog(context),
          ),
        ]),
        if (m != null) ...[
          const SizedBox(height: Space.lg),
          _Stats(m, payments),
        ],
        if (notices != null && notices.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          MemberSectionTitle(
            t.latestNotice,
            seeAll: t.seeAll,
            onSeeAll: () => context.go(AppRoutes.memberAnnouncements),
          ),
          _NoticePreview(notices.first),
        ],
        if (payments != null && payments.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          MemberSectionTitle(
            t.recentPayments,
            seeAll: t.seeAll,
            onSeeAll: () => context.go(AppRoutes.memberPayments),
          ),
          AppCard(
            child: Column(
              children: [
                for (final (i, p) in payments.take(3).indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  MemberPaymentTile(p),
                ],
              ],
            ),
          ),
        ],
        if (m != null) ...[
          const SizedBox(height: Space.xl),
          _DetailsCard(m),
        ],
        const SizedBox(height: Space.md),
        const _CorrectionsCard(),
      ],
    );
  }

  static String _firstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? name : parts.first;
  }
}

/// Four coloured tiles: what they have given, their receipts, how long they
/// have been a member, and what each closing asks of them.
class _Stats extends ConsumerWidget {
  const _Stats(this.m, this.payments);

  final Membership m;
  final List<Payment>? payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(memberTextProvider);
    final approved = (payments ?? const <Payment>[]).where(isApproved);
    final total = approved.fold<double>(0, (s, p) => s + p.amount);

    return StatGrid(children: [
      CountUp(
        value: total,
        builder: (_, v) => StatCard(
          label: t.totalContributed,
          value: Fmt.money(v.round()),
          icon: Icons.volunteer_activism_outlined,
          accent: StatAccent.green,
          onTap: () => context.go(AppRoutes.memberPayments),
        ),
      ),
      StatCard(
        label: t.approvedReceipts,
        value: payments == null ? '—' : '${approved.length}',
        icon: Icons.receipt_long_outlined,
        accent: StatAccent.blue,
        onTap: () => context.go(AppRoutes.memberPayments),
      ),
      StatCard(
        label: t.memberFor,
        value: t.membershipAge(m.joinDate),
        icon: Icons.event_available_outlined,
        accent: StatAccent.purple,
      ),
      StatCard(
        label: t.perClosing,
        value: Fmt.money(m.contributionAmount),
        icon: Icons.handshake_outlined,
        accent: StatAccent.teal,
      ),
    ]);
  }
}

/// The newest notice, two lines of it; the full list is one tap away.
class _NoticePreview extends ConsumerWidget {
  const _NoticePreview(this.item);

  final Announcement item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = ref.watch(memberTextProvider);
    final fresh = DateTime.now().difference(item.publishedAt).inDays < 7;

    return AppCard(
      child: InkWell(
        onTap: () => context.go(AppRoutes.memberAnnouncements),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentBackground(context, StatAccent.purple),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  size: 20,
                  color: StatAccent.purple.color,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        if (fresh) ...[
                          const SizedBox(width: Space.sm),
                          StatusPill(t.newBadge, tone: PillTone.brand),
                        ],
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ],
                    const SizedBox(height: Space.xs),
                    Text(
                      Fmt.date(item.publishedAt),
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rest of what the office holds about the member.
class _DetailsCard extends ConsumerWidget {
  const _DetailsCard(this.m);

  final Membership m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final t = ref.watch(memberTextProvider);

    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.myDetails,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Space.sm),
          if (m.fatherOrHusbandName.isNotEmpty)
            DetailRow(label: t.fatherOrHusband, value: m.fatherOrHusbandName),
          DetailRow(label: t.phoneShort, value: Fmt.phone(m.primaryPhone)),
          DetailRow(label: t.address, value: m.address),
          DetailRow(
            label: t.nominee,
            value: m.warisRelation.isEmpty
                ? m.warisName
                : '${m.warisName} (${m.warisRelation})',
          ),
          if (m.agentName.isNotEmpty)
            DetailRow(label: t.yourAgent, value: m.agentName),
          DetailRow(
            label: t.contribution,
            value: Fmt.money(m.contributionAmount),
          ),
          if (m.regNo.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => printMyCertificate(context, m, t),
              icon: const Icon(Icons.print_outlined, size: 17),
              label: Text(t.printCertificate),
            ),
          ],
        ],
      ),
    );
  }
}

/// A section whose screens are not built yet.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.item});

  /// Path of the section, from [AgentRoutes.nav] or [MemberRoutes.nav].
  final String item;

  @override
  Widget build(BuildContext context) {
    final nav = [...AgentRoutes.nav, ...MemberRoutes.nav]
        .firstWhere((n) => n.path == item);
    return PageBody(
      maxWidth: 720,
      children: [
        SectionHeader(title: nav.label, subtitle: nav.sublabel),
        const SizedBox(height: Space.xl),
        AppCard(child: EmptyState(message: S.comingSoon, icon: nav.icon)),
      ],
    );
  }
}

/// Corrections the member has asked for, and the button to ask for one.
class _CorrectionsCard extends ConsumerWidget {
  const _CorrectionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final items = ref.watch(myChangeRequestsProvider).value ?? const [];
    final t = ref.watch(memberTextProvider);

    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap, not Row: the button and the heading do not fit side by side
          // at 390 px, and the button drops below instead of overflowing.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.md,
            children: [
              Text(
                t.myCorrections,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: () => showCorrectionDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(t.requestCorrection),
              ),
            ],
          ),
          if (items.isEmpty)
            Text(
              t.noCorrections,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            )
          else
            for (final r in items) ...[
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t.changeField(r.field)}: ${r.newValue}',
                      style: text.bodySmall,
                    ),
                  ),
                  StatusPill(
                    t.requestStatus(r.status),
                    tone: switch (r.status) {
                      RequestStatus.approved => PillTone.success,
                      RequestStatus.rejected => PillTone.danger,
                      RequestStatus.pending => PillTone.warning,
                    },
                  ),
                ],
              ),
              if (r.decisionNote.isNotEmpty)
                Text(
                  r.decisionNote,
                  style: text.bodySmall?.copyWith(color: c.danger),
                ),
            ],
        ],
      ),
    );
  }
}
