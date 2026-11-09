import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

void main() {
  group('formatUsd', () {
    test('formats cents as dollars', () {
      expect(formatUsd(0), '\$0.00');
      expect(formatUsd(5), '\$0.05');
      expect(formatUsd(700), '\$7.00');
      expect(formatUsd(123456), '\$1,234.56');
      expect(formatUsd(100000000), '\$1,000,000.00');
    });
  });

  group('Transaction.fromJson', () {
    test('a payment has no request status', () {
      final t = Transaction.fromJson(testTransaction('p1'));
      expect(t.isPayment, isTrue);
      expect(t.isRequest, isFalse);
      expect(t.requestStatus, isNull);
      expect(t.actionLabel, '결제');
      expect(t.statusLabel, '결제 완료');
    });

    test('an empty request status also means a payment', () {
      final json = testTransaction('p1')..['requestStatus'] = '';
      expect(Transaction.fromJson(json).isPayment, isTrue);
    });

    test('request words follow the web rule', () {
      Transaction request(String status) =>
          Transaction.fromJson(testTransaction('r', requestStatus: status));
      expect(request('pending').actionLabel, '요청');
      expect(request('rejected').actionLabel, '요청');
      expect(request('accepted').actionLabel, '청구');
      expect(request('pending').statusLabel, '요청 대기 중');
      expect(request('accepted').statusLabel, '수락됨');
      expect(request('rejected').statusLabel, '거절됨');
    });

    test('counts likes and comments, and keeps cents', () {
      final t = Transaction.fromJson(testTransaction('p1', amount: 2500, likes: 2, comments: 3));
      expect(t.amount, 2500);
      expect(t.likeCount, 2);
      expect(t.commentCount, 3);
    });

    test('missing lists and names do not crash', () {
      final t = Transaction.fromJson({
        'id': 'x',
        'senderId': 's',
        'receiverId': 'r',
      });
      expect(t.likeCount, 0);
      expect(t.commentCount, 0);
      expect(t.senderName, '');
      expect(t.amount, 0);
    });
  });
}
