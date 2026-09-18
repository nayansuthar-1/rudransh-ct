import 'package:flutter/material.dart';

import '../../data/models/app_user.dart';
import '../l10n/strings.dart';

/// One entry in the sidebar.
class NavItem {
  const NavItem({
    required this.path,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.activeIcon,
  });

  final String path;
  final String label;
  final String sublabel;
  final IconData icon;
  final IconData activeIcon;
}

class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const dashboard = '/dashboard';
  static const members = '/members';
  static const agents = '/agents';
  static const yojna = '/yojna';
  static const closing = '/closing-payments';
  static const payments = '/payments';
  static const approvals = '/approvals';

  // Agent screens (IMPLEMENTATION_PLAN Phases 12–16).
  static const agentHome = '/agent';
  static const agentMembers = '/agent/members';
  static const agentCollections = '/agent/collections';
  static const agentDues = '/agent/dues';

  /// One closing group: `?yojna=<id>&group=<label>`.
  static const agentDuesGroup = '/agent/dues/group';

  // Member screens (Phase 15).
  static const memberHome = '/me';
  static const memberPayments = '/me/payments';

  static const nav = <NavItem>[
    NavItem(
      path: dashboard,
      label: S.dashboard,
      sublabel: S.dashboardSub,
      icon: Icons.space_dashboard_outlined,
      activeIcon: Icons.space_dashboard,
    ),
    NavItem(
      path: members,
      label: S.members,
      sublabel: S.membersSub,
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    NavItem(
      path: agents,
      label: S.agents,
      sublabel: S.agentsSub,
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge,
    ),
    NavItem(
      path: yojna,
      label: S.yojna,
      sublabel: S.yojnaSub,
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers,
    ),
    NavItem(
      path: closing,
      label: S.closingPayments,
      sublabel: S.closingPaymentsSub,
      icon: Icons.assignment_turned_in_outlined,
      activeIcon: Icons.assignment_turned_in,
    ),
    NavItem(
      path: payments,
      label: S.payments,
      sublabel: S.paymentsSub,
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
    ),
    NavItem(
      path: approvals,
      label: S.approvals,
      sublabel: S.approvalsSub,
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check,
    ),
  ];

  static NavItem itemFor(String location) {
    return nav.firstWhere(
      (n) => location.startsWith(n.path),
      orElse: () => nav.first,
    );
  }
}

/// Where each role lands, and which paths it may open.
extension RoleRoutes on UserRole {
  String get home => switch (this) {
        UserRole.owner || UserRole.staff => AppRoutes.dashboard,
        UserRole.agent => AppRoutes.agentHome,
        UserRole.member => AppRoutes.memberHome,
      };

  List<NavItem> get nav => switch (this) {
        UserRole.owner || UserRole.staff => AppRoutes.nav,
        UserRole.agent => AgentRoutes.nav,
        UserRole.member => MemberRoutes.nav,
      };

  bool canOpen(String location) {
    final agentArea = _within(location, AppRoutes.agentHome);
    final memberArea = _within(location, AppRoutes.memberHome);
    return switch (this) {
      UserRole.owner || UserRole.staff => !agentArea && !memberArea,
      UserRole.agent => agentArea,
      UserRole.member => memberArea,
    };
  }
}

/// `/me` and `/me/payments` are within `/me`; `/members` is not.
bool _within(String location, String base) =>
    location == base || location.startsWith('$base/');

class AgentRoutes {
  const AgentRoutes._();

  static const nav = <NavItem>[
    NavItem(
      path: AppRoutes.agentHome,
      label: S.home,
      sublabel: S.agentHomeSub,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    NavItem(
      path: AppRoutes.agentMembers,
      label: S.myMembers,
      sublabel: S.myMembersSub,
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    NavItem(
      path: AppRoutes.agentDues,
      label: S.dues,
      sublabel: S.duesSub,
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note,
    ),
    NavItem(
      path: AppRoutes.agentCollections,
      label: S.collections,
      sublabel: S.collectionsSub,
      icon: Icons.currency_rupee_outlined,
      activeIcon: Icons.currency_rupee,
    ),
  ];
}

class MemberRoutes {
  const MemberRoutes._();

  static const nav = <NavItem>[
    NavItem(
      path: AppRoutes.memberHome,
      label: S.home,
      sublabel: S.memberHomeSub,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    NavItem(
      path: AppRoutes.memberPayments,
      label: S.myPayments,
      sublabel: S.myPaymentsSub,
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
    ),
  ];
}
