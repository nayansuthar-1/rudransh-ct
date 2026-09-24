import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import '../state/auth_controller.dart';
import '../state/member_lang.dart';
import '../state/providers.dart';
import 'app_sidebar.dart';
import 'member_lang_toggle.dart';

/// Frame for agent and member screens (IMPLEMENTATION_PLAN §11.5).
///
/// Designed for phones first: a slim header and a bottom navigation bar.
/// On wider screens the content stays in a centred column.
class RoleShell extends ConsumerWidget {
  const RoleShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final isMember = user.role == UserRole.member;
    final t = ref.watch(memberTextProvider);
    // Members read their screens in the language they chose; agents in English.
    final items = [
      for (final item in user.role.nav) isMember ? t.nav(item) : item,
    ];
    // Longest matching path wins, so `/agent/members` does not select `/agent`.
    var selected = 0;
    for (var i = 0; i < items.length; i++) {
      final path = items[i].path;
      if ((location == path || location.startsWith('$path/')) &&
          path.length >= items[selected].path.length) {
        selected = i;
      }
    }

    return Scaffold(
      backgroundColor: c.canvas,
      body: Column(
        children: [
          _Header(title: items[selected].label),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: items.length < 2
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(items[i].path),
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isMember = user.role == UserRole.member;
    final t = ref.watch(memberTextProvider);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.sm, 0),
            child: Row(
              children: [
                const BrandMark(size: 28),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        '${S.appName} · ${isMember ? t.member : user.role.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                if (isMember) const MemberLangToggle(),
                IconButton(
                  tooltip: isMember ? t.toggleTheme : S.toggleTheme,
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  icon: Icon(
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: user.email,
                  position: PopupMenuPosition.under,
                  onSelected: (_) =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  itemBuilder: (context) => [
                    PopupMenuItem<int>(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
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
                    const PopupMenuDivider(),
                    PopupMenuItem<int>(
                      value: 0,
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded, size: 17),
                          const SizedBox(width: 10),
                          Text(isMember ? t.logout : S.logout),
                        ],
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: c.brand,
                      child: Text(
                        user.name.isEmpty
                            ? '?'
                            : user.name.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: c.onBrand,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
