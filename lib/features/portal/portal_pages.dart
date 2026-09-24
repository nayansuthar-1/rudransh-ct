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
import '../certificate/certificate_action.dart';
import '../certificate/certificate_data.dart';
import 'member_pages.dart';

/// Member landing page. Dues, receipts and announcements arrive in Phase 15.
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
    final isMember = user.role == UserRole.member;
    final t = ref.watch(memberTextProvider);
    // Members read their screens in the language they chose; agents in English.
    final sections = [
      for (final item in user.role.nav.skip(1)) isMember ? t.nav(item) : item,
    ];

    return PageBody(
      maxWidth: 720,
      children: [
        SectionHeader(
          title: isMember ? t.namaste(user.name) : 'Namaste, ${user.name}',
          subtitle: isMember
              ? '${t.trustName} · ${t.member}'
              : '${S.trustName} · ${user.role.label}',
        ),
        const SizedBox(height: Space.xl),
        if (isMember) ...[
          const _MembershipCard(),
          const SizedBox(height: Space.md),
          const _CorrectionsCard(),
          const SizedBox(height: Space.md),
        ],
        AppCard(
          child: Column(
            children: [
              for (final (i, item) in sections.indexed) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                ListTile(
                  leading: Icon(item.icon, color: c.brand),
                  title: Text(item.label),
                  subtitle: Text(item.sublabel),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(item.path),
                ),
              ],
            ],
          ),
        ),
      ],
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

/// The member's own record, with the details the office holds.
class _MembershipCard extends ConsumerWidget {
  const _MembershipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMembershipProvider);
    final m = async.value;

    if (m == null && async.hasError) {
      return AppCard(
        child: ErrorStateView(
          error: async.error!,
          onRetry: () => ref.invalidate(myMembershipProvider),
        ),
      );
    }
    if (m == null) return const AppCard(child: LoadingState(height: 120));

    final text = Theme.of(context).textTheme;
    final t = ref.watch(memberTextProvider);
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.myMembership,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                t.memberStatus(m.status),
                tone: m.status == MemberStatus.active
                    ? PillTone.success
                    : PillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          DetailRow(label: t.regNo, value: m.regNo),
          DetailRow(label: t.yojna, value: m.yojnaName),
          DetailRow(label: t.contribution, value: Fmt.money(m.contributionAmount)),
          DetailRow(label: t.memberSince, value: Fmt.date(m.joinDate)),
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
          if (m.regNo.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () {
                final member = m.toMember();
                printCertificateData(
                  context,
                  CertificateData(
                    regNo: member.regNo,
                    issuedOn: DateTime.now(),
                    name: member.name,
                    fatherOrHusbandName: member.fatherOrHusbandName,
                    yojnaName: m.yojnaName,
                    yojnaStartedOn: m.yojnaStartedOn,
                    contributionAmount: m.contributionAmount,
                    payoutNote: m.payoutNote,
                    gotra: member.gotra,
                    jati: member.jati,
                    dob: member.dob,
                    village: member.village,
                    district: member.district,
                    state: member.state,
                    address: member.address,
                    phone: member.primaryPhone,
                    warisName: member.warisName,
                    warisRelation: member.warisRelation,
                    agentName: m.agentName,
                    photoUrl: member.photoUrl,
                  ),
                  failedMessage: t.certificateFailed,
                );
              },
              icon: const Icon(Icons.print_outlined, size: 17),
              label: Text(t.printCertificate),
            ),
          ],
        ],
      ),
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
