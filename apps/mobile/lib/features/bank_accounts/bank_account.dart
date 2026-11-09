class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.routingNumber,
    required this.accountNumber,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: json['id'] as String,
        bankName: json['bankName'] as String,
        routingNumber: json['routingNumber'] as String,
        accountNumber: json['accountNumber'] as String,
      );

  final String id;
  final String bankName;
  final String routingNumber;
  final String accountNumber;

  /// Shows only the last 4 digits, for example `****1234`.
  String get maskedAccountNumber {
    final tail = accountNumber.length <= 4
        ? accountNumber
        : accountNumber.substring(accountNumber.length - 4);
    return '****$tail';
  }
}
