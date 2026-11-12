/// A bank account of another user, as the server shows it: no full number and no
/// balance, only the last 4 digits.
class OtherAccount {
  const OtherAccount({required this.id, required this.bankName, required this.last4});

  factory OtherAccount.fromJson(Map<String, dynamic> json) => OtherAccount(
        id: json['id'] as String,
        bankName: json['bankName'] as String? ?? '',
        last4: json['accountNumberLast4'] as String? ?? '',
      );

  final String id;
  final String bankName;
  final String last4;

  /// For example `계좌 번호 ****2222`.
  String get describe => '계좌 번호 ****$last4';
}
