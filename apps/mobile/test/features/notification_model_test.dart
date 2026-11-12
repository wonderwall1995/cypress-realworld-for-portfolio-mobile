import 'package:cypress_realworld_for_personal_portfolio_mobile/features/notifications/app_notification.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('knows the four kinds', () {
      for (final (kind, expected) in [
        ('requested', NotificationKind.requested),
        ('received', NotificationKind.received),
        ('like', NotificationKind.like),
        ('comment', NotificationKind.comment),
      ]) {
        expect(AppNotification.fromJson(testNotification('n', kind))!.kind, expected, reason: kind);
      }
    });

    test('a like or comment id wins over a payment status', () {
      final json = {...testNotification('n', 'like'), 'status': 'received'};
      expect(AppNotification.fromJson(json)!.kind, NotificationKind.like);
    });

    test('an unknown kind gives null', () {
      expect(AppNotification.fromJson({...testNotification('n', 'like'), 'likeId': null, 'status': 'x'}), isNull);
    });

    test('the Korean message uses the name from the server', () {
      expect(AppNotification.fromJson(testNotification('n', 'requested', name: 'Bob Test'))!.message,
          'Bob Test님이 결제를 요청했습니다.');
      expect(AppNotification.fromJson(testNotification('n', 'received', name: 'Ada Kim'))!.message,
          'Ada Kim님이 이체했습니다.');
    });
  });

  group('Transaction likes and comments', () {
    test('keeps who liked and the comments in order', () {
      final t = Transaction.fromJson(
        testTransaction('t', likedBy: ['a', 'b'], commentTexts: ['one', 'two']),
      );
      expect(t.likeCount, 2);
      expect(t.isLikedBy('a'), isTrue);
      expect(t.isLikedBy('zzz'), isFalse);
      expect(t.isLikedBy(null), isFalse);
      expect(t.commentCount, 2);
      expect(t.comments.map((c) => c.content), ['one', 'two']);
      expect(t.comments.first.createdAt, isNotNull);
    });

    test('a double like from the same user counts twice but is still "liked"', () {
      final t = Transaction.fromJson(testTransaction('t', likedBy: ['me', 'me']));
      expect(t.likeCount, 2);
      expect(t.isLikedBy('me'), isTrue);
    });

    test('a bad date does not crash', () {
      final c = TransactionComment.fromJson({'id': 'c', 'content': 'x', 'userId': 'u', 'createdAt': 'nope'});
      expect(c.createdAt, isNull);
    });
  });
}
