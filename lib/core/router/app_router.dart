import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';

import '../../features/agent/agent_dues.dart';
import '../../features/agent/agent_pages.dart';
import '../../features/agents/agents_page.dart';
import '../../features/approvals/approvals_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/closing/closing_payments_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/members/members_page.dart';
import '../../features/payments/payments_page.dart';
import '../../features/portal/portal_pages.dart';
import '../../features/yojna/yojna_page.dart';
import '../../state/auth_controller.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/role_shell.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bridges auth state changes into go_router's refresh mechanism.
  final refresh = ValueNotifier<String>(
    _routingKey(ref.read(authControllerProvider)),
  );
  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => refresh.value = _routingKey(next),
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(authControllerProvider), state.matchedLocation),
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
          _shellRoute(AppRoutes.approvals, const ApprovalsPage()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => RoleShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          _shellRoute(AppRoutes.agentHome, const AgentHomePage()),
          _shellRoute(AppRoutes.agentMembers, const AgentMembersPage()),
          _shellRoute(AppRoutes.agentCollections, const AgentCollectionsPage()),
          _shellRoute(AppRoutes.agentDues, const AgentDuesPage()),
          GoRoute(
            path: AppRoutes.agentDuesGroup,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: AgentGroupDuesPage(
                yojnaId: state.uri.queryParameters['yojna'] ?? '',
                closingGroup: state.uri.queryParameters['group'] ?? '',
              ),
            ),
          ),
          _shellRoute(AppRoutes.memberHome, const MemberHomePage()),
          _shellRoute(
            AppRoutes.memberPayments,
            const ComingSoonPage(item: AppRoutes.memberPayments),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouteError(message: '${state.error}'),
  );
});

/// Signed out → login. Signed in → the role's own screens only; anything
/// else sends them to their home. While a restored session's access is being
/// checked nothing moves, so a reload stays on the same page.
@visibleForTesting
String? redirectFor(AuthState auth, String location) {
  final atLogin = location == AppRoutes.login;
  if (!auth.isSignedIn) return atLogin ? null : AppRoutes.login;
  if (auth.checkingAccess) return null;

  final role = auth.user?.role ?? UserRole.member;
  if (atLogin || !role.canOpen(location)) return role.home;
  return null;
}

String _routingKey(AuthState auth) =>
    '${auth.isSignedIn}|${auth.checkingAccess}|${auth.user?.role.name}';

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
                onPressed: () => GoRouter.of(context).go(AppRoutes.login),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
