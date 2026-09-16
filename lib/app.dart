import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'state/auth_controller.dart';
import 'state/providers.dart';
import 'widgets/app_sidebar.dart';

class RudranshAdminApp extends ConsumerWidget {
  const RudranshAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final checking = ref.watch(
      authControllerProvider.select((s) => s.checkingAccess),
    );

    return MaterialApp.router(
      title: '${S.appName} · ${S.appSubtitle}',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      scrollBehavior: const _AppScrollBehavior(),
      // A restored session waits for its role before any page opens.
      builder: (context, child) =>
          checking ? const _AccessCheckSplash() : child ?? const SizedBox(),
    );
  }
}

class _AccessCheckSplash extends ConsumerWidget {
  const _AccessCheckSplash();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final error = ref.watch(authControllerProvider.select((s) => s.error));
    final auth = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: c.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 36),
              const SizedBox(height: Space.xl),
              if (error == null) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: Space.md),
                Text(
                  S.checkingAccess,
                  style: TextStyle(color: c.textSecondary),
                ),
              ] else ...[
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary),
                ),
                const SizedBox(height: Space.lg),
                Wrap(
                  spacing: Space.sm,
                  children: [
                    OutlinedButton(
                      onPressed: auth.signOut,
                      child: const Text(S.logout),
                    ),
                    FilledButton(
                      onPressed: auth.retryAccessCheck,
                      child: const Text(S.retry),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets desktop users drag-scroll lists with a mouse, which Flutter web
/// disables by default.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
