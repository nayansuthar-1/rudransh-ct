import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../data/models/models.dart';
import '../state/auth_controller.dart';
import '../state/providers.dart';
import 'forms/agent_form_dialog.dart';
import 'forms/member_form_dialog.dart';
import 'forms/payment_form_dialog.dart';

class AppTopBar extends ConsumerWidget {
  const AppTopBar({
    super.key,
    required this.currentPath,
    required this.onLeadingTap,
    this.leadingIcon = Icons.menu_rounded,
  });

  final String currentPath;
  final VoidCallback onLeadingTap;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final item = AppRoutes.itemFor(currentPath);
    final compact = context.isMobile;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 10, compact ? 8 : 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onLeadingTap,
                    icon: Icon(leadingIcon, size: 22),
                    tooltip: 'Menu',
                  ),
                  const SizedBox(width: 2),
                  if (!compact)
                    Flexible(
                      flex: 3,
                      child: Row(
                        children: [
                          Flexible(child: _Breadcrumb(label: item.label)),
                          const SizedBox(width: 14),
                          const Flexible(child: YojnaSelector()),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Actions scroll rather than overflow when the viewport is
                  // too narrow for the full set of buttons.
                  Flexible(
                    flex: 5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _actions(context, ref),
                      ),
                    ),
                  ),
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 10),
                const YojnaSelector(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final full = context.isDesktop || context.isLaptop;
    final yojnaId = ref.watch(selectedYojnaIdProvider);

    final widgets = <Widget>[];

    if (full) {
      widgets.addAll([
        _ActionButton(
          label: S.addPayment,
          icon: Icons.add,
          background: c.brand,
          onTap: () => showPaymentFormDialog(context),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          label: S.addAgent,
          icon: Icons.person_add_alt,
          background: c.ink,
          onTap: () => showAgentFormDialog(context),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          label: S.addMemberHi,
          icon: Icons.add,
          background: c.slate,
          onTap: () => showMemberFormDialog(context, presetYojnaId: yojnaId),
        ),
        const SizedBox(width: 10),
      ]);
    } else {
      widgets.addAll([
        PopupMenuButton<int>(
          tooltip: S.add,
          position: PopupMenuPosition.under,
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: c.brand,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
          onSelected: (value) {
            switch (value) {
              case 0:
                showPaymentFormDialog(context);
              case 1:
                showAgentFormDialog(context);
              case 2:
                showMemberFormDialog(context, presetYojnaId: yojnaId);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0, child: Text(S.addPayment)),
            PopupMenuItem(value: 1, child: Text(S.addAgent)),
            PopupMenuItem(value: 2, child: Text(S.addMemberHi)),
          ],
        ),
        const SizedBox(width: 4),
      ]);
    }

    widgets.addAll([
      _RequestsButton(showLabel: full),
      IconButton(
        tooltip: S.toggleTheme,
        onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        icon: Icon(
          Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          size: 19,
        ),
      ),
      const SizedBox(width: 4),
      const _UserChip(),
    ]);

    return widgets;
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            S.home,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: c.textSecondary),
          ),
        ),
        Icon(Icons.chevron_right, size: 16, color: c.textMuted),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Scheme scope selector — mirrors the dropdown in the reference header.
class YojnaSelector extends ConsumerWidget {
  const YojnaSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];
    final selectedId = ref.watch(selectedYojnaIdProvider);
    final selected = ref.watch(selectedYojnaProvider);

    return Container(
      constraints: BoxConstraints(
        maxWidth: context.responsive(mobile: 1000, tablet: 230, laptop: 280),
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.borderStrong),
      ),
      child: PopupMenuButton<String?>(
        tooltip: S.selectYojna,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        onSelected: (value) =>
            ref.read(selectedYojnaIdProvider.notifier).select(value),
        itemBuilder: (context) => [
          PopupMenuItem<String?>(
            value: null,
            child: Text(
              'सभी योजनाएँ (All)',
              style: TextStyle(color: c.textSecondary),
            ),
          ),
          for (final y in yojnas)
            PopupMenuItem<String?>(
              value: y.id,
              child: Row(
                children: [
                  Expanded(child: Text(y.name)),
                  if (y.id == selectedId)
                    Icon(Icons.check, size: 16, color: c.brand),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected?.name ?? 'सभी योजनाएँ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bell with a badge for pending payment approvals.
class _RequestsButton extends ConsumerWidget {
  const _RequestsButton({required this.showLabel});

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final payments = ref.watch(paymentsProvider).value ?? const <Payment>[];
    final pending =
        payments.where((p) => p.status == PaymentStatus.pending).length;

    final bell = Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded, size: 21),
        if (pending > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 15),
              decoration: BoxDecoration(
                color: c.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.surface, width: 1.5),
              ),
              child: Text(
                pending > 99 ? '99+' : '$pending',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );

    if (!showLabel) {
      return IconButton(
        tooltip: '${S.requests} ($pending)',
        onPressed: () => _openRequests(context, pending),
        icon: bell,
      );
    }

    return TextButton.icon(
      onPressed: () => _openRequests(context, pending),
      icon: bell,
      label: Text(S.requests, style: TextStyle(color: c.textSecondary)),
      style: TextButton.styleFrom(foregroundColor: c.textSecondary),
    );
  }

  void _openRequests(BuildContext context, int pending) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            pending == 0
                ? 'No pending requests'
                : '$pending pending payment ${pending == 1 ? 'request' : 'requests'} — see Payments › Pending',
          ),
        ),
      );
  }
}

class _UserChip extends ConsumerWidget {
  const _UserChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final showName = context.isDesktop;

    return PopupMenuButton<int>(
      tooltip: user.name,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 0) ref.read(authControllerProvider.notifier).signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              Text(
                user.email,
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 17),
              SizedBox(width: 10),
              Text(S.logout),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: c.brandSoft,
              child: Text(
                user.name.isEmpty ? '?' : user.name.characters.first,
                style: TextStyle(
                  color: c.brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (showName) ...[
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    user.role,
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: c.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
