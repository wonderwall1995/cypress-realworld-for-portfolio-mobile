import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/test_id.dart';
import 'transaction.dart';
import 'transaction_feed_controller.dart';
import 'transaction_widgets.dart';

/// One transaction. The receiver of a pending request can accept or reject it.
/// (Like and comment come in a later step.)
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
        skipLoadingOnReload: true,
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

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _busy = false;

  void _showMessage(String text, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TestId(success ? 'alert-bar-success' : 'alert-bar-error', child: Text(text)),
      ),
    );
  }

  Future<bool> _confirmAccept() async {
    final t = widget.transaction;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('요청 수락'),
        content: Text('${t.senderName}님에게 ${formatUsd(t.amount)}를 보냅니다. 수락하시겠습니까?'),
        actions: [
          TestId(
            'transaction-accept-cancel',
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
          ),
          TestId(
            'transaction-accept-confirm',
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('수락'),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// [status] is `accepted` or `rejected`. Accept asks first (money moves).
  Future<void> _resolve(String status) async {
    final id = widget.transaction.id;
    if (status == 'accepted' && !await _confirmAccept()) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).updateRequestStatus(id, status);
      _showMessage(status == 'accepted' ? '요청을 수락했습니다.' : '요청을 거절했습니다.', success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        _showMessage('이미 처리된 요청입니다.', success: false);
      } else if (e.isConnection) {
        _showMessage('서버에 연결할 수 없습니다.', success: false);
      } else {
        _showMessage('요청을 처리하지 못했습니다.', success: false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    // Load again: the status, the lists, and the balance may have changed.
    ref.invalidate(transactionDetailProvider(id));
    ref.invalidate(transactionFeedProvider);
    await ref.read(sessionProvider.notifier).refreshUser();
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final currentUserId = ref.watch(sessionProvider.select((s) => s.user?['id']));
    final canResolve = transaction.isPendingRequest && transaction.receiverId == currentUserId;

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
              if (canResolve) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TestId(
                        'transaction-reject-request-${transaction.id}',
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _resolve('rejected'),
                          child: const Text('거절'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TestId(
                        'transaction-accept-request-${transaction.id}',
                        child: FilledButton(
                          onPressed: _busy ? null : () => _resolve('accepted'),
                          child: const Text('수락'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
