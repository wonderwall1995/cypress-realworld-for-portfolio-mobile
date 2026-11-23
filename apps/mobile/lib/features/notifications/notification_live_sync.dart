import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../money/money_status.dart';
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
/// [livePollIntervalProvider] instead.
const liveMaxFailures = 3;

/// After this many answered polls the stream is tried again (6 x 10 seconds).
const livePollsBeforeRetry = 6;

/// Keeps the notifications fresh while the app is in view, and only then.
///
/// It opens the server's stream (`GET /notifications/stream`). Each time it is
/// connected, the list is read once to catch up (nothing is replayed), and every
/// event adds a notification at once. When the stream keeps failing it asks for
/// the list every 10 seconds instead, and while that works it tries the stream again
/// once a minute (the server may have been started again). When the app goes to the background, both
/// stop; when it comes back they start again, and the money is read once: it can
/// have changed without an unread notification (a deposit on another device, or a
/// notification that was read on the web). When the sign-in is over, everything
/// stops. Nothing else polls.
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

  /// Really out of view, not just covered for a moment.
  bool _wasHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _start();
        if (_wasHidden) ref.read(moneyStatusProvider.notifier).refresh();
        _wasHidden = false;
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _wasHidden = true;
        _stop();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
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
    } on ApiException catch (e) {
      // The sign-in is over: the session closes this screen. Do not knock again.
      if (e.statusCode == 401) return;
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
    var answered = 0;
    Future<void> tick() async {
      if (!_current(generation)) return;
      final ok = await ref.read(notificationsProvider.notifier).refresh();
      if (!ok || !_current(generation)) return;
      if (++answered <= livePollsBeforeRetry) return;
      // One more failure, and it polls again.
      _timer?.cancel();
      _failures = liveMaxFailures - 1;
      unawaited(_connect(generation));
    }

    tick();
    _timer = Timer.periodic(ref.read(livePollIntervalProvider), (_) => tick());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
