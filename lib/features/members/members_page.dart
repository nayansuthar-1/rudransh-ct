import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/extensions.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/forms/member_form_dialog.dart';
import '../../widgets/forms/payment_form_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(membersProvider);
    final members = ref.watch(filteredMembersProvider);
    final scoped = ref.watch(scopedMembersProvider);
    final agents = ref.watch(agentByIdProvider);
    final yojnas = ref.watch(yojnaByIdProvider);
    final yojnaId = ref.watch(selectedYojnaIdProvider);
    final selectedYojna = ref.watch(selectedYojnaProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.members,
          subtitle:
              '${Fmt.number(scoped.length)} ${S.membersCount.toLowerCase()} · ${selectedYojna?.name ?? 'सभी योजनाएँ'}',
          actions: [
            FilledButton.icon(
              onPressed: () =>
                  showMemberFormDialog(context, presetYojnaId: yojnaId),
              icon: const Icon(Icons.add, size: 17),
              label: const Text(S.addMemberHi),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _MemberFilters(),
        const SizedBox(height: 14),
        AppCard(
          child: Builder(
            builder: (context) {
              if (async.isLoading && async.value == null) {
                return const LoadingState();
              }
              if (async.hasError && async.value == null) {
                return ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(membersProvider),
                );
              }
              return ResponsiveTable<Member>(
                rows: members,
                pageSize: 14,
                onRowTap: (m) => showMemberDetails(context, ref, m),
                mobileTitle: (m) => m.name,
                mobileSubtitle: (m) => m.regNo,
                mobileLeading: (context, m) => AppAvatar(name: m.name),
                columns: [
                  TableCol<Member>(
                    label: S.memberName,
                    flex: 2,
                    minWidth: 190,
                    text: (m) => m.name,
                    cell: (context, m) => Row(
                      children: [
                        if (!context.isMobile) ...[
                          AppAvatar(name: m.name, size: 32),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                m.fatherOrHusbandName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TableCol<Member>(
                    label: S.regNo,
                    minWidth: 130,
                    text: (m) => m.regNo,
                    cell: (context, m) => Text(
                      m.regNo,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  TableCol<Member>(
                    label: S.phone,
                    minWidth: 125,
                    text: (m) => Fmt.phone(m.primaryPhone),
                    cell: (context, m) => Text(
                      Fmt.phone(m.primaryPhone),
                      style: const TextStyle(fontSize: 13),
                    ),
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
                      style: const TextStyle(fontSize: 12.5),
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
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  TableCol<Member>(
                    label: S.joinedOn,
                    minWidth: 110,
                    hideBelow: ScreenSize.laptop,
                    text: (m) => Fmt.date(m.joinDate),
                    cell: (context, m) => Text(
                      Fmt.date(m.joinDate),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  TableCol<Member>(
                    label: S.status,
                    minWidth: 100,
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
    final districts = ref.watch(memberDistrictsProvider);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: FormGrid(
        gap: 12,
        columnsOverride:
            context.responsive<int>(mobile: 1, tablet: 2, laptop: 4),
        items: [
          GridItem(
            SearchField(
              hint: 'नाम, Reg No, फ़ोन, आधार…',
              onChanged: notifier.setQuery,
            ),
          ),
          GridItem(
            AppDropdown<MemberStatus>(
              label: '',
              value: filter.status,
              items: MemberStatus.values,
              itemLabel: (s) => s.label,
              includeAllOption: true,
              allLabel: 'All statuses',
              hint: 'All statuses',
              onChanged: notifier.setStatus,
            ),
          ),
          GridItem(
            AppDropdown<Agent>(
              label: '',
              value: agents.where((a) => a.id == filter.agentId).firstOrNull,
              items: agents,
              itemLabel: (a) => a.name,
              includeAllOption: true,
              allLabel: 'All agents',
              hint: 'All agents',
              onChanged: (a) => notifier.setAgent(a?.id),
            ),
          ),
          GridItem(
            Row(
              children: [
                Expanded(
                  child: AppDropdown<String>(
                    label: '',
                    value: filter.district,
                    items: districts,
                    itemLabel: (d) => d,
                    includeAllOption: true,
                    allLabel: 'All districts',
                    hint: 'All districts',
                    onChanged: notifier.setDistrict,
                  ),
                ),
                if (!filter.isEmpty) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: IconButton(
                      tooltip: S.clearFilters,
                      onPressed: notifier.clear,
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 19),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
            final ok = await confirmDialog(context);
            if (!ok) return;
            await ref.read(membersProvider.notifier).remove(member.id);
            if (context.mounted) showToast(context, 'सदस्य हटाया गया');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text(S.view)),
        const PopupMenuItem(value: 1, child: Text(S.edit)),
        const PopupMenuItem(value: 2, child: Text(S.addPayment)),
        PopupMenuItem(
          value: 3,
          child: Text(S.delete, style: TextStyle(color: c.danger)),
        ),
      ],
    );
  }
}

void showMemberDetails(BuildContext context, WidgetRef ref, Member m) {
  final yojna = ref.read(yojnaByIdProvider)[m.yojnaId];
  final agent = ref.read(agentByIdProvider)[m.agentId];
  final payments = (ref.read(paymentsProvider).value ?? const <Payment>[])
      .where((p) => p.memberId == m.id)
      .take(6)
      .toList();

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: m.name,
      subtitle: '${m.regNo} · ${yojna?.name ?? ''}',
      icon: Icons.person_outline,
      maxWidth: 640,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
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
          Row(
            children: [
              AppAvatar(name: m.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        MemberStatusPill(status: m.status),
                        StatusPill(m.gender.hi, tone: PillTone.neutral),
                        if (m.closingGroup != null)
                          StatusPill(m.closingGroup!, tone: PillTone.info),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DetailRow(label: S.fldFather, value: m.fatherOrHusbandName),
          DetailRow(label: S.fldJati, value: m.jati),
          DetailRow(label: S.fldGotra, value: m.gotra),
          DetailRow(
            label: S.fldWaris,
            value: '${m.warisName} (${m.warisRelation})',
          ),
          DetailRow(label: S.fldPrimaryPhone, value: Fmt.phone(m.primaryPhone)),
          if (m.altPhone.isNotEmpty)
            DetailRow(label: S.fldAltPhone, value: Fmt.phone(m.altPhone)),
          DetailRow(label: S.fldAadhaar, value: Fmt.aadhaarMasked(m.aadhaar)),
          DetailRow(label: S.addressInfo, value: m.address),
          DetailRow(label: S.agent, value: agent?.name ?? '—'),
          DetailRow(label: S.joinedOn, value: Fmt.date(m.joinDate)),
          if (m.closingDate != null)
            DetailRow(label: S.closingDate, value: Fmt.date(m.closingDate)),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionHeader(title: S.recentPayments, dense: true),
            const SizedBox(height: 8),
            for (final p in payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.receiptNo} · ${Fmt.date(p.date)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    Text(
                      Fmt.money(p.amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
