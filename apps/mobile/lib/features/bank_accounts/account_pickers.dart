import 'package:flutter/material.dart';

import '../../core/test_id.dart';
import '../transactions/transaction.dart';
import 'bank_account.dart';
import 'other_account.dart';

/// One line of a picker: the bank, the last 4 digits, and the balance on the right
/// (only for the user's own accounts).
///
/// Only the bank NAME is cut with "…" when the line is too short; the digits and the
/// balance are always whole. The balance goes to a second line when it has to.
class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.id, required this.bankName, required this.last4, this.balance, this.canSend = false});

  final String id;
  final String bankName;
  final String last4;

  /// In cents.
  final int? balance;

  /// The balance is green: there is money to send, and enough of it.
  final bool canSend;

  @override
  Widget build(BuildContext context) {
    final name = TestId(
      '$id-bank-name',
      child: Text(bankName, semanticsLabel: bankName, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    final number = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: name),
        const SizedBox(width: 4),
        Text('····$last4', semanticsLabel: '끝자리 $last4'),
      ],
    );
    if (balance == null) return number;
    final money = TestId(
      '$id-balance',
      child: Text(
        '잔액 ${formatUsd(balance!)}',
        style: canSend ? TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w700) : null,
      ),
    );
    // Wrap, not Row: when the line is too short, the balance goes to a second line
    // and stays whole.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        children: [number, money],
      ),
    );
  }
}

/// Radio list of the user's own bank accounts, with the money each one holds.
///
/// With [requiredCents], choosing an account that holds less says so under the list
/// (the screen also turns its button off).
class MyAccountPicker extends StatelessWidget {
  const MyAccountPicker({
    required this.idPrefix,
    required this.title,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.requiredCents,
    this.errorText,
    super.key,
  });

  /// The test ids are `$idPrefix` for the list and `$idPrefix-<id>` for each row.
  final String idPrefix;
  final String title;
  final List<BankAccount> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  /// How many cents the account must hold, or null when it does not matter.
  final int? requiredCents;
  final String? errorText;

  static bool isEnough(BankAccount account, int? requiredCents) =>
      requiredCents == null || (account.balance ?? 0) >= requiredCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TestId(
      idPrefix,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          RadioGroup<String>(
            groupValue: selectedId,
            onChanged: onChanged,
            child: Column(
              children: [
                for (final account in accounts)
                  TestId(
                    '$idPrefix-${account.id}',
                    child: RadioListTile<String>(
                      value: account.id,
                      title: _AccountLine(
                        id: '$idPrefix-${account.id}-row',
                        bankName: account.bankName,
                        last4: account.last4,
                        balance: account.balance,
                        canSend: (account.balance ?? 0) > 0 && isEnough(account, requiredCents),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          if (_tooLittle != null)
            TestId(
              'transaction-create-not-enough',
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  '선택한 계좌의 잔액(${formatUsd(_tooLittle!.balance ?? 0)})이 부족합니다',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            )
          else if (errorText != null)
            TestId(
              '$idPrefix-error',
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(errorText!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
        ],
      ),
    );
  }

  /// The chosen account, when it holds less than is needed.
  BankAccount? get _tooLittle {
    final chosen = accounts.where((a) => a.id == selectedId).firstOrNull;
    return chosen != null && !isEnough(chosen, requiredCents) ? chosen : null;
  }
}

/// Radio list of the accounts of the other user (only the bank and the last 4
/// digits are known).
class OtherAccountPicker extends StatelessWidget {
  const OtherAccountPicker({
    required this.idPrefix,
    required this.title,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final String idPrefix;
  final String title;
  final List<OtherAccount> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TestId(
      idPrefix,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          RadioGroup<String>(
            groupValue: selectedId,
            onChanged: onChanged,
            child: Column(
              children: [
                for (final account in accounts)
                  TestId(
                    '$idPrefix-${account.id}',
                    child: RadioListTile<String>(
                      value: account.id,
                      title: _AccountLine(
                        id: '$idPrefix-${account.id}-row',
                        bankName: account.bankName,
                        last4: account.last4,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          if (errorText != null)
            TestId(
              '$idPrefix-error',
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(errorText!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
        ],
      ),
    );
  }
}
