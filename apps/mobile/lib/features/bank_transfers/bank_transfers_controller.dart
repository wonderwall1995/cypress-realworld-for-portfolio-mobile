import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import 'bank_transfer.dart';

/// The signed-in user's bank transfers, newest first.
///
/// Dropped when nobody is watching it (after sign-out), so the next user starts
/// fresh. When nobody is signed in the list is empty and the server is not called.
class BankTransfersController extends AsyncNotifier<List<BankTransfer>> {
  @override
  Future<List<BankTransfer>> build() async {
    final userId = ref.watch(sessionProvider.select((s) => s.user?['id']));
    if (userId == null) return const [];
    return _fetch();
  }

  Future<List<BankTransfer>> _fetch() async {
    final raw = await ref.read(apiClientProvider).getBankTransfers();
    final list = raw.map(BankTransfer.fromJson).toList();
    // Newest first. A missing time goes last.
    list.sort((a, b) {
      final ta = a.createdAt, tb = b.createdAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return list;
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

  /// Loads again after an error (shows the loading state).
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final bankTransfersProvider =
    AsyncNotifierProvider.autoDispose<BankTransfersController, List<BankTransfer>>(
  BankTransfersController.new,
);
