import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import 'app_notification.dart';

/// The signed-in user's unread notifications.
///
/// There is no automatic refresh (the web has none). The list is loaded when
/// the user signs in or the app starts, when the 알림 tab is opened, and when
/// the user pulls down. When nobody is signed in the list is empty and the
/// server is not called.
class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final userId = ref.watch(sessionProvider.select((s) => s.user?['id']));
    if (userId == null) return const [];
    return _fetch();
  }

  Future<List<AppNotification>> _fetch() async {
    final raw = await ref.read(apiClientProvider).getNotifications();
    // A kind the app does not know is left out.
    return raw.map(AppNotification.fromJson).whereType<AppNotification>().toList();
  }

  /// Loads again without the loading state. Returns false when it failed; the
  /// old list stays then.
  Future<bool> refresh() async {
    try {
      state = AsyncData(await _fetch());
      return true;
    } on ApiException catch (e, stack) {
      if (!state.hasValue) state = AsyncError(e, stack);
      return false;
    }
  }

  /// Loads the first time again after an error (shows the loading state).
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
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
    AsyncNotifierProvider.autoDispose<NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);

/// How many unread notifications there are (0 while loading or on error).
final unreadCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(notificationsProvider).value?.length ?? 0,
);
