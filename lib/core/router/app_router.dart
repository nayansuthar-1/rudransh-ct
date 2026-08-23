import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agents/agents_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/closing/closing_payments_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/members/members_page.dart';
import '../../features/payments/payments_page.dart';
import '../../features/yojna/yojna_page.dart';
import '../../state/auth_controller.dart';
import '../../widgets/app_shell.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bridges auth state changes into go_router's refresh mechanism.
  final refresh = ValueNotifier<bool>(
    ref.read(authControllerProvider).isSignedIn,
  );
  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => refresh.value = next.isSignedIn,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(authControllerProvider).isSignedIn;
      final atLogin = state.matchedLocation == AppRoutes.login;
      if (!signedIn && !atLogin) return AppRoutes.login;
      if (signedIn && atLogin) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          _shellRoute(AppRoutes.dashboard, const DashboardPage()),
          _shellRoute(AppRoutes.members, const MembersPage()),
          _shellRoute(AppRoutes.agents, const AgentsPage()),
          _shellRoute(AppRoutes.yojna, const YojnaPage()),
          _shellRoute(AppRoutes.closing, const ClosingPaymentsPage()),
          _shellRoute(AppRoutes.payments, const PaymentsPage()),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouteError(message: '${state.error}'),
  );
});

GoRoute _shellRoute(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage(child: child),
  );
}

class _RouteError extends StatelessWidget {
  const _RouteError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => GoRouter.of(context).go(AppRoutes.dashboard),
                child: const Text('Back to dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
