import '../../core/api_client.dart';
import '../../core/error_text.dart';

/// A deposit or a withdrawal, as the server sends it.
class BankTransfer {
  const BankTransfer({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.bankAccountId,
    required this.transactionId,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory BankTransfer.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    final transactionId = json['transactionId'] as String?;
    return BankTransfer(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      // The server makes some withdrawals by itself and leaves the account empty.
      bankAccountId: (source == null || source.isEmpty) ? null : source,
      transactionId: (transactionId == null || transactionId.isEmpty) ? null : transactionId,
      balanceBefore: (json['balanceBefore'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  final String id;

  /// `deposit` or `withdrawal`.
  final String type;

  /// In cents.
  final int amount;
  final String status;

  /// The bank account, or null for a withdrawal the server made by itself.
  final String? bankAccountId;

  /// Set when the server made this withdrawal to cover that payment.
  final String? transactionId;

  /// In cents.
  final int balanceBefore;
  final int balanceAfter;
  final DateTime? createdAt;

  bool get isDeposit => type == 'deposit';

  /// A withdrawal that the server made to cover a payment.
  bool get isAutomatic => transactionId != null;

  String get label {
    if (isDeposit) return '입금';
    return isAutomatic ? '출금 (결제 부족분)' : '출금';
  }
}

/// Korean text for what the server says when it refuses a deposit or withdrawal.
String bankTransferErrorMessage(ApiException e, {required bool isDeposit}) =>
    isDeposit ? depositRefusalText(e) : serverRefusalText(e, base: '출금하지 못했습니다');
