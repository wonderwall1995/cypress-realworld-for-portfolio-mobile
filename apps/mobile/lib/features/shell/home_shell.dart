import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';
import '../notifications/notifications_controller.dart';

/// The red number on the 알림 icon: how many notifications are unread.
///
/// It sits on top of the tab bar, as its own element. (Inside the tab it would
/// be merged into the tab description and could not be found by its test id.)
class _UnreadBadgeOverlay extends ConsumerWidget {
  const _UnreadBadgeOverlay({required this.tabIndex, required this.tabCount});

  final int tabIndex;
  final int tabCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);
    if (count == 0) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The tabs share the width equally. Put the badge at the top right of the icon.
        final centerX = constraints.maxWidth / tabCount * (tabIndex + 0.5);
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: centerX + 4, top: 8),
            child: TestId(
              'nav-top-notifications-count',
              // No `alignment` here: it would make the box as big as the bar.
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(color: colors.onError, fontSize: 11, height: 1.2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
      bottomNavigationBar: Stack(
        children: [
          NavigationBar(
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
              // New notifications may have come in. (There is no automatic refresh.)
              if (_tabs[index].id == 'sidenav-notifications') {
                ref.read(notificationsProvider.notifier).refresh();
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
          // The unread number, on top of the 알림 tab. Taps go to the tab below;
          // the meaning (semantics) stays, so a test can find it by its id.
          Positioned.fill(
            child: IgnorePointer(
              child: _UnreadBadgeOverlay(
                tabIndex: _tabs.indexWhere((t) => t.id == 'sidenav-notifications'),
                tabCount: _tabs.length + 1, // the tabs and the ... button
              ),
            ),
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
              'sidenav-about',
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('앱 정보'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/about');
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
