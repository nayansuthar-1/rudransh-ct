import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primitives.dart';

/// Agent landing page. Members, dues and collections arrive in Phases 12–16.
class AgentHomePage extends StatelessWidget {
  const AgentHomePage({super.key});

  @override
  Widget build(BuildContext context) => const _PortalHome();
}

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

    return PageBody(
      maxWidth: 720,
      children: [
        SectionHeader(
          title: 'Namaste, ${user.name}',
          subtitle: '${S.trustName} · ${user.role.label}',
        ),
        const SizedBox(height: Space.xl),
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
