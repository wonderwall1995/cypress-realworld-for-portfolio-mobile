import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// The signed-in user is `u1`. A request is "to me" when its receiver is `u1`.
Map<String, dynamic> requestToMe({String requestStatus = 'pending'}) => testTransaction(
      'r1',
      sender: 'Bob Test',
      receiver: 'Ada Kim',
      description: 'Share of dinner',
      amount: 700,
      requestStatus: requestStatus,
      status: requestStatus == 'accepted' ? 'complete' : 'pending',
      senderId: 'u2',
      receiverId: 'u1',
    );

Map<String, dynamic> requestFromMe() => testTransaction(
      'r2',
      sender: 'Ada Kim',
      receiver: 'Bob Test',
      description: 'My request',
      amount: 900,
      requestStatus: 'pending',
      status: 'pending',
      senderId: 'u1',
      receiverId: 'u2',
    );

FakeServer serverWith(List<Map<String, dynamic>> items) =>
    FakeServer(signedIn: true, accounts: [testAccount('b1')])
      ..balance = 5000
      ..everyone.addAll(items);

Future<void> openDetail(WidgetTester tester, String id) => tapId(tester, 'transaction-item-$id');

void main() {
  group('who sees the buttons', () {
    testWidgets('the receiver of a pending request sees 수락 and 거절', (tester) async {
      await pumpApp(tester, serverWith([requestToMe()]));
      await openDetail(tester, 'r1');

      expect(byId('transaction-accept-request-r1'), findsOneWidget);
      expect(byId('transaction-reject-request-r1'), findsOneWidget);
    });

    testWidgets('the sender of the request does not', (tester) async {
      await pumpApp(tester, serverWith([requestFromMe()]));
      await openDetail(tester, 'r2');

      expect(byId('transaction-accept-request-r2'), findsNothing);
      expect(byId('transaction-reject-request-r2'), findsNothing);
    });

    testWidgets('a resolved request has no buttons', (tester) async {
      await pumpApp(tester, serverWith([requestToMe(requestStatus: 'accepted')]));
      await openDetail(tester, 'r1');

      expect(byId('transaction-accept-request-r1'), findsNothing);
      expect(find.descendant(of: byId('transaction-status'), matching: find.text('수락됨')), findsOneWidget);
    });

    testWidgets('a payment has no buttons', (tester) async {
      await pumpApp(tester, serverWith([testTransaction('p1', senderId: 'u2', receiverId: 'u1')]));
      await openDetail(tester, 'p1');

      expect(byId('transaction-accept-request-p1'), findsNothing);
    });
  });

  group('accept', () {
    testWidgets('asks first; cancel changes nothing', (tester) async {
      final server = serverWith([requestToMe()]);
      await pumpApp(tester, server);
      await openDetail(tester, 'r1');

      await tapId(tester, 'transaction-accept-request-r1');
      expect(find.text('Bob Test님에게 \$7.00를 보냅니다. 수락하시겠습니까?'), findsOneWidget);

      await tapId(tester, 'transaction-accept-cancel');

      expect(server.calls, isNot(contains('PATCH /transactions/r1')));
      expect(byId('transaction-accept-request-r1'), findsOneWidget);
    });

    testWidgets('after confirm, the request is accepted and the balance goes down', (tester) async {
      final server = serverWith([requestToMe()]);
      await pumpApp(tester, server);
      await openDetail(tester, 'r1');

      await tapId(tester, 'transaction-accept-request-r1');
      await tapId(tester, 'transaction-accept-confirm');

      expect(server.bodies['PATCH /transactions/r1'], {'requestStatus': 'accepted'});
      expect(find.descendant(of: byId('transaction-status'), matching: find.text('수락됨')), findsOneWidget);
      expect(byId('transaction-accept-request-r1'), findsNothing);
      expect(byId('alert-bar-success'), findsOneWidget);

      // $50.00 - $7.00
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapId(tester, 'sidenav-my-account');
      expect(find.descendant(of: byId('sidenav-user-balance'), matching: find.text('\$43.00')), findsOneWidget);
    });
  });

  group('reject', () {
    testWidgets('is done at once, without asking, and the money stays', (tester) async {
      final server = serverWith([requestToMe()]);
      await pumpApp(tester, server);
      await openDetail(tester, 'r1');

      await tapId(tester, 'transaction-reject-request-r1');

      expect(server.bodies['PATCH /transactions/r1'], {'requestStatus': 'rejected'});
      expect(find.descendant(of: byId('transaction-status'), matching: find.text('거절됨')), findsOneWidget);
      expect(byId('transaction-reject-request-r1'), findsNothing);
      expect(server.balance, 5000);
    });
  });

  group('when something goes wrong', () {
    testWidgets('a request that was resolved elsewhere shows a message and refreshes', (tester) async {
      final server = serverWith([requestToMe()]);
      await pumpApp(tester, server);
      await openDetail(tester, 'r1');

      // Someone resolved it in the meantime.
      server.everyone.first['requestStatus'] = 'rejected';
      await tapId(tester, 'transaction-reject-request-r1');

      expect(find.text('이미 처리된 요청입니다.'), findsOneWidget);
      expect(find.descendant(of: byId('transaction-status'), matching: find.text('거절됨')), findsOneWidget);
      expect(byId('transaction-reject-request-r1'), findsNothing);
    });

    testWidgets('a server error shows a message and keeps the buttons', (tester) async {
      final server = serverWith([requestToMe()])..updateTransactionStatus = 500;
      await pumpApp(tester, server);
      await openDetail(tester, 'r1');

      await tapId(tester, 'transaction-reject-request-r1');

      expect(find.text('요청을 처리하지 못했습니다.'), findsOneWidget);
      expect(byId('transaction-reject-request-r1'), findsOneWidget);
    });
  });
}
