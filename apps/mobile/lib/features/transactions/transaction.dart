/// A payment or a request, as the server sends it.
class Transaction {
  const Transaction({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.receiverName,
    required this.description,
    required this.amount,
    required this.status,
    required this.requestStatus,
    required this.likeCount,
    required this.commentCount,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final requestStatus = json['requestStatus'] as String?;
    return Transaction(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      senderName: json['senderName'] as String? ?? '',
      receiverName: json['receiverName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      // A payment has no request status (missing or empty).
      requestStatus: (requestStatus == null || requestStatus.isEmpty) ? null : requestStatus,
      likeCount: (json['likes'] as List<dynamic>?)?.length ?? 0,
      commentCount: (json['comments'] as List<dynamic>?)?.length ?? 0,
    );
  }

  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String receiverName;
  final String description;

  /// In cents. 700 is $7.00.
  final int amount;

  /// `pending`, `incomplete`, or `complete`.
  final String status;

  /// `pending`, `accepted`, or `rejected`. Null for a payment.
  final String? requestStatus;

  final int likeCount;
  final int commentCount;

  bool get isRequest => requestStatus != null;
  bool get isPayment => !isRequest;
  bool get isAcceptedRequest => requestStatus == 'accepted';
  bool get isRejectedRequest => requestStatus == 'rejected';
  bool get isPendingRequest => requestStatus == 'pending';

  /// The short word after the names. Same rule as the web:
  /// payment is "paid", an accepted request is "charged", other requests are "requested".
  String get actionLabel {
    if (isPayment) return '결제';
    return isAcceptedRequest ? '청구' : '요청';
  }

  /// Where the transaction stands, for the detail screen.
  String get statusLabel {
    if (isPayment) return status == 'complete' ? '결제 완료' : '처리 중';
    if (isAcceptedRequest) return '수락됨';
    if (isRejectedRequest) return '거절됨';
    return '요청 대기 중';
  }
}

/// Dollars with a thousands separator, for example `$1,234.50`. [cents] is in cents.
String formatUsd(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final dollars = (abs ~/ 100).toString();
  final rest = (abs % 100).toString().padLeft(2, '0');
  final grouped = dollars.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negative ? '-' : ''}\$$grouped.$rest';
}
