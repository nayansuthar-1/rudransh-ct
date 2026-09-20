import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/extensions.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/forms/member_form_dialog.dart';
import '../../widgets/forms/payment_form_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';
import '../certificate/certificate_action.dart';

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(membersPageProvider);
    final page = async.value ?? PageResult.empty<Member>();
    final scopeTotal = ref.watch(dashboardStatsProvider).value?.totalMembers;
    final agents = ref.watch(agentByIdProvider);
    final yojnas = ref.watch(yojnaByIdProvider);
    final yojnaId = ref.watch(selectedYojnaIdProvider);
    final selectedYojna = ref.watch(selectedYojnaProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.members,
          subtitle: [
            if (scopeTotal != null)
              '${Fmt.number(scopeTotal)} ${S.membersCount.toLowerCase()}',
            selectedYojna?.name ?? S.allYojnas,
          ].join(' · '),
          actions: [
            FilledButton.icon(
              onPressed: () =>
                  showMemberFormDialog(context, presetYojnaId: yojnaId),
              icon: const Icon(Icons.add, size: 17),
              label: const Text(S.addMember),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const _MemberFilters(),
        const SizedBox(height: Space.md),
        AppCard(
          child: Builder(
            builder: (context) {
              if (async.isLoading && async.value == null) {
                return const LoadingState();
              }
              if (async.hasError && async.value == null) {
                return ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(membersPageProvider),
                );
              }
              return ResponsiveTable<Member>(
                rows: page.items,
                totalCount: page.total,
                pageSize: listPageSize,
                page: ref.watch(memberPageProvider),
                onPageChanged: ref.read(memberPageProvider.notifier).set,
                busy: async.isLoading,
                onRowTap: (m) => showMemberDetails(context, ref, m),
                mobileTitle: (m) => m.name,
                mobileSubtitle: (m) => m.regNo,
                mobileTrailing: (context, m) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: MemberStatusPill(status: m.status),
                ),
                columns: [
                  TableCol<Member>(
                    label: S.memberName,
                    flex: 2,
                    minWidth: 190,
                    text: (m) => m.name,
                    cell: (context, m) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          m.fatherOrHusbandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TableCol<Member>(
                    label: S.regNo,
                    minWidth: 130,
                    showOnMobile: false,
                    text: (m) => m.regNo,
                    cell: (context, m) => Text(
                      m.regNo,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ),
                  TableCol<Member>(
                    label: S.phone,
                    minWidth: 125,
                    text: (m) => Fmt.phone(m.primaryPhone),
                    cell: (context, m) => Text(Fmt.phone(m.primaryPhone)),
                  ),
                  TableCol<Member>(
                    label: S.scheme,
                    minWidth: 160,
                    hideBelow: ScreenSize.desktop,
                    text: (m) => yojnas[m.yojnaId]?.name ?? '—',
                    cell: (context, m) => Text(
                      yojnas[m.yojnaId]?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TableCol<Member>(
                    label: S.agent,
                    minWidth: 140,
                    hideBelow: ScreenSize.laptop,
                    text: (m) => agents[m.agentId]?.name ?? '—',
                    cell: (context, m) => Text(
                      agents[m.agentId]?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TableCol<Member>(
                    label: S.joinedOn,
                    minWidth: 110,
                    hideBelow: ScreenSize.laptop,
                    text: (m) => Fmt.date(m.joinDate),
                    cell: (context, m) => Text(Fmt.date(m.joinDate)),
                  ),
                  TableCol<Member>(
                    label: S.status,
                    minWidth: 100,
                    showOnMobile: false,
                    cell: (context, m) => MemberStatusPill(status: m.status),
                  ),
                ],
                rowActions: (context, m) => _MemberActions(member: m),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MemberStatusPill extends StatelessWidget {
  const MemberStatusPill({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      MemberStatus.active => PillTone.success,
      MemberStatus.inactive => PillTone.neutral,
      MemberStatus.closed => PillTone.info,
      MemberStatus.pending => PillTone.warning,
    };
    return StatusPill(status.label, tone: tone);
  }
}

class _MemberFilters extends ConsumerWidget {
  const _MemberFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(memberFilterProvider);
    final notifier = ref.read(memberFilterProvider.notifier);
    final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
    final districts =
        ref.watch(memberDistrictsProvider).value ?? const <String>[];

    return FilterBar(
      search: SearchField(
        hint: 'Name, reg no, phone, village…',
        value: filter.query,
        onChanged: notifier.setQuery,
      ),
      filters: [
        FilterMenu<MemberStatus>(
          label: S.status,
          value: filter.status,
          items: MemberStatus.values,
          itemLabel: (s) => s.label,
          onChanged: notifier.setStatus,
        ),
        FilterMenu<Agent>(
          label: S.agent,
          value: agents.where((a) => a.id == filter.agentId).firstOrNull,
          items: agents,
          itemLabel: (a) => a.name,
          onChanged: (a) => notifier.setAgent(a?.id),
        ),
        FilterMenu<String>(
          label: 'District',
          value: filter.district,
          items: districts,
          itemLabel: (d) => d,
          onChanged: notifier.setDistrict,
        ),
      ],
      onClear: filter.isEmpty ? null : notifier.clear,
    );
  }
}

class _MemberActions extends ConsumerWidget {
  const _MemberActions({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PopupMenuButton<int>(
      tooltip: S.actions,
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.more_horiz, size: 19),
      onSelected: (value) async {
        switch (value) {
          case 0:
            showMemberDetails(context, ref, member);
          case 1:
            showMemberFormDialog(context, existing: member);
          case 2:
            showPaymentFormDialog(context, presetMember: member);
          case 3:
            final ok = await confirmDialog(
              context,
              message:
                  'A member with receipts cannot be deleted; mark them Inactive '
                  'instead. A member without receipts will be removed permanently.',
            );
            if (!ok || !context.mounted) return;
            await runWithToast(
              context,
              () => ref.read(memberActionsProvider).remove(member.id),
              success: 'Member deleted',
            );
          case 4:
            await _exportMemberData(context, ref, member);
          case 5:
            final reason = await reasonDialog(
              context,
              title: 'Erase ${member.name}?',
              message: 'Their name, phone, address, nominee and Aadhaar are '
                  'overwritten and cannot be recovered. Receipts and closings '
                  'stay, because the trust must keep its financial records.',
              confirmLabel: S.eraseData,
            );
            if (reason == null || !context.mounted) return;
            await runWithToast(
              context,
              () => ref
                  .read(repositoryProvider)
                  .eraseMemberData(member.id, reason),
              success: 'Member data erased',
            );
            ref.invalidate(membersPageProvider);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text(S.view)),
        const PopupMenuItem(value: 1, child: Text(S.edit)),
        const PopupMenuItem(value: 2, child: Text(S.addPayment)),
        // A data request under the DPDP Act is the owner's call, not staff's
        // (IMPLEMENTATION_PLAN §7).
        if (ref.watch(currentUserProvider).isOwner) ...[
          const PopupMenuItem(value: 4, child: Text(S.exportData)),
          PopupMenuItem(
            value: 5,
            child: Text(S.eraseData, style: TextStyle(color: c.danger)),
          ),
        ],
        PopupMenuItem(
          value: 3,
          child: Text(S.delete, style: TextStyle(color: c.danger)),
        ),
      ],
    );
  }
}

/// Hands the member's own data back to them, as JSON they can keep. Shown in a
/// dialog rather than downloaded: the trust has a handful of these a year, and
/// a file download needs platform plumbing this app does not otherwise carry.
Future<void> _exportMemberData(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  try {
    final data = await ref.read(repositoryProvider).exportMemberData(member.id);
    if (!context.mounted) return;
    final text = const JsonEncoder.withIndent('  ').convert(data);
    await AppDialog.show<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '${S.exportData}: ${member.name}',
        subtitle: member.regNo,
        maxWidth: 720,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(S.cancel),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (dialogContext.mounted) {
                showToast(dialogContext, 'Copied');
              }
            },
            icon: const Icon(Icons.copy_all_outlined, size: 17),
            label: const Text('Copy'),
          ),
        ],
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) showToast(context, '$e', error: true);
  }
}

void showMemberDetails(BuildContext context, WidgetRef ref, Member m) {
  final yojna = ref.read(yojnaByIdProvider)[m.yojnaId];
  final agent = ref.read(agentByIdProvider)[m.agentId];

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: m.name,
      subtitle: '${m.regNo} · ${yojna?.name ?? ''}',
      maxWidth: 640,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () => printMemberCertificate(
            context,
            member: m,
            yojna: yojna,
            agent: agent,
          ),
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text(S.printCertificate),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            showMemberFormDialog(context, existing: m);
          },
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text(S.edit),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MemberStatusPill(status: m.status),
              StatusPill(m.gender.label),
              if (m.closingGroup != null)
                StatusPill(m.closingGroup!, tone: PillTone.info),
            ],
          ),
          const SizedBox(height: 8),
          DetailRow(label: S.fldFather, value: m.fatherOrHusbandName),
          DetailRow(label: S.fldJati, value: m.jati),
          DetailRow(label: S.fldGotra, value: m.gotra),
          if (m.dob != null)
            DetailRow(label: S.fldDob, value: Fmt.date(m.dob)),
          DetailRow(
            label: S.fldWaris,
            value: '${m.warisName} (${m.warisRelation})',
          ),
          DetailRow(label: S.fldPrimaryPhone, value: Fmt.phone(m.primaryPhone)),
          if (m.altPhone.isNotEmpty)
            DetailRow(label: S.fldAltPhone, value: Fmt.phone(m.altPhone)),
          _AadhaarRow(member: m),
          DetailRow(label: S.addressInfo, value: m.address),
          if (m.state.isNotEmpty) DetailRow(label: S.fldState, value: m.state),
          DetailRow(label: S.agent, value: agent?.name ?? '—'),
          DetailRow(label: S.joinedOn, value: Fmt.date(m.joinDate)),
          if (m.closingDate != null)
            DetailRow(label: S.closingDate, value: Fmt.date(m.closingDate)),
          _MemberRecentPayments(memberId: m.id),
        ],
      ),
    ),
  );
}

class _MemberRecentPayments extends ConsumerWidget {
  const _MemberRecentPayments({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments =
        ref.watch(memberRecentPaymentsProvider(memberId)).value?.items ??
        const <Payment>[];
    if (payments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const SectionHeader(title: S.recentPayments, dense: true),
        const SizedBox(height: 4),
        for (final p in payments)
          DetailRow(
            label: '${p.receiptNo} · ${Fmt.date(p.date)}',
            value: Fmt.money(p.amount),
          ),
      ],
    );
  }
}

/// Aadhaar in the member detail sheet.
///
/// The number is encrypted in the database (IMPLEMENTATION_PLAN §7), so all
/// this row has is the last four digits. An owner can ask for the rest, which
/// fetches it on demand rather than carrying it around in every member list.
class _AadhaarRow extends ConsumerStatefulWidget {
  const _AadhaarRow({required this.member});

  final Member member;

  @override
  ConsumerState<_AadhaarRow> createState() => _AadhaarRowState();
}

class _AadhaarRowState extends ConsumerState<_AadhaarRow> {
  String? _full;
  bool _busy = false;

  Future<void> _reveal() async {
    setState(() => _busy = true);
    try {
      final value =
          await ref.read(repositoryProvider).fetchMemberAadhaar(widget.member.id);
      if (!mounted) return;
      setState(() {
        _full = value;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final isOwner = ref.watch(currentUserProvider).isOwner;
    final masked = Fmt.aadhaarFromLast4(m.aadhaarLast4);

    // Nothing on record, or a role that may never see more than the mask.
    if (!isOwner || m.aadhaarLast4.isEmpty) {
      return DetailRow(label: S.fldAadhaar, value: masked);
    }

    return Row(
      children: [
        Expanded(
          child: DetailRow(
            label: S.fldAadhaar,
            value: _full == null ? masked : Fmt.aadhaar(_full!),
          ),
        ),
        if (_full == null)
          TextButton(
            onPressed: _busy ? null : _reveal,
            child: Text(_busy ? '…' : S.show),
          ),
      ],
    );
  }
}
