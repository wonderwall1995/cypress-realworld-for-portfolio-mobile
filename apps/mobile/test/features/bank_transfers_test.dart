import 'package:cypress_realworld_for_personal_portfolio_mobile/core/api_client.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/bank_transfers/bank_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// A signed-in user with $100.00 and one bank account.
FakeServer newServer({List<Map<String, dynamic>>? accounts}) => FakeServer(
      signedIn: true,
      accounts: accounts ?? [testAccount('b1', bank: 'First Test Bank')],
    )..balance = 10000;

Future<void> openMyAccount(WidgetTester tester) => tapId(tester, 'sidenav-my-account');

Future<void> openForm(WidgetTester tester, String buttonId) async {
  await openMyAccount(tester);
  await tapId(tester, buttonId);
}

Finder balance(String text) =>
    find.descendant(of: byId('sidenav-user-balance'), matching: find.text(text));

void main() {
  group('the 내 계좌 tab', () {
    testWidgets('has 입금 and 출금 under the balance', (tester) async {
      await pumpApp(tester, newServer());
      await openMyAccount(tester);

      expect(byId('my-account-deposit'), findsOneWidget);
      expect(byId('my-account-withdraw'), findsOneWidget);
      final balanceBottom = tester.getBottomLeft(byId('sidenav-user-balance')).dy;
      expect(tester.getTopLeft(byId('my-account-deposit')).dy, greaterThan(balanceBottom));
    });

    testWidgets('an empty history says so', (tester) async {
      await pumpApp(tester, newServer());
      await openMyAccount(tester);

      expect(byId('bank-transfers-empty'), findsOneWidget);
      expect(find.text('이체 내역이 없습니다.'), findsOneWidget);
    });

    testWidgets('lists the transfers, newest first, with names, signs and balances', (tester) async {
      final server = newServer()
        ..transfers.addAll([
          testTransfer('old', 'deposit', 5000,
              balanceBefore: 0, balanceAfter: 5000, createdAt: '2026-11-08T10:00:00.000Z'),
          testTransfer('auto', 'withdrawal', 48500,
              source: '', transactionId: 'tx1', balanceBefore: 1500, balanceAfter: 0,
              createdAt: '2026-11-09T18:21:22.378Z'),
          testTransfer('gone', 'withdrawal', 100,
              source: 'deleted-account', balanceBefore: 5000, balanceAfter: 4900,
              createdAt: '2026-11-08T12:00:00.000Z'),
        ]);
      await pumpApp(tester, server);
      await openMyAccount(tester);

      // Newest first: auto (11/9), then gone (11/8 12:00), then old (11/8 10:00).
      final autoY = tester.getTopLeft(byId('bank-transfer-list-item-auto')).dy;
      final goneY = tester.getTopLeft(byId('bank-transfer-list-item-gone')).dy;
      final oldY = tester.getTopLeft(byId('bank-transfer-list-item-old')).dy;
      expect(autoY, lessThan(goneY));
      expect(goneY, lessThan(oldY));

      expect(find.text('입금 · First Test Bank'), findsOneWidget);
      expect(find.text('출금 (결제 부족분) · 은행 계좌 없음'), findsOneWidget);
      expect(find.text('출금 · 삭제된 은행 계좌'), findsOneWidget);
      expect(find.descendant(of: byId('bank-transfer-amount-old'), matching: find.text('+\$50.00')), findsOneWidget);
      expect(find.descendant(of: byId('bank-transfer-amount-auto'), matching: find.text('-\$485.00')), findsOneWidget);
      expect(find.textContaining('잔액 \$15.00 → \$0.00'), findsOneWidget);
    });

    testWidgets('a failed load shows an error with retry', (tester) async {
      final server = newServer()
        ..transfers.add(testTransfer('t1', 'deposit', 1000, balanceAfter: 1000))
        ..failTransfers = true;
      await pumpApp(tester, server);
      await openMyAccount(tester);

      expect(byId('bank-transfers-load-error'), findsOneWidget);

      server.failTransfers = false;
      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(byId('bank-transfers-load-error'), findsNothing);
      expect(byId('bank-transfer-list-item-t1'), findsOneWidget);
    });

    testWidgets('pulling down loads the balance and the history again', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openMyAccount(tester);

      server.balance = 777;
      server.transfers.add(testTransfer('t9', 'deposit', 777, balanceAfter: 777));
      await tester.drag(find.byType(ListView).last, const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(balance('\$7.77'), findsOneWidget);
      expect(byId('bank-transfer-list-item-t9'), findsOneWidget);
    });

    testWidgets('the next user does not see the previous user\'s history', (tester) async {
      final server = newServer()..transfers.add(testTransfer('mine', 'deposit', 1000, balanceAfter: 1000));
      await pumpApp(tester, server);
      await openMyAccount(tester);
      expect(byId('bank-transfer-list-item-mine'), findsOneWidget);

      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      server.transfers.clear();
      await enter(tester, 'signin-username', 'someone');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');
      await openMyAccount(tester);

      expect(byId('bank-transfer-list-item-mine'), findsNothing);
      expect(byId('bank-transfers-empty'), findsOneWidget);
    });
  });

  group('the form', () {
    testWidgets('입금 opens a screen with the account and the amount', (tester) async {
      await pumpApp(tester, newServer());
      await openForm(tester, 'my-account-deposit');

      expect(find.text('입금'), findsWidgets);
      expect(find.text('은행 계좌에서 내 계좌로 옮깁니다.'), findsOneWidget);
      expect(byId('bank-transfer-account-b1'), findsOneWidget);
      expect(byId('bank-transfer-amount-input'), findsOneWidget);
      expect(find.descendant(of: byId('bank-transfer-submit'), matching: find.text('입금하기')), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing); // a full screen
    });

    testWidgets('출금 says the other direction and has its own button text', (tester) async {
      await pumpApp(tester, newServer());
      await openForm(tester, 'my-account-withdraw');

      expect(find.text('내 계좌에서 은행 계좌로 옮깁니다.'), findsOneWidget);
      expect(find.descendant(of: byId('bank-transfer-submit'), matching: find.text('출금하기')), findsOneWidget);
    });

    testWidgets('with one account, it is chosen already', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-deposit');

      await enter(tester, 'bank-transfer-amount-input', '5');
      await tapId(tester, 'bank-transfer-submit');

      expect(server.bodies['POST /bankTransfers'], {'bankAccountId': 'b1', 'amount': 5, 'type': 'deposit'});
    });

    testWidgets('with two accounts, one must be chosen', (tester) async {
      final server = newServer(accounts: [
        testAccount('b1', bank: 'First Test Bank'),
        testAccount('b2', bank: 'Second Test Bank'),
      ]);
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-deposit');

      await enter(tester, 'bank-transfer-amount-input', '5');
      await tapId(tester, 'bank-transfer-submit');
      expect(find.text('은행 계좌를 선택하세요.'), findsOneWidget);
      expect(server.calls, isNot(contains('POST /bankTransfers')));

      await tapId(tester, 'bank-transfer-account-b2');
      await tapId(tester, 'bank-transfer-submit');

      expect((server.bodies['POST /bankTransfers'] as Map)['bankAccountId'], 'b2');
    });

    testWidgets('checks the amount before sending', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-deposit');

      await tapId(tester, 'bank-transfer-submit');
      expect(find.text('금액을 입력하세요.'), findsOneWidget);

      for (final (text, message) in [
        ('0', '금액은 1달러 이상이어야 합니다.'),
        ('12.5', '금액은 숫자로 입력하세요. (달러 단위, 소수점 없음)'),
        ('10000000', '금액은 9999999달러 이하여야 합니다.'),
      ]) {
        await enter(tester, 'bank-transfer-amount-input', text);
        await tapId(tester, 'bank-transfer-submit');
        expect(find.text(message), findsOneWidget, reason: text);
      }
      expect(server.calls, isNot(contains('POST /bankTransfers')));
    });
  });

  group('deposit and withdraw', () {
    testWidgets('a deposit raises the balance, returns to the tab, and shows in the history', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-deposit');

      await enter(tester, 'bank-transfer-amount-input', '50');
      await tapId(tester, 'bank-transfer-submit');

      expect(server.bodies['POST /bankTransfers'], {'bankAccountId': 'b1', 'amount': 50, 'type': 'deposit'});
      expect(byId('bank-transfer-submit'), findsNothing); // back on the tab
      expect(balance('\$150.00'), findsOneWidget);
      expect(find.text('\$50.00를 입금했습니다.'), findsOneWidget);
      expect(find.text('입금 · First Test Bank'), findsOneWidget);
      expect(find.textContaining('잔액 \$100.00 → \$150.00'), findsOneWidget);
    });

    testWidgets('a withdrawal lowers the balance', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-withdraw');

      await enter(tester, 'bank-transfer-amount-input', '30');
      await tapId(tester, 'bank-transfer-submit');

      expect(server.bodies['POST /bankTransfers'], {'bankAccountId': 'b1', 'amount': 30, 'type': 'withdrawal'});
      expect(balance('\$70.00'), findsOneWidget);
      expect(find.text('\$30.00를 출금했습니다.'), findsOneWidget);
      expect(find.text('출금 · First Test Bank'), findsOneWidget);
    });

    testWidgets('withdrawing more than the balance is refused by the server; the app only tells the user',
        (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-withdraw');

      await enter(tester, 'bank-transfer-amount-input', '500');
      await tapId(tester, 'bank-transfer-submit');

      // The app does not stop the request. The server answered 400.
      expect(server.calls, contains('POST /bankTransfers'));
      expect(find.text('잔액이 부족합니다.'), findsOneWidget);
      expect(byId('bank-transfer-error'), findsOneWidget);
      expect(byId('bank-transfer-submit'), findsOneWidget); // still on the form
      expect(server.balance, 10000);
      expect(server.transfers, isEmpty);
    });

    testWidgets('after a refusal the user can fix the amount and try again', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-withdraw');

      await enter(tester, 'bank-transfer-amount-input', '500');
      await tapId(tester, 'bank-transfer-submit');
      expect(byId('bank-transfer-error'), findsOneWidget);

      await enter(tester, 'bank-transfer-amount-input', '40');
      await tapId(tester, 'bank-transfer-submit');

      expect(byId('bank-transfer-submit'), findsNothing);
      expect(balance('\$60.00'), findsOneWidget);
    });

    testWidgets('two taps in one frame send one request', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-deposit');
      await enter(tester, 'bank-transfer-amount-input', '5');

      await tester.tap(byId('bank-transfer-submit'));
      await tester.tap(byId('bank-transfer-submit'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(server.calls.where((c) => c == 'POST /bankTransfers'), hasLength(1));
      expect(server.balance, 10500);
    });

    testWidgets('other server answers get a Korean message', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openForm(tester, 'my-account-deposit');
      await enter(tester, 'bank-transfer-amount-input', '5');

      server.moveMoneyStatus = 422;
      await tapId(tester, 'bank-transfer-submit');
      expect(find.text('입력한 내용을 확인해 주세요.'), findsOneWidget);

      server.moveMoneyStatus = 500;
      await tapId(tester, 'bank-transfer-submit');
      expect(find.text('입금하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);

      server.moveMoneyStatus = null;
      server.down = true;
      await tapId(tester, 'bank-transfer-submit');
      expect(find.text('서버에 연결할 수 없습니다.'), findsOneWidget);
    });
  });

  group('without a bank account', () {
    testWidgets('says an account is needed and offers to create one', (tester) async {
      // The only account was deleted. The app treats it as no account.
      final server = FakeServer(signedIn: true, accounts: [testAccount('b1', isDeleted: true)]);
      await pumpApp(tester, server);
      // (The first-time setup would open here, so finish it with a new account.)
      await tapId(tester, 'user-onboarding-next');
      await enter(tester, 'bankaccount-bankName-input', 'New Test Bank');
      await enter(tester, 'bankaccount-routingNumber-input', '111222333');
      await enter(tester, 'bankaccount-accountNumber-input', '555666777');
      await tapId(tester, 'bankaccount-submit');
      await tapId(tester, 'user-onboarding-next');

      // Now delete it from the 은행 계좌 tab. The setup does not open again.
      await tapId(tester, 'sidenav-bankaccounts');
      await tester.tap(byId('bankaccount-delete'));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      await openMyAccount(tester);
      await tapId(tester, 'my-account-deposit');

      expect(byId('bank-transfer-no-account'), findsOneWidget);
      expect(find.text('입금하려면 은행 계좌가 필요합니다.'), findsOneWidget);
      expect(byId('bank-transfer-amount-input'), findsNothing);

      await tapId(tester, 'bank-transfer-create-account');
      expect(byId('bankaccount-form'), findsOneWidget);
    });
  });

  group('BankTransfer', () {
    test('an empty account and transaction mean a withdrawal the server made', () {
      final t = BankTransfer.fromJson(
        testTransfer('a', 'withdrawal', 100, source: '', transactionId: 'tx'),
      );
      expect(t.bankAccountId, isNull);
      expect(t.isAutomatic, isTrue);
      expect(t.label, '출금 (결제 부족분)');
    });

    test('labels', () {
      expect(BankTransfer.fromJson(testTransfer('a', 'deposit', 100)).label, '입금');
      expect(BankTransfer.fromJson(testTransfer('a', 'withdrawal', 100)).label, '출금');
    });

    test('missing values do not crash', () {
      final t = BankTransfer.fromJson({'id': 'x'});
      expect((t.amount, t.balanceBefore, t.createdAt, t.bankAccountId), (0, 0, null, null));
    });

    test('error messages follow what the server says', () {
      String msg(String text, {int? status, bool deposit = false}) => bankTransferErrorMessage(
            ApiException(text, statusCode: status),
            isDeposit: deposit,
          );
      expect(msg('not enough balance', status: 400), '잔액이 부족합니다.');
      expect(msg('the balance would be too large', status: 400, deposit: true), '잔액이 너무 커져서 입금할 수 없습니다.');
      expect(msg('this bank account was deleted', status: 400), '삭제된 은행 계좌입니다.');
      expect(msg('bank account not found', status: 404), '이 은행 계좌를 사용할 수 없습니다.');
      expect(msg('this is not your bank account', status: 403), '이 은행 계좌를 사용할 수 없습니다.');
      expect(msg('Request failed', status: 422), '입력한 내용을 확인해 주세요.');
      expect(msg('x', status: 500), '출금하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      expect(
        bankTransferErrorMessage(const ApiException('x', isConnection: true), isDeposit: true),
        '서버에 연결할 수 없습니다.',
      );
    });
  });
}
