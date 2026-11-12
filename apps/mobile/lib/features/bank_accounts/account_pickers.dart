import 'package:flutter/material.dart';

import '../../core/test_id.dart';
import '../transactions/transaction.dart';
import 'bank_account.dart';
import 'other_account.dart';

/// One line of a picker: the left 60% says the bank and the last 4 digits (cut
/// with "…" when long), the right 40% says the balance (only for the user's own
/// accounts).
class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.left, this.right});

  final String left;
  final String? right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 6, child: Text(left, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(
          flex: 4,
          child: Text(
            right ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// Radio list of the user's own bank accounts, with the money each one holds.
///
/// With [requiredCents], choosing an account that holds less shows "선택한 계좌의
/// 잔액이 부족합니다." (the screen also turns its button off).
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

  /// The test ids are `$idPrefix` for the list and `$idPrefix-account-<id>` for each row.
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
                    '$idPrefix-account-${account.id}',
                    child: RadioListTile<String>(
                      value: account.id,
                      title: _AccountLine(
                        left: '${account.bankName} ${account.maskedAccountNumber}',
                        right: account.balance == null ? null : formatUsd(account.balance!),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          if (_shownError != null)
            TestId(
              '$idPrefix-error',
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(_shownError!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
        ],
      ),
    );
  }

  /// The message under the list: the screen's own, or "too little" for the chosen account.
  String? get _shownError {
    if (errorText != null) return errorText;
    final chosen = accounts.where((a) => a.id == selectedId).firstOrNull;
    if (chosen != null && !isEnough(chosen, requiredCents)) return '선택한 계좌의 잔액이 부족합니다.';
    return null;
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
                    '$idPrefix-account-${account.id}',
                    child: RadioListTile<String>(
                      value: account.id,
                      title: _AccountLine(left: '${account.bankName} ****${account.last4}'),
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
