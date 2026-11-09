import '../../core/header_credit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/test_id.dart';
import 'app_notification.dart';
import 'notifications_controller.dart';

/// The "알림" tab: unread notifications. Each one has a "읽음" button; tapping
/// the row opens the transaction (and does not mark it read).
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(notificationsProvider.notifier).refresh();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: TestId('alert-bar-error', child: Text('알림을 새로 불러오지 못했습니다.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('알림'), actions: const [HeaderCredit()]),
      body: notifications.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: TestId(
            'notifications-load-error',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('알림을 불러오지 못했습니다.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.read(notificationsProvider.notifier).retry(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: list.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: const Center(
                        child: TestId('notifications-empty', child: Text('새 알림이 없습니다.')),
                      ),
                    ),
                  ),
                )
              : TestId(
                  'notifications-list',
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _NotificationTile(notification: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

IconData _iconFor(NotificationKind kind) => switch (kind) {
      NotificationKind.requested => Icons.request_page_outlined,
      NotificationKind.received => Icons.payments_outlined,
      NotificationKind.like => Icons.favorite_border,
      NotificationKind.comment => Icons.chat_bubble_outline,
    };

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  Future<void> _markRead(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationsProvider.notifier).markRead(notification.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: TestId(
            'alert-bar-error',
            child: Text(e.isConnection ? '서버에 연결할 수 없습니다.' : '읽음 처리하지 못했습니다.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TestId(
      'notification-list-item-${notification.id}',
      child: ListTile(
        leading: Icon(_iconFor(notification.kind)),
        title: Text(notification.message),
        onTap: () => context.push('/transaction/${notification.transactionId}'),
        trailing: TestId(
          'notification-mark-read-${notification.id}',
          child: TextButton(
            onPressed: () => _markRead(context, ref),
            child: const Text('읽음'),
          ),
        ),
      ),
    );
  }
}
