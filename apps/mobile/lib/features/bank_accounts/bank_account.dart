import '../transactions/transaction.dart';

class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    this.balance,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: json['id'] as String,
        bankName: json['bankName'] as String,
        accountNumber: json['accountNumber'] as String,
        balance: (json['balance'] as num?)?.toInt(),
      );

  final String id;
  final String bankName;
  final String accountNumber;

  /// The money held in this bank account, in cents. A deposit raises it. (The
  /// server did not send it in the past, so it can be missing.)
  final int? balance;

  /// What the lists say about the account: the number (last 4 digits only) and,
  /// when the server sends it, the money in the account. For example
  /// `계좌 번호 ****1234 · 잔액 $25.00`.
  String get describe =>
      balance == null ? '계좌 번호 $maskedAccountNumber' : '계좌 번호 $maskedAccountNumber · 잔액 ${formatUsd(balance!)}';

  /// Shows only the last 4 digits, for example `****1234`.
  String get maskedAccountNumber {
    final tail = accountNumber.length <= 4
        ? accountNumber
        : accountNumber.substring(accountNumber.length - 4);
    return '****$tail';
  }
}
