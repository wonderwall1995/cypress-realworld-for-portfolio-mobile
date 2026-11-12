import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/test_id.dart';
import '../bank_accounts/bank_accounts_controller.dart';
import '../transactions/transaction_feed_controller.dart';
import 'notifications_controller.dart';

/// Whether the live connection is used at all. (Widget tests turn it off, so no
/// timer or open stream is left behind; the live tests turn it on.)
final liveNotificationsEnabledProvider = Provider<bool>((_) => true);

/// How long to wait before opening the stream again after it closed or failed.
final liveReconnectDelayProvider = Provider<Duration>(
  (_) => const Duration(seconds: 5),
);

/// How often to ask for notifications when the stream does not work.
final livePollIntervalProvider = Provider<Duration>(
  (_) => const Duration(seconds: 10),
);

/// After this many failed connections in a row the app asks every
/// [livePollIntervalProvider] instead, until it is in view again.
const liveMaxFailures = 3;

/// Keeps the notifications fresh while the app is in view, and only then.
///
/// It opens the server's stream (`GET /notifications/stream`). Each time it is
/// connected, the list is read once to catch up (nothing is replayed), and every
/// event adds a notification at once. When the stream keeps failing it asks for
/// the list every 10 seconds instead. When the app goes to the background, both
/// stop; when it comes back they start again. Nothing else polls.
class NotificationLiveSync extends ConsumerStatefulWidget {
  const NotificationLiveSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationLiveSync> createState() =>
      _NotificationLiveSyncState();
}

class _NotificationLiveSyncState extends ConsumerState<NotificationLiveSync>
    with WidgetsBindingObserver {
  int _generation = 0;
  CancelToken? _cancel;
  Timer? _timer;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  void _stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _cancel?.cancel();
    _cancel = null;
  }

  void _start() {
    if (!ref.read(liveNotificationsEnabledProvider)) return;
    _stop();
    _failures = 0;
    _connect(_generation);
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> _connect(int generation) async {
    if (!_current(generation)) return;
    final cancel = _cancel = CancelToken();
    try {
      final stream = ref
          .read(apiClientProvider)
          .openNotificationStream(
            cancelToken: cancel,
            onOpen: () {
              if (!_current(generation)) return;
              _failures = 0;
              // Nothing is replayed, so read what came while we were not connected.
              ref.read(notificationsProvider.notifier).refresh();
            },
          );
      await for (final json in stream) {
        if (!_current(generation)) break;
        ref.read(notificationsProvider.notifier).receive(json);
      }
    } catch (_) {
      // Closed or failed: handled the same way below.
    }
    if (!_current(generation)) return;
    _failures++;
    if (_failures >= liveMaxFailures) {
      _poll(generation);
    } else {
      _timer = Timer(
        ref.read(liveReconnectDelayProvider),
        () => _connect(generation),
      );
    }
  }

  void _poll(int generation) {
    void tick() {
      if (_current(generation)) {
        ref.read(notificationsProvider.notifier).refresh();
      }
    }

    tick();
    _timer = Timer.periodic(ref.read(livePollIntervalProvider), (_) => tick());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Reads the account, the bank accounts and the transaction list again, and hides
/// the notice. (The same three things the web's refresh button reads.)
Future<void> refreshMoney(WidgetRef ref) async {
  ref.read(moneyNoticeProvider.notifier).clear();
  ref.invalidate(transactionFeedProvider);
  await Future.wait([
    ref.read(sessionProvider.notifier).refreshUser(),
    ref.read(bankAccountsProvider.notifier).reload(),
  ]);
}

/// "금액 변동이 생겼어요. 새로고침을 해주세요." with a 새로고침 button. It shows only
/// when a new "received" notification came in after the app was opened.
class MoneyChangeNotice extends ConsumerWidget {
  const MoneyChangeNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(moneyNoticeProvider)) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return TestId(
      'money-change-notice',
      child: Material(
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '금액 변동이 생겼어요. 새로고침을 해주세요.',
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ),
              TestId(
                'money-change-refresh',
                child: TextButton(
                  onPressed: () => refreshMoney(ref),
                  child: const Text('새로고침'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
