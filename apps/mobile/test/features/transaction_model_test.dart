import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

void main() {
  group('formatUsd', () {
    test('formats cents as dollars', () {
      expect(formatUsd(0), '\$0');
      expect(formatUsd(5), '\$0.05');
      expect(formatUsd(700), '\$7');
      expect(formatUsd(123456), '\$1,234.56');
      expect(formatUsd(100000000), '\$1,000,000');
    });
  });

  group('Transaction.fromJson', () {
    test('says where it stands', () {
      expect(Transaction.fromJson(testTransaction('p1')).statusLabel, '이체 완료');
      expect(Transaction.fromJson(testTransaction('p1', status: 'incomplete')).statusLabel, '처리 중');
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

  test('money as the web shows it: no cents when there are none', () {
    expect(formatUsd(51200), '\$512');
    expect(formatUsd(51250), '\$512.5');
    expect(formatUsd(123456), '\$1,234.56');
    expect(formatUsd(5), '\$0.05');
    expect(formatUsd(0), '\$0');
    expect(formatUsd(-200000), '-\$2,000');
    expect(formatUsd(2147483600), '\$21,474,836');
  });
}
