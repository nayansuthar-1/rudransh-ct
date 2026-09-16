import 'package:flutter/material.dart';

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
  ];

  static NavItem itemFor(String location) {
    return nav.firstWhere(
      (n) => location.startsWith(n.path),
      orElse: () => nav.first,
    );
  }
}
