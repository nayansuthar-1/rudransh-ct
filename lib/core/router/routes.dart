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
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    NavItem(
      path: members,
      label: S.members,
      sublabel: S.membersSub,
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
    ),
    NavItem(
      path: agents,
      label: S.agents,
      sublabel: S.agentsSub,
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
    ),
    NavItem(
      path: yojna,
      label: S.yojna,
      sublabel: S.yojnaSub,
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
    ),
    NavItem(
      path: closing,
      label: S.closingPayments,
      sublabel: S.closingPaymentsSub,
      icon: Icons.credit_card_outlined,
      activeIcon: Icons.credit_card,
    ),
    NavItem(
      path: payments,
      label: S.payments,
      sublabel: S.paymentsSub,
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
    ),
  ];

  static NavItem itemFor(String location) {
    return nav.firstWhere(
      (n) => location.startsWith(n.path),
      orElse: () => nav.first,
    );
  }
}
