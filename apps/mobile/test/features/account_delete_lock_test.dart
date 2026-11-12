import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

FakeServer serverWith({List<Map<String, dynamic>>? accounts}) => FakeServer(
      signedIn: true,
      accounts: accounts ?? [testAccount('b1', bank: 'First Bank', balance: 20000)],
    )..balance = 20000;

void main() {
  group('an account that holds money', () {
    FakeServer accountsServer() => FakeServer(signedIn: true, accounts: [
          testAccount('b1', bank: 'Rich Bank', balance: 500),
          testAccount('b2', bank: 'Empty Bank', balance: 0),
          testAccount('b3', bank: 'Unknown Bank'), // the server did not say
        ]);

    bool deleteEnabled(WidgetTester tester, String id) => tester
            .widget<TextButton>(find.descendant(of: byId('bankaccount-list-item-$id'), matching: find.byType(TextButton)))
            .onPressed !=
        null;

    testWidgets('cannot be deleted: the button is off and says why', (tester) async {
      await pumpApp(tester, accountsServer());
      await tapId(tester, 'sidenav-bankaccounts');

      expect(deleteEnabled(tester, 'b1'), isFalse);
      expect(find.descendant(of: byId('bankaccount-list-item-b1'), matching: find.text('잔액이 있는 계좌는 삭제할 수 없습니다.')), findsOneWidget);
      expect(find.descendant(of: byId('bankaccount-list-item-b2'), matching: find.text('잔액이 있는 계좌는 삭제할 수 없습니다.')), findsNothing);
    });

    testWidgets('an empty account, and one without a balance from the server, can be deleted', (tester) async {
      await pumpApp(tester, accountsServer());
      await tapId(tester, 'sidenav-bankaccounts');

      expect(deleteEnabled(tester, 'b2'), isTrue);
      expect(deleteEnabled(tester, 'b3'), isTrue);
    });

    testWidgets('after the money is gone, the account can be deleted', (tester) async {
      final server = accountsServer();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');
      expect(deleteEnabled(tester, 'b1'), isFalse);

      server.accounts.first['balance'] = 0; // changed on the server
      await tapId(tester, 'sidenav-home');
      await tapId(tester, 'sidenav-bankaccounts'); // opening the tab loads the list again

      expect(deleteEnabled(tester, 'b1'), isTrue);
    });
  });
}
