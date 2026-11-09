import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_widgets.dart';

/// The "내 계좌" tab: who the user is and how much is in the account.
/// Pull down to load the balance again. (Deposit and withdraw come in step 7.)
class MyAccountPage extends ConsumerWidget {
  const MyAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final username = user?['username'] as String?;
    final balance = (user?['balance'] as num?)?.toInt() ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('내 계좌')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(sessionProvider.notifier).refreshUser(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                InitialAvatar(fullName, radius: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TestId(
                        'my-account-full-name',
                        child: Text(fullName, style: theme.textTheme.titleMedium),
                      ),
                      TestId(
                        'my-account-username',
                        child: Text(username == null ? '' : '@$username'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 계좌 잔액', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TestId(
                      'sidenav-user-balance',
                      child: Text(formatUsd(balance), style: theme.textTheme.headlineMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
