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
/// Everyone can like it once and write comments.
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

/// Loads the detail and the lists again: the status, the counts, or the
/// balance may have changed.
Future<void> _reloadAfterChange(WidgetRef ref, String transactionId) async {
  ref.invalidate(transactionDetailProvider(transactionId));
  ref.invalidate(transactionFeedProvider);
  await ref.read(sessionProvider.notifier).refreshUser();
}

void _showMessage(BuildContext context, String text, {required bool success}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: TestId(success ? 'alert-bar-success' : 'alert-bar-error', child: Text(text)),
    ),
  );
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _busy = false;

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
    if (_busy) return;
    final id = widget.transaction.id;
    if (status == 'accepted' && !await _confirmAccept()) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).updateRequestStatus(id, status);
      if (!mounted) return;
      _showMessage(
        context,
        status == 'accepted' ? '요청을 수락했습니다.' : '요청을 거절했습니다.',
        success: true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        _showMessage(context, '이미 처리된 요청입니다.', success: false);
      } else if (e.isConnection) {
        _showMessage(context, '서버에 연결할 수 없습니다.', success: false);
      } else {
        _showMessage(context, '요청을 처리하지 못했습니다.', success: false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reloadAfterChange(ref, id);
  }

  /// One like per user. (The server would accept a second one, so the button
  /// is off after the first, like on the web.)
  Future<void> _like() async {
    // The button is off while busy, but a second tap in the same frame can still
    // get here. The server would count both likes.
    if (_busy) return;
    final id = widget.transaction.id;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).likeTransaction(id);
      await _reloadAfterChange(ref, id);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(
        context,
        e.isConnection ? '서버에 연결할 수 없습니다.' : '좋아요를 누르지 못했습니다.',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final currentUserId = ref.watch(sessionProvider.select((s) => s.user?['id'])) as String?;
    final canResolve = transaction.isPendingRequest && transaction.receiverId == currentUserId;
    final liked = transaction.isLikedBy(currentUserId);

    return Column(
      children: [
        Expanded(
          child: ListView(
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TestId(
                          'transaction-like-button-${transaction.id}',
                          child: IconButton(
                            tooltip: '좋아요',
                            onPressed: (liked || _busy) ? null : _like,
                            icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                          ),
                        ),
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
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text('댓글 ${transaction.commentCount}', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _CommentList(comments: transaction.comments),
                  ],
                ),
              ),
            ],
          ),
        ),
        _CommentInput(transactionId: transaction.id),
      ],
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({required this.comments});

  final List<TransactionComment> comments;

  /// For example `11/10 18:51`, in the phone's time zone.
  static String _time(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const TestId('comments-empty', child: Text('아직 댓글이 없습니다.'));
    }
    return TestId(
      'comments-list',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final comment in comments)
            TestId(
              'comment-list-item-${comment.id}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.content),
                    Text(
                      _time(comment.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The input line at the bottom of the screen (stays above the keyboard).
class _CommentInput extends ConsumerStatefulWidget {
  const _CommentInput({required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postComment(widget.transactionId, content);
      if (!mounted) return;
      _text.clear();
      await _reloadAfterChange(ref, widget.transactionId);
    } on ApiException catch (e) {
      if (!mounted) return;
      // The text stays, so the user can try again.
      _showMessage(
        context,
        e.isConnection ? '서버에 연결할 수 없습니다.' : '댓글을 남기지 못했습니다.',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.transactionId;
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TestId(
                  'transaction-comment-input-$id',
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: '댓글을 입력하세요...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (context, value, _) => TestId(
                  'transaction-comment-submit-$id',
                  child: IconButton(
                    tooltip: '댓글 보내기',
                    onPressed: (value.text.trim().isEmpty || _busy) ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

