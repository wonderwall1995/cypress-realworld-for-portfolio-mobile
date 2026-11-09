import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/test_id.dart';

/// Bottom tab bar. Test ids follow the web side menu names.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (id: 'sidenav-home', label: '홈', icon: Icons.home_outlined),
    (id: 'sidenav-notifications', label: '알림', icon: Icons.notifications_outlined),
    (id: 'sidenav-bankaccounts', label: '은행 계좌', icon: Icons.account_balance_outlined),
    (id: 'sidenav-user-settings', label: '설정', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final tab in _tabs)
            TestId(
              tab.id,
              child: NavigationDestination(icon: Icon(tab.icon), label: tab.label),
            ),
        ],
      ),
    );
  }
}
