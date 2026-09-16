import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
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

  static const expandedWidth = 244.0;
  static const railWidth = 64.0;

  bool get _isRail => mode == SidebarMode.rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);

    return Container(
      width: _isRail ? railWidth : expandedWidth,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: mode == SidebarMode.drawer
            ? null
            : Border(right: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 64, child: _brand(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  _isRail ? Space.md : Space.md,
                  Space.xs,
                  _isRail ? Space.md : Space.md,
                  Space.md,
                ),
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
    const mark = BrandMark(size: 30);

    if (_isRail) return const Center(child: mark);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg + Space.xs),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 10),
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
        ],
      ),
    );
  }

  Widget _groupLabel(BuildContext context, String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: c.textMuted,
        ),
      ),
    );
  }
}

/// Square monogram used in the sidebar, top bar and login screen.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.brand,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Text(
        'R',
        style: TextStyle(
          color: c.onBrand,
          fontSize: size * 0.54,
          fontWeight: FontWeight.w700,
          height: 1,
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
    final fg = selected ? c.onBrandSoft : c.textSecondary;
    final icon = Icon(
      selected ? item.activeIcon : item.icon,
      size: 20,
      color: fg,
    );

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? c.brandSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: onTap,
          hoverColor: selected ? Colors.transparent : c.hover,
          child: SizedBox(
            height: 40,
            child: rail
                ? Center(child: icon)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                    child: Row(
                      children: [
                        icon,
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );

    return rail
        ? Tooltip(
            message: item.label,
            waitDuration: Duration.zero,
            child: tile,
          )
        : tile;
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

    if (rail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: IconButton(
            tooltip: '${S.logout} ($email)',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg + Space.xs, Space.md, Space.sm, Space.md),
      child: Row(
        children: [
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
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.logout,
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}
