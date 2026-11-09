import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';

/// Bottom tab bar. Test ids follow the web side menu names.
///
/// The last button, "더보기" (...), opens a menu instead of a screen.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (id: 'sidenav-home', label: '홈', icon: Icons.home_outlined),
    (id: 'sidenav-notifications', label: '알림', icon: Icons.notifications_outlined),
    (id: 'sidenav-bankaccounts', label: '은행 계좌', icon: Icons.account_balance_outlined),
    (id: 'sidenav-my-account', label: '내 계좌', icon: Icons.account_balance_wallet_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index == _tabs.length) {
            _openMoreMenu(context, ref);
            return;
          }
          // The balance may have changed (a request was accepted, for example).
          if (_tabs[index].id == 'sidenav-my-account') {
            ref.read(sessionProvider.notifier).refreshUser();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final tab in _tabs)
            TestId(
              tab.id,
              child: NavigationDestination(icon: Icon(tab.icon), label: tab.label),
            ),
          const TestId(
            'sidenav-more',
            child: NavigationDestination(icon: Icon(Icons.more_horiz), label: '더보기'),
          ),
        ],
      ),
    );
  }

  void _openMoreMenu(BuildContext context, WidgetRef ref) {
    final user = ref.read(sessionProvider).user;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final username = user?['username'] as String?;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: TestId('sidenav-user-full-name', child: Text(fullName)),
              subtitle: TestId(
                'sidenav-username',
                child: Text(username == null ? '' : '@$username'),
              ),
            ),
            const Divider(height: 1),
            TestId(
              'sidenav-user-settings',
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('설정'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/settings');
                },
              ),
            ),
            TestId(
              'sidenav-signout',
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(sessionProvider.notifier).signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
