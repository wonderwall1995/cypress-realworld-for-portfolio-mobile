import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/test_id.dart';
import 'transaction.dart';
import 'transaction_feed_controller.dart';
import 'transaction_widgets.dart';

/// One transaction, read only. (Like, comment, accept and reject come in later steps.)
class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const TestId('transaction-detail-header', child: Text('거래 상세')),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: TestId(
            'transaction-detail-error',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('거래를 불러오지 못했습니다.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(transactionDetailProvider(transactionId)),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (transaction) => _DetailBody(transaction: transaction),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TestId(
          'transaction-item-${transaction.id}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TestId('transaction-sender-avatar', child: InitialAvatar(transaction.senderName, radius: 28)),
                  const SizedBox(width: 8),
                  TestId('transaction-receiver-avatar', child: InitialAvatar(transaction.receiverName, radius: 28)),
                ],
              ),
              const SizedBox(height: 16),
              TransactionTitleLine(transaction),
              const SizedBox(height: 12),
              TestId(
                'transaction-description',
                child: Text(transaction.description, style: theme.textTheme.bodyLarge),
              ),
              const SizedBox(height: 16),
              TransactionAmountText(transaction, large: true),
              const SizedBox(height: 8),
              TestId('transaction-status', child: Text(transaction.statusLabel)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.favorite_border, size: 18, color: muted),
                  const SizedBox(width: 4),
                  TestId(
                    'transaction-like-count-${transaction.id}',
                    child: Text('${transaction.likeCount}'),
                  ),
                  const SizedBox(width: 20),
                  Icon(Icons.chat_bubble_outline, size: 18, color: muted),
                  const SizedBox(width: 4),
                  TestId(
                    'transaction-comment-count-${transaction.id}',
                    child: Text('${transaction.commentCount}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
