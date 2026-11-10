import 'package:flutter/material.dart';

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

/// "Alice Test → Bob Test  [결제]". Test ids follow the web names.
class TransactionTitleLine extends StatelessWidget {
  const TransactionTitleLine(this.transaction, {super.key});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final id = transaction.id;
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.titleSmall;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        TestId('transaction-sender-$id', child: Text(transaction.senderName, style: nameStyle)),
        const Text('→'),
        TestId('transaction-receiver-$id', child: Text(transaction.receiverName, style: nameStyle)),
        TestId(
          'transaction-action-$id',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transaction.actionLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "+$7.00" in green for a request, "-$20.00" in red for a payment (same rule
/// as the web, which colors by type and not by who the user is). An external
/// deposit is money coming in, so it is "+" and green.
class TransactionAmountText extends StatelessWidget {
  const TransactionAmountText(this.transaction, {this.large = false, super.key});

  final Transaction transaction;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = large ? Theme.of(context).textTheme.headlineSmall : Theme.of(context).textTheme.titleMedium;
    final incoming = transaction.isRequest || transaction.isExternalDeposit;
    return TestId(
      'transaction-amount-${transaction.id}',
      child: Text(
        '${incoming ? '+' : '-'}${formatUsd(transaction.amount)}',
        style: style?.copyWith(
          color: incoming ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
