enum NotificationKind { requested, received, like, comment }

/// One unread notification. [userFullName] is what the server sends.
/// (For "received" the server sends the name of the user who got the money,
/// that is, the signed-in user. The web shows it the same way.)
class AppNotification {
  const AppNotification({
    required this.id,
    required this.transactionId,
    required this.kind,
    required this.userFullName,
  });

  /// Returns null for a notification of a kind the app does not know.
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final kind = json['likeId'] != null
        ? NotificationKind.like
        : json['commentId'] != null
            ? NotificationKind.comment
            : switch (json['status']) {
                'requested' => NotificationKind.requested,
                'received' => NotificationKind.received,
                _ => null,
              };
    if (kind == null) return null;
    return AppNotification(
      id: json['id'] as String,
      transactionId: json['transactionId'] as String,
      kind: kind,
      userFullName: json['userFullName'] as String? ?? '',
    );
  }

  final String id;
  final String transactionId;
  final NotificationKind kind;
  final String userFullName;

  /// Korean text, same meaning as the web text.
  String get message => switch (kind) {
        NotificationKind.requested => '$userFullName님이 결제를 요청했습니다.',
        NotificationKind.received => '$userFullName님이 결제를 받았습니다.',
        NotificationKind.like => '$userFullName님이 거래에 좋아요를 눌렀습니다.',
        NotificationKind.comment => '$userFullName님이 거래에 댓글을 남겼습니다.',
      };
}
