import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import 'app_notification.dart';

/// Whether a new money notice should be shown ("금액 변동이 생겼어요. 새로고침을
/// 해주세요."). Turned on when a new "received" notification arrives after the
/// first load; turned off by the refresh button.
class MoneyNoticeController extends Notifier<bool> {
  @override
  bool build() {
    // Another user (or nobody) starts without a notice.
    ref.watch(sessionProvider.select((s) => s.user?['id']));
    return false;
  }

  void show() => state = true;

  void clear() => state = false;
}

final moneyNoticeProvider = NotifierProvider<MoneyNoticeController, bool>(
  MoneyNoticeController.new,
);

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

  @override
  Future<List<AppNotification>> build() async {
    _known = null;
    final userId = ref.watch(sessionProvider.select((s) => s.user?['id']));
    if (userId == null) return const [];
    final list = await _fetch();
    _see(list, announce: false);
    return list;
  }

  void _see(List<AppNotification> list, {required bool announce}) {
    final known = _known;
    if (announce &&
        known != null &&
        list.any(
          (n) => n.kind == NotificationKind.received && !known.contains(n.id),
        )) {
      ref.read(moneyNoticeProvider.notifier).show();
    }
    (_known ??= {}).addAll(list.map((n) => n.id));
  }

  /// A notification the server pushed. Added at the top unless it is already there.
  void receive(Map<String, dynamic> json) {
    final notification = AppNotification.fromJson(json);
    final current = state.value;
    if (notification == null || current == null) return;
    if (current.any((n) => n.id == notification.id)) return;
    _see([notification], announce: true);
    state = AsyncData([notification, ...current]);
  }

  Future<List<AppNotification>> _fetch() async {
    final raw = await ref.read(apiClientProvider).getNotifications();
    // A kind the app does not know is left out.
    return raw
        .map(AppNotification.fromJson)
        .whereType<AppNotification>()
        .toList();
  }

  /// Loads again without the loading state. Returns false when it failed; the
  /// old list stays then.
  Future<bool> refresh() async {
    try {
      final list = await _fetch();
      _see(list, announce: true);
      state = AsyncData(list);
      return true;
    } on ApiException catch (e, stack) {
      if (!state.hasValue) state = AsyncError(e, stack);
      return false;
    }
  }

  /// Loads the first time again after an error (shows the loading state).
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final list = await _fetch();
      _see(list, announce: false);
      return list;
    });
  }

  /// Throws [ApiException] when the server refuses.
  Future<void> markRead(String id) async {
    await ref.read(apiClientProvider).markNotificationRead(id);
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
