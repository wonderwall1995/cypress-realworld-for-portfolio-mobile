import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';
import 'transaction.dart';

/// A round avatar with the first letter of the name. (The server sends no
/// avatar image yet.)
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {this.radius = 20, super.key});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return CircleAvatar(radius: radius, child: Text(initial));
  }
}

/// The avatar of the sender of a transaction: the first letter of the name, or a
/// bank icon for an external deposit (it has no real sender, so no letter).
class TransactionSenderAvatar extends StatelessWidget {
  const TransactionSenderAvatar(this.transaction, {this.radius = 20, super.key});

  final Transaction transaction;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!transaction.isExternalDeposit) return InitialAvatar(transaction.senderName, radius: radius);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      child: Icon(
        Icons.account_balance,
        size: radius,
        color: Theme.of(context).colorScheme.onTertiaryContainer,
      ),
    );
  }
}

/// "Test Bank 계좌로 입금 되었습니다." / "Test Bank 계좌에서 출금 되었습니다."
///
/// "입금" is green and "출금" is red. The bank name shrinks with an ellipsis when
/// it is too long for the line. When the bank is not known, it says only
/// "은행 계좌로".
class BankMoveSentence extends StatelessWidget {
  const BankMoveSentence({required this.id, this.bankName, this.deposit = true, super.key});

  /// The id of the transaction, for the test ids.
  final String id;
  final String? bankName;
  final bool deposit;

  /// The bank as the web says it: "국민" -> "국민 은행"; a name that already ends with
  /// 은행 or Bank stays as typed.
  static String bankDisplayName(String name) {
    final text = name.trim();
    return RegExp(r'(은행|bank)$', caseSensitive: false).hasMatch(text) ? text : '$text 은행';
  }

  /// Only the first [maxLength] characters of a long bank name are shown, then "…".
  static const maxBankNameLength = 14;
  static String clipBankName(String name) {
    final text = name.trim();
    final chars = text.characters;
    return chars.length <= maxBankNameLength ? text : '${chars.take(maxBankNameLength)}…';
  }

  /// "국민은행" already says 은행, so it is not said twice. A deposit goes
  /// "계좌로" (to the account), a withdrawal "계좌에서" (from the account).
  static String bankLabel(String? name, {bool deposit = true}) {
    final tail = deposit ? '계좌로' : '계좌에서';
    final text = name?.trim() ?? '';
    if (text.isEmpty) return '은행 $tail';
    final lower = text.toLowerCase();
    final saysBank = text.endsWith('은행') || lower.endsWith('bank');
    return saysBank ? '$text $tail' : '$text 은행 $tail';
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final word = deposit ? '입금' : '출금';
    final color = deposit ? Colors.green.shade700 : Colors.red.shade700;
    final label = bankLabel(bankName, deposit: deposit);
    // The last words of the label ("계좌로", "계좌에서") must stay; only the name is cut.
    final tail = deposit ? ' 계좌로' : ' 계좌에서';
    // The name as the screen says it ("국민 은행"), cut to 14 characters.
    final name = clipBankName(label.substring(0, label.length - tail.length));
    return TestId(
      'transaction-bank-sentence-$id',
      // Wrap, not Row: a short line goes on to a second line instead of overflowing.
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: TestId(
                'transaction-bank-name-$id',
                child: Text(name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            Text(tail, style: style),
            const SizedBox(width: 4),
            TestId(
              'transaction-bank-move-$id',
              child: Text(word, style: style?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ),
            Text(' 되었습니다.', style: style),
          ],
        ),
      ),
    );
  }
}

/// "국민은행 남은 잔액 $70.00", under the amount. The bank name gets an ellipsis
/// when it is long; the words and the number stay.
class BankBalanceText extends StatelessWidget {
  const BankBalanceText({required this.id, required this.bankName, required this.balanceAfter, super.key});

  final String id;
  final String bankName;

  /// In cents.
  final int balanceAfter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return TestId(
      'transaction-balance-$id',
      // Wrap, not Row: when the room is short, the words go to a second line
      // instead of running out of the screen. The bank name gets an ellipsis.
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: TestId(
                'transaction-balance-bank-$id',
                child: Text(BankMoveSentence.clipBankName(BankMoveSentence.bankDisplayName(bankName)), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            TestId(
              'transaction-balance-amount-$id',
              child: Text(' 남은 잔액 ${formatUsd(balanceAfter)}', style: style),
            ),
          ],
        ),
      ),
    );
  }
}

/// The headline of a transaction: "Alice Test님이 Bob Test님에게 이체했습니다".
/// An external deposit is just "외부 입금". (An old request still in the list reads
/// "요청했습니다" or "청구했습니다".)
class TransactionTitleLine extends StatelessWidget {
  const TransactionTitleLine(this.transaction, {super.key});

  final Transaction transaction;

  /// The sentence, for tests and for the screen.
  static String sentence(Transaction t) {
    if (t.isExternalDeposit) return t.senderName;
    final verb = t.isPayment ? '이체' : (t.isAcceptedRequest ? '청구' : '요청');
    return '${t.senderName}님이 ${t.receiverName}님에게 $verb했습니다';
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    final id = transaction.id;
    return TestId(
      transaction.isExternalDeposit ? 'transaction-sender-$id' : 'transaction-title-$id',
      // The whole names, never shortened by the app; a very long sentence ends with …
      child: Text(sentence(transaction), style: style, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}

/// The amount as the signed-in user sees it (the same rule as the web):
///  - money I received: green "+$30.00"
///  - money I paid: red "-$30.00"
///  - a request that did not move money yet (waiting, or rejected): grey, with the
///    sign it would have
///  - someone else's transaction: grey, no sign
class TransactionAmountText extends ConsumerWidget {
  const TransactionAmountText(this.transaction, {this.large = false, super.key});

  final Transaction transaction;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider.select((s) => s.user?['id'])) as String?;
    final theme = Theme.of(context);
    final style = large ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium;
    final received = transaction.receivedBy(me);
    final color = received == null || !transaction.moneyMoved
        ? theme.colorScheme.onSurfaceVariant
        : received
            ? Colors.green.shade700
            : Colors.red.shade700;
    final sign = received == null ? '' : (received ? '+' : '-');
    return TestId(
      'transaction-amount-${transaction.id}',
      child: Text(
        '$sign${formatUsd(transaction.amount)}',
        style: style?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
