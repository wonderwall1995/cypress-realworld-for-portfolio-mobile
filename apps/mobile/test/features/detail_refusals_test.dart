import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';
import '../support/transfer_helpers.dart';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')])
  ..everyone.add(testTransaction('t1', description: 'Dinner'));

Future<void> openDetail(WidgetTester tester, FakeServer server) async {
  await pumpApp(tester, server);
  await tapId(tester, 'transaction-item-t1');
}

void likeFromAnotherDevice(FakeServer server) =>
    (server.everyone.single['likes'] as List).add({'id': 'l9', 'userId': 'u1'});

void main() {
  group('a transaction that cannot be seen', () {
    testWidgets('says so, without a retry, and leads back to the list', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      server.everyone.clear(); // made private, for example
      await tapId(tester, 'transaction-item-t1');

      expect(find.text('거래를 찾을 수 없거나 볼 수 없습니다.'), findsOneWidget);
      expect(byId('transaction-detail-error'), findsNothing);
      await tapId(tester, 'transaction-detail-back-to-list');
      expect(byId('nav-transaction-tabs'), findsOneWidget);
    });

    testWidgets('another failure still has the retry', (tester) async {
      final server = newServer()..failTransactionDetail = true;
      await openDetail(tester, server);
      expect(byId('transaction-detail-error'), findsOneWidget);
      expect(byId('transaction-detail-not-found'), findsNothing);
    });
  });

  group('a like', () {
    testWidgets('made on another device: says so and shows the like, no error state', (tester) async {
      final server = newServer();
      await openDetail(tester, server);
      likeFromAnotherDevice(server);
      await tapId(tester, 'transaction-like-button-t1');

      expect(find.text('이미 좋아요를 눌렀습니다'), findsOneWidget);
      expect(find.descendant(of: byId('transaction-like-count-t1'), matching: find.text('1')), findsOneWidget);
      final button = tester.widget<IconButton>(find.descendant(of: byId('transaction-like-button-t1'), matching: find.byType(IconButton)));
      expect(button.onPressed, isNull);
      expect(server.calls.where((c) => c == 'POST /likes/t1'), hasLength(1));
    });

    testWidgets('whose answer is lost: shows what the server has', (tester) async {
      final server = newServer()..loseAnswer.add('POST /likes/t1');
      await openDetail(tester, server);
      await tapId(tester, 'transaction-like-button-t1');

      expect(find.descendant(of: byId('transaction-like-count-t1'), matching: find.text('1')), findsOneWidget);
    });
  });

  group('a comment', () {
    testWidgets('whose answer is lost: the text stays and the list shows it is there', (tester) async {
      final server = newServer()..loseAnswer.add('POST /comments/t1');
      await openDetail(tester, server);
      await enterIn(tester, 'transaction-comment-input-t1', 'Hello');
      await tester.pump();
      await tapId(tester, 'transaction-comment-submit-t1');

      expect(find.text('응답을 받지 못해 처리 결과를 확인할 수 없습니다.'), findsOneWidget);
      expect(find.text('Hello'), findsNWidgets(2)); // the draft and the comment
      expect(server.calls.where((c) => c == 'POST /comments/t1'), hasLength(1));
    });

    testWidgets('leaving while it is on its way does not break the app', (tester) async {
      final server = newServer();
      await openDetail(tester, server);
      final hold = Completer<void>();
      server.gate = (key) => key == 'POST /comments/t1' || key == 'POST /likes/t1' ? hold.future : null;
      await enterIn(tester, 'transaction-comment-input-t1', 'Hello');
      await tester.pump();
      await tester.tap(byId('transaction-comment-submit-t1'));
      await tester.tap(byId('transaction-like-button-t1'));
      await tester.pump();
      await goBack(tester);
      hold.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(byId('nav-transaction-tabs'), findsOneWidget);
    });
  });
}
