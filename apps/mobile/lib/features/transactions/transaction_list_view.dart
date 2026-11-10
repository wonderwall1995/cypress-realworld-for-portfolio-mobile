import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/test_id.dart';
import 'transaction.dart';
import 'transaction_feed_controller.dart';
import 'transaction_filters.dart';
import 'transaction_widgets.dart';

/// One of the three lists. Scroll to the end to load 10 more; pull down to
/// load again from the start.
class TransactionListView extends ConsumerStatefulWidget {
  const TransactionListView({required this.feed, super.key});

  final TransactionFeed feed;

  @override
  ConsumerState<TransactionListView> createState() => _TransactionListViewState();
}

// Keeps the scroll position when the user switches tabs and comes back.
class _TransactionListViewState extends ConsumerState<TransactionListView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  TransactionFeedController get _controller =>
      ref.read(transactionFeedProvider(widget.feed).notifier);

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _controller.refresh();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: TestId('alert-bar-error', child: Text('목록을 새로 불러오지 못했습니다.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(transactionFeedProvider(widget.feed));

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: TestId(
          'transaction-list-load-error',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('거래를 불러오지 못했습니다.'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _controller.retry, child: const Text('다시 시도')),
            ],
          ),
        ),
      ),
      data: (state) => RefreshIndicator(
        onRefresh: _refresh,
        child: state.items.isEmpty ? _EmptyList(onRefresh: _refresh) : _buildList(state),
      ),
    );
  }

  Widget _buildList(FeedState state) {
    final hasFooter = state.hasNextPages;
    return TestId(
      'transaction-list',
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + (hasFooter ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            final transaction = state.items[index];
            return _TransactionTile(
              transaction: transaction,
              onTap: () => context.push('/transaction/${transaction.id}'),
            );
          }
          return _Footer(state: state, controller: _controller);
        },
      ),
    );
  }
}

class _EmptyList extends ConsumerWidget {
  const _EmptyList({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtersActive = ref.watch(transactionFiltersProvider).isActive;
    // A scroll view, so pulling down works on an empty list too.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TestId(
                  'transaction-list-empty',
                  child: Text(filtersActive ? '조건에 맞는 거래가 없습니다.' : '거래가 없습니다.'),
                ),
                const SizedBox(height: 16),
                if (filtersActive)
                  TestId(
                    'transaction-list-filter-clear-all',
                    child: OutlinedButton(
                      onPressed: ref.read(transactionFiltersProvider.notifier).clearAll,
                      child: const Text('필터 지우기'),
                    ),
                  )
                else
                  TestId(
                    'transaction-list-empty-create-transaction-button',
                    child: FilledButton(
                      onPressed: () => context.push('/transaction/new'),
                      child: const Text('거래 만들기'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The end of the list. Starts the next load when it comes into view.
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.controller});

  final FeedState state;
  final TransactionFeedController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: TestId(
            'transaction-list-load-more-error',
            child: OutlinedButton(
              onPressed: controller.loadMore,
              child: const Text('더 불러오지 못했습니다. 다시 시도'),
            ),
          ),
        ),
      );
    }
    // Start the load after this frame. The controller ignores repeated calls.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onTap});

  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return TestId(
      'transaction-item-${transaction.id}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TransactionSenderAvatar(transaction),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TransactionTitleLine(transaction),
                    const SizedBox(height: 4),
                    Text(transaction.description),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.favorite_border, size: 16, color: muted),
                        const SizedBox(width: 4),
                        TestId('transaction-like-count', child: Text('${transaction.likeCount}')),
                        const SizedBox(width: 16),
                        Icon(Icons.chat_bubble_outline, size: 16, color: muted),
                        const SizedBox(width: 4),
                        TestId('transaction-comment-count', child: Text('${transaction.commentCount}')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TransactionAmountText(transaction),
            ],
          ),
        ),
      ),
    );
  }
}
