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
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory BankTransfer.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    return BankTransfer(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      bankAccountId: (source == null || source.isEmpty) ? null : source,
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

  /// The bank account, or null when the server does not say.
  final String? bankAccountId;

  /// In cents.
  final int balanceBefore;
  final int balanceAfter;
  final DateTime? createdAt;

  bool get isDeposit => type == 'deposit';

  String get label => isDeposit ? '입금' : '출금';
}

/// Korean text for what the server says when it refuses a deposit or withdrawal.
String bankTransferErrorMessage(ApiException e, {required bool isDeposit}) =>
    isDeposit ? depositRefusalText(e) : serverRefusalText(e, base: '출금하지 못했습니다');
