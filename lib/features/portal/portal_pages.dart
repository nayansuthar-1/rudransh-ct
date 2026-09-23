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
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primitives.dart';
import '../certificate/certificate_action.dart';
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
    final sections = user.role.nav.skip(1).toList();
    final isMember = user.role == UserRole.member;

    return PageBody(
      maxWidth: 720,
      children: [
        SectionHeader(
          title: 'Namaste, ${user.name}',
          subtitle: '${S.trustName} · ${user.role.label}',
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
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.myMembership,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                m.status.label,
                tone: m.status == MemberStatus.active
                    ? PillTone.success
                    : PillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          DetailRow(label: S.lookupRegNo, value: m.regNo),
          DetailRow(label: S.yojna, value: m.yojnaName),
          DetailRow(label: 'Contribution', value: Fmt.money(m.contributionAmount)),
          DetailRow(label: 'Member since', value: Fmt.date(m.joinDate)),
          DetailRow(label: 'Phone', value: Fmt.phone(m.primaryPhone)),
          DetailRow(label: 'Address', value: m.address),
          DetailRow(
            label: 'Nominee',
            value: m.warisRelation.isEmpty
                ? m.warisName
                : '${m.warisName} (${m.warisRelation})',
          ),
          if (m.agentName.isNotEmpty)
            DetailRow(label: 'Your agent', value: m.agentName),
          if (m.regNo.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => printMemberCertificate(
                context,
                member: Member(
                  id: m.memberId,
                  yojnaId: m.yojnaId,
                  regNo: m.regNo,
                  name: m.name,
                  fatherOrHusbandName: m.fatherOrHusbandName,
                  jati: '',
                  warisName: m.warisName,
                  warisRelation: m.warisRelation,
                  primaryPhone: m.primaryPhone,
                  altPhone: m.altPhone,
                  aadhaar: '',
                  village: m.village,
                  tehsil: m.tehsil,
                  district: m.district,
                  pincode: m.pincode,
                  joinDate: m.joinDate,
                  status: m.status,
                ),
                agentName: m.agentName,
              ),
              icon: const Icon(Icons.print_outlined, size: 17),
              label: const Text(S.printCertificate),
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
                S.myCorrections,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: () => showCorrectionDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(S.requestCorrection),
              ),
            ],
          ),
          if (items.isEmpty)
            Text(
              S.noCorrections,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            )
          else
            for (final r in items) ...[
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.field.label}: ${r.newValue}',
                      style: text.bodySmall,
                    ),
                  ),
                  StatusPill(
                    r.status.label,
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
