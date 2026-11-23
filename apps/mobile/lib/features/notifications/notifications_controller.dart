import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../money/money_status.dart';
import 'app_notification.dart';

/// The signed-in user's unread notifications.
///
/// The list is loaded when the user signs in or the app starts, when the 알림 tab
/// is opened, when the user pulls down, and while the app is in view
/// (`NotificationLiveSync`) when the server sends a new one. When nobody is
/// signed in the list is empty and the server is not called.
class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  /// The ids seen so far. A "received" notification that is not in it, after the
  /// first load, is news (notifications that were there at the start are not).
  Set<String>? _known;

  /// Pushed by the server, in order. A list that was asked for before a push does
  /// not have it yet.
  final List<AppNotification> _pushed = [];

  /// Marked as read here. A list that was asked for before that still has it.
  final Set<String> _read = {};

  /// Goes up with every load; only the newest one is shown.
  int _load = 0;

  @override
  Future<List<AppNotification>> build() async {
    _known = null;
    _pushed.clear();
    _read.clear();
    _load++;
    final userId = ref.watch(sessionProvider.select((s) => s.user?['id']));
    if (userId == null) return const [];
    return _loadList(announce: false);
  }

  void _see(List<AppNotification> list, {required bool announce}) {
    final known = _known;
    if (announce &&
        known != null &&
        list.any(
          (n) => n.kind == NotificationKind.received && !known.contains(n.id),
        )) {
      ref.read(moneyStatusProvider.notifier).changed();
    }
    (_known ??= {}).addAll(list.map((n) => n.id));
  }

  /// A notification the server pushed. Added at the top unless it is already there.
  void receive(Map<String, dynamic> json) {
    final AppNotification? notification;
    try {
      notification = readAnswer(() => AppNotification.fromJson(json));
    } on ApiException {
      return; // not in the agreed shape
    }
    if (notification == null || _read.contains(notification.id)) return;
    _pushed.add(notification);
    final current = state.value;
    if (current == null) return; // the first load adds it
    if (current.any((n) => n.id == notification!.id)) return;
    _see([notification], announce: true);
    state = AsyncData([notification, ...current]);
  }

  /// The server's list, with what happened here while it was on its way.
  Future<List<AppNotification>> _loadList({required bool announce}) async {
    final pushedBefore = _pushed.length;
    final raw = await ref.read(apiClientProvider).getNotifications();
    // A kind the app does not know is left out.
    final list = readAnswer(
      () => raw.map(AppNotification.fromJson).whereType<AppNotification>().toList(),
    );
    _see(list, announce: announce);
    final ids = {for (final n in list) n.id};
    final pushed = _pushed.skip(pushedBefore).where((n) => ids.add(n.id)).toList();
    _see(pushed, announce: true);
    return [
      for (final n in [...pushed.reversed, ...list])
        if (!_read.contains(n.id)) n,
    ];
  }

  /// Loads again without the loading state. Returns false when it failed; the
  /// old list stays then.
  Future<bool> refresh() async {
    final load = ++_load;
    try {
      final list = await _loadList(announce: true);
      if (!ref.mounted || load != _load) return true;
      state = AsyncData(list);
      return true;
    } on ApiException catch (e, stack) {
      if (!ref.mounted || load != _load) return true;
      if (!state.hasValue) state = AsyncError(e, stack);
      return false;
    }
  }

  /// Loads the first time again after an error (shows the loading state).
  Future<void> retry() async {
    final load = ++_load;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _loadList(announce: false));
    if (ref.mounted && load == _load) state = result;
  }

  /// Throws [ApiException] when the server refuses.
  Future<void> markRead(String id) async {
    try {
      await ref.read(apiClientProvider).markNotificationRead(id);
    } on ApiException catch (e) {
      // It may have been done, or be read already somewhere else.
      if (ref.mounted && e.failure != ApiFailure.notSent) unawaited(refresh());
      rethrow;
    }
    if (!ref.mounted) return;
    _read.add(id);
    state = AsyncData([...?state.value]..removeWhere((n) => n.id == id));
  }
}

/// Dropped when nobody is watching it (after sign-out), so the next user starts
/// fresh and never sees the old data.
final notificationsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      List<AppNotification>
    >(NotificationsController.new);

/// How many unread notifications there are (0 while loading or on error).
final unreadCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(notificationsProvider).value?.length ?? 0,
);
