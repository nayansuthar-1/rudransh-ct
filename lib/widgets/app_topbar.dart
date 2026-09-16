import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import '../state/auth_controller.dart';
import '../state/providers.dart';
import '../state/selectors.dart';
import 'app_sidebar.dart';
import 'forms/agent_form_dialog.dart';
import 'forms/member_form_dialog.dart';
import 'forms/payment_form_dialog.dart';

/// Header above every page.
///
/// * phones — menu, brand, search, "+" and account; the Yojna scope gets its
///   own full-width row underneath
/// * tablet and up — member search on the left; Yojna scope, "New",
///   requests, theme and account on the right
class AppTopBar extends ConsumerWidget {
  const AppTopBar({
    super.key,
    required this.currentPath,
    required this.onLeadingTap,
    this.showLeading = true,
  });

  final String currentPath;
  final VoidCallback onLeadingTap;
  final bool showLeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mobile = context.isMobile;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: mobile ? _phone(context) : _wide(context),
      ),
    );
  }

  Widget _phone(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLeadingTap,
                  icon: const Icon(Icons.menu_rounded, size: 21),
                  tooltip: 'Menu',
                ),
                const SizedBox(width: Space.xs),
                const BrandMark(size: 28),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    S.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: S.searchMembers,
                  onPressed: () => context.go(AppRoutes.members),
                  icon: const Icon(Icons.search_rounded, size: 22),
                ),
                const SizedBox(width: Space.xs),
                const _NewMenu(compact: true),
                const SizedBox(width: Space.sm),
                const _AccountMenu(extended: true),
              ],
            ),
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: const YojnaSelector(expand: true),
        ),
      ],
    );
  }

  Widget _wide(BuildContext context) {
    // The search box needs ~420px beside the controls; below that it becomes
    // an icon.
    final roomyForSearch = context.screenWidth >= 900;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        child: Row(
          children: [
            if (showLeading) ...[
              IconButton(
                onPressed: onLeadingTap,
                icon: const Icon(Icons.menu_rounded, size: 20),
                tooltip: 'Menu',
              ),
              const SizedBox(width: Space.sm),
            ],
            if (roomyForSearch)
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _MemberSearch(),
                ),
              )
            else ...[
              IconButton(
                tooltip: S.searchMembers,
                onPressed: () => context.go(AppRoutes.members),
                icon: const Icon(Icons.search_rounded, size: 22),
              ),
              const Spacer(),
            ],
            const SizedBox(width: Space.lg),
            const Flexible(child: YojnaSelector()),
            const SizedBox(width: Space.md),
            const _NewMenu(compact: false),
            const SizedBox(width: Space.md),
            const _RequestsButton(),
            const _ThemeButton(),
            const SizedBox(width: Space.sm),
            const _AccountMenu(extended: false),
          ],
        ),
      ),
    );
  }
}

/// Gmail-style search pill. Submitting opens Members filtered by the query,
/// from any page.
class _MemberSearch extends ConsumerStatefulWidget {
  const _MemberSearch();

  @override
  ConsumerState<_MemberSearch> createState() => _MemberSearchState();
}

class _MemberSearchState extends ConsumerState<_MemberSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String text) {
    ref.read(memberFilterProvider.notifier).setQuery(text.trim());
    context.go(AppRoutes.members);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? c.surfaceMuted : const Color(0xFFEEF2F7);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _controller,
          onSubmitted: _submit,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: S.searchMembers,
            hintStyle: TextStyle(fontSize: 15, color: c.textSecondary),
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 22,
              color: c.textSecondary,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 52,
              minHeight: 44,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        ref.read(memberFilterProvider.notifier).setQuery('');
                      },
                    ),
            ),
            border: _pill(Colors.transparent),
            enabledBorder: _pill(Colors.transparent),
            focusedBorder: _pill(c.brand, width: 1.5),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _pill(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Scheme scope selector. Every page filters by it.
class YojnaSelector extends ConsumerWidget {
  const YojnaSelector({super.key, this.expand = false});

  /// Fill the available width (phone header row).
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];
    final selectedId = ref.watch(selectedYojnaIdProvider);
    final selected = ref.watch(selectedYojnaProvider);

    final label = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text('Yojna', style: TextStyle(fontSize: 13, color: c.textMuted)),
        const SizedBox(width: 8),
        Flexible(
          fit: expand ? FlexFit.tight : FlexFit.loose,
          child: Text(
            selected?.name ?? S.allYojnas,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.unfold_more_rounded, size: 16, color: c.textMuted),
      ],
    );

    return PopupMenuButton<String>(
      tooltip: S.selectYojna,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      onSelected: (value) => ref
          .read(selectedYojnaIdProvider.notifier)
          .select(value.isEmpty ? null : value),
      itemBuilder: (context) => [
        _option(context, '', S.allYojnas, selectedId == null),
        const PopupMenuDivider(height: 9),
        for (final y in yojnas)
          _option(context, y.id, y.name, y.id == selectedId),
      ],
      child: Container(
        height: 40,
        constraints: BoxConstraints(maxWidth: expand ? double.infinity : 320),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.control),
          border: expand ? null : Border.all(color: c.borderStrong),
        ),
        child: label,
      ),
    );
  }

  PopupMenuItem<String> _option(
    BuildContext context,
    String value,
    String text,
    bool selected,
  ) {
    final c = context.colors;
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: c.textPrimary),
            ),
          ),
          if (selected) Icon(Icons.check, size: 16, color: c.brand),
        ],
      ),
    );
  }
}

/// "New" menu: payment, member, agent.
class _NewMenu extends ConsumerWidget {
  const _NewMenu({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final yojnaId = ref.watch(selectedYojnaIdProvider);

    return PopupMenuButton<int>(
      tooltip: S.add,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 210),
      onSelected: (value) {
        switch (value) {
          case 0:
            showPaymentFormDialog(context);
          case 1:
            showMemberFormDialog(context, presetYojnaId: yojnaId);
          case 2:
            showAgentFormDialog(context);
        }
      },
      itemBuilder: (context) => [
        _item(context, 0, Icons.receipt_long_outlined, S.addPayment),
        _item(context, 1, Icons.person_add_alt_outlined, S.addMember),
        _item(context, 2, Icons.badge_outlined, S.addAgent),
      ],
      child: Container(
        height: compact ? 40 : 40,
        width: compact ? 40 : null,
        padding: compact ? null : const EdgeInsets.only(left: 14, right: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.brandSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: compact
            ? Icon(Icons.add, size: 22, color: c.onBrandSoft)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 20, color: c.onBrandSoft),
                  const SizedBox(width: Space.sm),
                  Text(
                    'New',
                    style: TextStyle(
                      color: c.onBrandSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  PopupMenuItem<int> _item(
    BuildContext context,
    int value,
    IconData icon,
    String label,
  ) {
    final c = context.colors;
    return PopupMenuItem<int>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13.5, color: c.textPrimary)),
        ],
      ),
    );
  }
}

class _ThemeButton extends ConsumerWidget {
  const _ThemeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: S.toggleTheme,
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
      icon: Icon(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 18,
      ),
    );
  }
}

/// Bell with a count of pending payments.
class _RequestsButton extends ConsumerWidget {
  const _RequestsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pending = ref.watch(pendingPaymentCountProvider).value ?? 0;

    return IconButton(
      tooltip: '${S.requests} ($pending)',
      onPressed: () => showRequestsToast(context, pending),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 19),
          if (pending > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 1.2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void showRequestsToast(BuildContext context, int pending) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        width: context.isMobile ? null : 420,
        content: Text(
          pending == 0
              ? 'No pending requests'
              : '$pending pending payment ${pending == 1 ? 'request' : 'requests'} — see Payments › Pending',
        ),
      ),
    );
}

/// Avatar menu. On phones it also carries requests and the theme toggle,
/// which have no room in the header.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final pending = ref.watch(pendingPaymentCountProvider).value ?? 0;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<int>(
      tooltip: user.email,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 220),
      onSelected: (value) {
        switch (value) {
          case 0:
            ref.read(authControllerProvider.notifier).signOut();
          case 1:
            showRequestsToast(context, pending);
          case 2:
            ref.read(themeModeProvider.notifier).toggle();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          height: 56,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: c.textPrimary,
                ),
              ),
              Text(
                user.email,
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 9),
        if (extended) ...[
          _item(
            context,
            1,
            Icons.notifications_none_rounded,
            pending == 0 ? S.requests : '${S.requests} ($pending)',
          ),
          _item(
            context,
            2,
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            dark ? 'Light mode' : 'Dark mode',
          ),
          const PopupMenuDivider(height: 9),
        ],
        _item(context, 0, Icons.logout_rounded, S.logout),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
          child: Text(
            user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
            style: TextStyle(
              color: c.onBrand,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<int> _item(
    BuildContext context,
    int value,
    IconData icon,
    String label,
  ) {
    final c = context.colors;
    return PopupMenuItem<int>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13.5, color: c.textPrimary)),
        ],
      ),
    );
  }
}
