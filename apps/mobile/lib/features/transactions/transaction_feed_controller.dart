import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import 'transaction.dart';
import 'transaction_filters.dart';

/// The two lists on the home screen (same as the web tabs).
enum TransactionFeed {
  everyone('/transactions/public', 'nav-public-tab', '전체'),
  mine('/transactions', 'nav-personal-tab', '내 거래');

  const TransactionFeed(this.path, this.tabId, this.label);

  final String path;

  /// The web `data-testid` of the tab.
  final String tabId;
  final String label;
}

class FeedState {
  const FeedState({
    this.items = const [],
    this.page = 0,
    this.hasNextPages = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Transaction> items;
  final int page;
  final bool hasNextPages;
  final bool loadingMore;
  final bool loadMoreFailed;

  FeedState copyWith({bool? loadingMore, bool? loadMoreFailed}) => FeedState(
        items: items,
        page: page,
        hasNextPages: hasNextPages,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// One transaction list. Loads 10 at a time (the server's page size).
/// Loads again when the signed-in user changes; when nobody is signed in the
/// list is empty and the server is not called.
class TransactionFeedController extends AsyncNotifier<FeedState> {
  TransactionFeedController(this.feed);

  final TransactionFeed feed;
  static const _limit = 10;

  /// Goes up with every load from the start (another user, other filters, a
  /// refresh). An answer that belongs to an earlier number is dropped.
  int _load = 0;

  @override
  Future<FeedState> build() async {
    _load++;
    final userId = ref.watch(sessionProvider.select((s) => s.user?['id']));
    // New filters load the list again from the start.
    ref.watch(transactionFiltersProvider);
    if (userId == null) return const FeedState();
    return _fetchFirstPage();
  }

  Future<FeedState> _fetchFirstPage() async {
    final result = await ref
        .read(apiClientProvider)
        .getTransactions(
          feed.path,
          page: 1,
          limit: _limit,
          filters: ref.read(transactionFiltersProvider).toQuery(),
        );
    return FeedState(
      items: readAnswer(() => result.results.map(Transaction.fromJson).toList()),
      page: 1,
      hasNextPages: result.hasNextPages,
    );
  }

  /// Pull to refresh. Returns false when it failed; the old list stays then.
  Future<bool> refresh() async {
    final load = ++_load;
    try {
      final fresh = await _fetchFirstPage();
      // A newer load took over; its result is what the screen shows.
      if (!ref.mounted || load != _load) return true;
      state = AsyncData(fresh);
      return true;
    } on ApiException catch (e, stack) {
      if (!ref.mounted || load != _load) return true;
      final old = state.value;
      // A next page that was on its way has been dropped.
      state = old == null ? AsyncError(e, stack) : AsyncData(old.copyWith(loadingMore: false));
      return false;
    }
  }

  /// Loads the first page again after an error (shows the loading state).
  Future<void> retry() async {
    final load = ++_load;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_fetchFirstPage);
    if (ref.mounted && load == _load) state = result;
  }

  /// Loads the next 10. Does nothing while one is loading or when there is no more.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNextPages || current.loadingMore) return;

    final load = _load;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final result = await ref
          .read(apiClientProvider)
          .getTransactions(
            feed.path,
            page: current.page + 1,
            limit: _limit,
            filters: ref.read(transactionFiltersProvider).toQuery(),
          );
      final more = readAnswer(() => result.results.map(Transaction.fromJson).toList());
      if (!ref.mounted || load != _load) return;
      // A transaction made in the meantime moves the pages by one, so the last one
      // of this page can come again.
      final known = {for (final t in current.items) t.id};
      state = AsyncData(
        FeedState(
          items: [...current.items, ...more.where((t) => known.add(t.id))],
          page: current.page + 1,
          hasNextPages: result.hasNextPages,
        ),
      );
    } on ApiException {
      if (!ref.mounted || load != _load) return;
      state = AsyncData(current.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}

final transactionFeedProvider = AsyncNotifierProvider.family<
    TransactionFeedController, FeedState, TransactionFeed>(
  TransactionFeedController.new,
);

/// One transaction for the detail screen. Loaded when the screen opens, and again
/// for another user (who may not be allowed to see it).
final transactionDetailProvider =
    FutureProvider.autoDispose.family<Transaction, String>((ref, id) async {
  ref.watch(sessionProvider.select((s) => s.user?['id']));
  final json = await ref.watch(apiClientProvider).getTransaction(id);
  return readAnswer(() => Transaction.fromJson(json));
});
