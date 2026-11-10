/// A comment on a transaction. (The server sends the text and the author's id,
/// not the author's name.)
class TransactionComment {
  const TransactionComment({
    required this.id,
    required this.content,
    required this.userId,
    required this.createdAt,
  });

  factory TransactionComment.fromJson(Map<String, dynamic> json) => TransactionComment(
        id: json['id'] as String,
        content: json['content'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  final String id;
  final String content;
  final String userId;
  final DateTime? createdAt;
}

/// The sender of an "외부 입금" (a deposit into a bank account). The server makes
/// one transaction for each deposit; `senderName` is already "외부 입금".
const externalDepositSenderId = 'external-deposit';

/// A payment, a request, or an external deposit, as the server sends it.
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
    required this.likedByUserIds,
    required this.comments,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final requestStatus = json['requestStatus'] as String?;
    final likes = (json['likes'] as List<dynamic>?) ?? const [];
    final comments = (json['comments'] as List<dynamic>?) ?? const [];
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
      // One entry per like. The same user can appear twice: the server does
      // not stop a second like.
      likedByUserIds: [
        for (final like in likes) (like as Map<String, dynamic>)['userId'] as String? ?? '',
      ],
      comments: [
        for (final c in comments) TransactionComment.fromJson(c as Map<String, dynamic>),
      ],
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

  /// The user id of each like.
  final List<String> likedByUserIds;

  /// Oldest first, as the server sends them.
  final List<TransactionComment> comments;

  int get likeCount => likedByUserIds.length;
  int get commentCount => comments.length;

  bool isLikedBy(String? userId) => userId != null && likedByUserIds.contains(userId);

  /// A deposit the user made into one of their own bank accounts. Money came in
  /// from outside, so there is no real sender.
  bool get isExternalDeposit => senderId == externalDepositSenderId;

  bool get isRequest => requestStatus != null;
  bool get isPayment => !isRequest;
  bool get isAcceptedRequest => requestStatus == 'accepted';
  bool get isRejectedRequest => requestStatus == 'rejected';
  bool get isPendingRequest => requestStatus == 'pending';

  /// The short word after the names. Same rule as the web:
  /// payment is "paid", an accepted request is "charged", other requests are "requested".
  String get actionLabel {
    if (isExternalDeposit) return '입금';
    if (isPayment) return '결제';
    return isAcceptedRequest ? '청구' : '요청';
  }

  /// Where the transaction stands, for the detail screen.
  String get statusLabel {
    if (isExternalDeposit) return status == 'complete' ? '입금 완료' : '처리 중';
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
