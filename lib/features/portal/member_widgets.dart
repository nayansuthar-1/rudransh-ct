import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/member_text.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/member_lang.dart';
import '../../state/providers.dart';
import '../../widgets/primitives.dart';
import '../../widgets/stat_card.dart';
import '../certificate/certificate_action.dart';
import '../certificate/certificate_data.dart';
import '../receipt/receipt_action.dart';

/// Pieces the member screens share: the membership card, the standing
/// banner, shortcuts, and a receipt row.

/// Tile background for [accent]: its soft tint, or a blend in dark mode.
/// The same rule as [StatCard], so banners and tiles match.
Color accentBackground(BuildContext context, StatAccent accent) =>
    Theme.of(context).brightness == Brightness.dark
        ? Color.alphaBlend(
            accent.color.withValues(alpha: 0.16),
            context.colors.surface,
          )
        : accent.tint;

/// A number that counts up from zero the first time it shows.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => builder(context, v),
      );
}

/// Heading above a dashboard section, with an optional "See all".
class MemberSectionTitle extends StatelessWidget {
  const MemberSectionTitle(this.title, {super.key, this.onSeeAll, this.seeAll});

  final String title;
  final String? seeAll;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text(seeAll ?? '')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Membership card
// ---------------------------------------------------------------------------

/// The member's card: photo, name, reg no, Yojna and status on the trust's
/// blue, like a membership card in the wallet.
class MemberIdCard extends ConsumerWidget {
  const MemberIdCard(this.m, {super.key});

  final Membership m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = ref.watch(memberTextProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    const white = Colors.white;
    final soft = white.withValues(alpha: 0.78);
    final active = m.status == MemberStatus.active;

    return Container(
      decoration: BoxDecoration(
        color: dark ? c.brandSoft : c.brand,
        borderRadius: BorderRadius.circular(Radii.dialog),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Two faint rings for texture; flat colour, no gradient.
          Positioned(right: -56, top: -72, child: _Ring(size: 200)),
          Positioned(right: 48, bottom: -90, child: _Ring(size: 160)),
          Padding(
            padding: const EdgeInsets.all(Space.xl - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 16, color: soft),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.myMembership,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: soft,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF6DD58C)
                                  : const Color(0xFFF6C35B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.memberStatus(m.status),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    _Photo(url: m.photoUrl, name: m.name),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: white,
                              height: 1.25,
                            ),
                          ),
                          if (m.fatherOrHusbandName.isNotEmpty)
                            Text(
                              m.fatherOrHusbandName,
                              style: TextStyle(fontSize: 13, color: soft),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xl - 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CardField(
                        label: t.regNo,
                        value: m.regNo.isEmpty ? '—' : m.regNo,
                        big: true,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    _CardField(
                      label: t.memberSince,
                      value: Fmt.date(m.joinDate),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                _CardField(label: t.yojna, value: m.yojnaName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 28,
          ),
        ),
      );
}

class _CardField extends StatelessWidget {
  const _CardField({
    required this.label,
    required this.value,
    this.big = false,
  });

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 17 : 14,
            fontWeight: big ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: big ? 0.6 : 0,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// The member's photo, or their initials when there is none.
class _Photo extends StatelessWidget {
  const _Photo({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 60.0;
    final initials = Container(
      color: Colors.white.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        Fmt.initials(name),
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? initials
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Standing
// ---------------------------------------------------------------------------

/// What the member owes right now, in one line and one button: due (amber),
/// waiting for the office (blue), or all paid (green).
class StandingBanner extends ConsumerWidget {
  const StandingBanner(this.dues, {super.key});

  final List<MemberDue> dues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(memberTextProvider);
    final open = dues.where((d) => d.due > 0 && d.pending <= 0).toList()
      ..sort((a, b) => a.closingDate.compareTo(b.closingDate));
    final owed = open.fold<double>(0, (s, d) => s + d.due);
    final waiting = dues.fold<double>(0, (s, d) => s + d.pending);

    final (accent, icon, title, sub) = owed > 0
        ? (
            StatAccent.amber,
            Icons.account_balance_wallet_outlined,
            t.owedTitle(owed),
            t.owedSub(open.length, open.first.closingDate),
          )
        : waiting > 0
            ? (
                StatAccent.blue,
                Icons.hourglass_top_rounded,
                t.pendingTitle(waiting),
                t.pendingSub,
              )
            : (
                StatAccent.green,
                Icons.verified_rounded,
                t.allPaidTitle,
                t.allPaidSub,
              );

    return _Banner(
      accent: accent,
      icon: icon,
      title: title,
      subtitle: sub,
      action: owed > 0
          ? FilledButton(
              onPressed: () => context.go(AppRoutes.memberDues),
              child: Text(t.payNow),
            )
          : null,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final StatAccent accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final message = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: accent.color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: accentBackground(context, accent),
        borderRadius: BorderRadius.circular(Radii.dialog),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) return message;
          // A phone puts the button under the message.
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                message,
                const SizedBox(height: Space.md),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: action,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: Space.md),
              action!,
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shortcuts
// ---------------------------------------------------------------------------

class QuickAction {
  const QuickAction(this.icon, this.label, this.accent, this.onTap);

  final IconData icon;
  final String label;
  final StatAccent accent;
  final VoidCallback? onTap;
}

/// A row of round shortcuts, one per thing a member comes here to do.
class QuickActions extends StatelessWidget {
  const QuickActions(this.items, {super.key});

  final List<QuickAction> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in items)
          Expanded(
            child: InkWell(
              onTap: a.onTap,
              borderRadius: BorderRadius.circular(Radii.dialog),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accentBackground(context, a.accent),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(a.icon, color: a.accent.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Certificate and receipts
// ---------------------------------------------------------------------------

/// Prints the member's own certificate.
void printMyCertificate(BuildContext context, Membership m, MemberText t) {
  final member = m.toMember();
  printCertificateData(
    context,
    CertificateData(
      regNo: member.regNo,
      joinedOn: member.joinDate,
      name: member.name,
      fatherOrHusbandName: member.fatherOrHusbandName,
      yojnaName: m.yojnaName,
      yojnaStartedOn: m.yojnaStartedOn,
      yojnaShortName: m.yojnaShortName,
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
}

/// Approved and not cancelled: money that counts.
bool isApproved(Payment p) => p.status == PaymentStatus.paid && !p.isCancelled;

/// One receipt: a status icon, number and date, amount, and print.
class MemberPaymentTile extends ConsumerWidget {
  const MemberPaymentTile(this.payment, {super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final cancelled = payment.isCancelled;
    final t = ref.watch(memberTextProvider);

    final (accent, icon) = cancelled
        ? (null, Icons.block_rounded)
        : switch (payment.status) {
            PaymentStatus.paid => (StatAccent.green, Icons.check_rounded),
            PaymentStatus.pending => (StatAccent.amber, Icons.schedule_rounded),
            PaymentStatus.failed => (StatAccent.red, Icons.close_rounded),
          };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent == null
                  ? c.surfaceMuted
                  : accentBackground(context, accent),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: accent?.color ?? c.textMuted,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.receiptNo.isEmpty ? '—' : payment.receiptNo,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${Fmt.date(payment.date)} · ${t.paymentKind(payment.kind)}',
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
                if (payment.rejectReason.isNotEmpty)
                  Text(
                    payment.rejectReason,
                    style: text.bodySmall?.copyWith(color: c.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(payment.amount),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              StatusPill(
                t.paymentStatus(payment),
                tone: cancelled
                    ? PillTone.neutral
                    : switch (payment.status) {
                        PaymentStatus.paid => PillTone.success,
                        PaymentStatus.pending => PillTone.warning,
                        PaymentStatus.failed => PillTone.danger,
                      },
              ),
            ],
          ),
          if (!cancelled && payment.receiptNo.isNotEmpty) ...[
            const SizedBox(width: Space.xs),
            IconButton(
              icon: const Icon(Icons.print_outlined, size: 20),
              tooltip: t.printReceipt,
              onPressed: () {
                final membership = ref.read(myMembershipProvider).value;
                printPaymentReceipt(
                  context,
                  payment: payment,
                  member: membership?.toMember(),
                  yojnaName: membership?.yojnaName ?? '',
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
