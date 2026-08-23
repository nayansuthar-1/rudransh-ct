import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../state/auth_controller.dart';

enum SidebarMode { expanded, rail, drawer }

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.mode,
    required this.currentPath,
    this.onNavigate,
  });

  final SidebarMode mode;
  final String currentPath;

  /// Called after navigation so the drawer can close itself.
  final VoidCallback? onNavigate;

  static const expandedWidth = 262.0;
  static const railWidth = 78.0;

  bool get _isRail => mode == SidebarMode.rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);

    return Container(
      width: _isRail ? railWidth : expandedWidth,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(context),
            Divider(color: c.border, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isRail) _groupLabel(context, S.mainMenu),
                    for (final item in AppRoutes.nav)
                      _NavTile(
                        item: item,
                        selected: currentPath.startsWith(item.path),
                        rail: _isRail,
                        onTap: () {
                          context.go(item.path);
                          onNavigate?.call();
                        },
                      ),
                  ],
                ),
              ),
            ),
            Divider(color: c.border, height: 1),
            if (!_isRail) _groupLabel(context, S.system),
            _UserTile(
              name: user.name,
              email: user.email,
              rail: _isRail,
              onSignOut: () {
                ref.read(authControllerProvider.notifier).signOut();
                onNavigate?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _brand(BuildContext context) {
    final c = context.colors;
    final logo = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.spa_rounded, color: Colors.white, size: 21),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isRail ? 12 : 16,
        vertical: 16,
      ),
      child: _isRail
          ? Center(child: logo)
          : Row(
              children: [
                logo,
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        S.appName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        S.appSubtitle,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _groupLabel(BuildContext context, String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: c.textMuted,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.rail,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool rail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.brand : c.textSecondary;

    final tile = Container(
      margin: EdgeInsets.symmetric(horizontal: rail ? 12 : 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? c.brandSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? c.brand.withValues(alpha: 0.28) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: selected ? null : c.surfaceMuted,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: rail ? 0 : 12,
              vertical: rail ? 12 : 10,
            ),
            child: rail
                ? Icon(selected ? item.activeIcon : item.icon,
                    size: 21, color: fg)
                : Row(
                    children: [
                      Icon(selected ? item.activeIcon : item.icon,
                          size: 20, color: fg),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w600,
                                color: selected ? c.brand : c.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              item.sublabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: c.textMuted,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return rail ? Tooltip(message: item.label, child: tile) : tile;
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.name,
    required this.email,
    required this.rail,
    required this.onSignOut,
  });

  final String name;
  final String email;
  final bool rail;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final avatar = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );

    if (rail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Tooltip(message: '$name\n$email', child: Center(child: avatar)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: c.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      S.online,
                      style: TextStyle(fontSize: 11, color: c.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.logout,
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
