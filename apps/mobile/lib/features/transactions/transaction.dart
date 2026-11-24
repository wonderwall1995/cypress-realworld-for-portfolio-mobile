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

/// The signed-in user's own bank account in a transaction: which bank, and how
/// much the account held after the transaction. The server sends it only when
/// the account is the user's own.
class MyAccountInfo {
  const MyAccountInfo({required this.bankName, this.balanceAfter});

  factory MyAccountInfo.fromJson(Map<String, dynamic> json) => MyAccountInfo(
        bankName: json['bankName'] as String? ?? '',
        balanceAfter: (json['balanceAfter'] as num?)?.toInt(),
      );

  final String bankName;

  /// In cents. Null when the server does not say.
  final int? balanceAfter;
}

/// A payment (이체) or an external deposit, as the server sends it.
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
    required this.likedByUserIds,
    required this.comments,
    this.createdAt,
    this.source,
    this.myAccount,
    this.privacyLevel,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
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
      // One entry per like. (Old data can hold the same user twice.)
      likedByUserIds: [
        for (final like in likes) (like as Map<String, dynamic>)['userId'] as String? ?? '',
      ],
      comments: [
        for (final c in comments) TransactionComment.fromJson(c as Map<String, dynamic>),
      ],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      source: (json['source'] as String?)?.isEmpty ?? true ? null : json['source'] as String?,
      myAccount: json['myAccount'] is Map<String, dynamic>
          ? MyAccountInfo.fromJson(json['myAccount'] as Map<String, dynamic>)
          : null,
      privacyLevel: json['privacyLevel'] as String?,
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

  /// The user id of each like.
  final List<String> likedByUserIds;

  /// Oldest first, as the server sends them.
  final List<TransactionComment> comments;

  /// The id of the bank account an external deposit went into. Null for the rest.
  final String? source;

  /// The user's own bank account in this transaction (null when it is not theirs).
  final MyAccountInfo? myAccount;

  /// Who can see it: `public`, `private` (or the old `contacts`). Null when the
  /// server does not say.
  final String? privacyLevel;

  /// When the payment or deposit was made. Missing if the server does not say.
  final DateTime? createdAt;

  /// The day it was made on the phone's calendar, for example `2026/11/10`.
  /// Null when the server did not send the time.
  String? get dateLabel {
    final t = createdAt?.toLocal();
    if (t == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}/${two(t.month)}/${two(t.day)}';
  }

  int get likeCount => likedByUserIds.length;
  int get commentCount => comments.length;

  bool isLikedBy(String? userId) => userId != null && likedByUserIds.contains(userId);

  /// A deposit the user made into one of their own bank accounts. Money came in
  /// from outside, so there is no real sender.
  bool get isExternalDeposit => senderId == externalDepositSenderId;

  /// Did money really move? A payment that is not complete moved nothing.
  bool get moneyMoved => isExternalDeposit || status == 'complete';

  /// Which way the money went for [userId]: `true` = the user received it (입금),
  /// `false` = the user paid it (출금), null = not the user's money.
  /// The money goes from the sender to the receiver.
  bool? receivedBy(String? userId) {
    if (userId == null || senderId == receiverId) return null;
    if (receiverId == userId) return true;
    if (senderId == userId) return false;
    return null;
  }

  /// Where the transaction stands, for the detail screen.
  String get statusLabel {
    if (status != 'complete') return '처리 중';
    return isExternalDeposit ? '입금 완료' : '이체 완료';
  }
}

/// Dollars as the web shows them: a thousands separator and no cents when there are
/// none (`$1,234`). Cents that exist are shown (`$512.5`, `$1,234.56`). [cents] is in
/// cents.
String formatUsd(int cents) {
  final abs = cents.abs();
  final dollars = (abs ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final rest = abs % 100;
  final decimals = rest == 0
      ? ''
      : rest % 10 == 0
      ? '.${rest ~/ 10}'
      : '.${rest.toString().padLeft(2, '0')}';
  return '${cents < 0 ? '-' : ''}\$$dollars$decimals';
}
