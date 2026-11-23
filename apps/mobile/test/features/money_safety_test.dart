import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';
import '../support/transfer_helpers.dart';

/// What happens to a deposit or a transfer when something goes wrong on the way.
FakeServer newServer({List<Map<String, dynamic>>? accounts}) => FakeServer(
      signedIn: true,
      accounts: accounts ?? [testAccount('b1', bank: 'First Bank', balance: 20000)],
    )
      ..balance = 20000
      ..users.add(testOtherUser('u2', 'Bob', 'Test'))
      ..everyone.add(testTransaction('t1', description: 'Dinner'));

const unknownText = '응답을 받지 못해 처리 결과를 확인할 수 없습니다.';
const staleText = '처리는 완료됐지만 최신 잔액을 불러오지 못했습니다.';

int calls(FakeServer s, String key) => s.calls.where((c) => c == key).length;

/// Goes on without waiting for the answer that is held back (a spinner never settles).
Future<void> step(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> openDeposit(WidgetTester tester, FakeServer server) async {
  await pumpApp(tester, server);
  await tapId(tester, 'sidenav-my-account');
  await tapId(tester, 'sidenav-deposit');
  await enter(tester, 'deposit-amount-input', '5');
}

Future<void> openTransfer(WidgetTester tester, FakeServer server) async {
  await pumpApp(tester, server);
  await tapId(tester, 'sidenav-my-account');
  await tapId(tester, 'sidenav-transfer');
  await tapId(tester, 'user-list-item-u2');
  await enter(tester, 'transaction-create-amount-input', '5');
  await enter(tester, 'transaction-create-description-input', 'x');
  await tester.pump();
}

/// The phone's Back button.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await step(tester);
}

void main() {
  group('a deposit on its way', () {
    testWidgets('cannot be closed: not by Cancel, a tap outside, or Back', (tester) async {
      final server = newServer();
      await openDeposit(tester, server);
      final hold = Completer<void>();
      server.gate = (key) => key == 'POST /bankTransfers' ? hold.future : null;

      await tester.tap(byId('deposit-submit-button'));
      await step(tester);
      expect(find.text('처리 중입니다.'), findsOneWidget);

      final cancel = tester.widget<TextButton>(find.descendant(of: byId('deposit-cancel-button'), matching: find.byType(TextButton)));
      expect(cancel.onPressed, isNull);
      await tester.tapAt(const Offset(5, 5));
      await step(tester);
      await systemBack(tester);
      expect(byId('deposit-dialog'), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(byId('deposit-dialog'), findsNothing);
      expect(byId('sidenav-deposit'), findsOneWidget); // only the dialog was closed
      expect(calls(server, 'POST /bankTransfers'), 1);
    });

    testWidgets('can be closed before it is sent', (tester) async {
      await openDeposit(tester, newServer());
      await systemBack(tester);
      expect(byId('deposit-dialog'), findsNothing);
    });

    testWidgets('the answer is lost: says unknown, does not offer to send again, offers the history', (tester) async {
      final server = newServer()..loseAnswer.add('POST /bankTransfers');
      await openDeposit(tester, server);
      await tapId(tester, 'deposit-submit-button');

      expect(find.text(unknownText), findsOneWidget);
      expect(byId('deposit-submit-button'), findsNothing);
      expect(byId('deposit-dialog'), findsOneWidget);
      // The keyboard's done key does not send it either.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls(server, 'POST /bankTransfers'), 1);

      await tapId(tester, 'deposit-check-history');
      expect(byId('deposit-dialog'), findsNothing);
      // The server had done it, and the history shows it.
      expect(find.text('입금 · First Bank'), findsOneWidget);
    });

    testWidgets('an HTML error page is not shown and counts as unknown', (tester) async {
      final server = newServer()..htmlError.add('POST /bankTransfers');
      await openDeposit(tester, server);
      await tapId(tester, 'deposit-submit-button');

      expect(find.text(unknownText), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
    });

    testWidgets('not sent at all: can be tried again', (tester) async {
      final server = newServer();
      await openDeposit(tester, server);
      server.down = true;
      await tapId(tester, 'deposit-submit-button');
      expect(byId('deposit-submit-button'), findsOneWidget);

      server.down = false;
      await tapId(tester, 'deposit-submit-button');
      expect(byId('deposit-dialog'), findsNothing);
      expect(server.transfers, hasLength(1));
    });

    testWidgets('done, but the new balance could not be read: says both, and only reads again', (tester) async {
      final server = newServer();
      await openDeposit(tester, server);
      server.failAccountList = true;
      await tapId(tester, 'deposit-submit-button');

      expect(byId('deposit-dialog'), findsNothing);
      expect(find.text(staleText), findsOneWidget);

      await tapId(tester, 'amounts-changed-reload'); // still failing
      expect(byId('amounts-changed-notice'), findsOneWidget);

      server.failAccountList = false;
      await tapId(tester, 'amounts-changed-reload');
      expect(byId('amounts-changed-notice'), findsNothing);
      expect(calls(server, 'POST /bankTransfers'), 1);
      await tapId(tester, 'sidenav-bankaccounts');
      expect(find.textContaining('205'), findsOneWidget);
    });
  });

  group('a transfer on its way', () {
    testWidgets('cannot be closed while it is sent', (tester) async {
      final server = newServer();
      await openTransfer(tester, server);
      await tapId(tester, 'transaction-create-submit-payment');
      final hold = Completer<void>();
      server.gate = (key) => key == 'POST /transactions' ? hold.future : null;
      await enterIn(tester, 'transaction-confirm-password', 'pw-1234');
      await tester.pump();
      await tester.tap(byId('transaction-confirm-confirm'));
      await step(tester);

      await systemBack(tester);
      expect(byId('transaction-confirm-dialog'), findsOneWidget);
      expect(find.text('처리 중입니다.'), findsOneWidget);
      expect(find.text('이체 완료'), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text('이체 완료'), findsOneWidget);
      expect(calls(server, 'POST /transactions'), 1);
    });

    testWidgets('the answer is lost: unknown, no second send, the history', (tester) async {
      final server = newServer()..loseAnswer.add('POST /transactions');
      await openTransfer(tester, server);
      await payNow(tester);

      expect(find.text(unknownText), findsOneWidget);
      expect(byId('transaction-confirm-confirm'), findsNothing);
      expect(find.text('이체 완료'), findsNothing);

      await tapId(tester, 'transaction-confirm-check-history');
      expect(byId('nav-transaction-tabs'), findsOneWidget);
      expect(calls(server, 'POST /transactions'), 1);
    });

    testWidgets('the password check fails (not 403): nothing was sent, and it says so', (tester) async {
      final server = newServer()..htmlError.add('POST /users/verifyPassword');
      await openTransfer(tester, server);
      await payNow(tester);

      expect(find.text('비밀번호를 확인하지 못했습니다. 잠시 뒤 다시 시도하세요'), findsOneWidget);
      expect(byId('transaction-confirm-confirm'), findsOneWidget); // can try again
      expect(calls(server, 'POST /transactions'), 0);
    });

    testWidgets('403 about the account is not a wrong password: choose the accounts again', (tester) async {
      final server = newServer()
        ..createTransactionStatus = 403
        ..createTransactionMessage = "this is not the receiver's bank account";
      await openTransfer(tester, server);
      await payNow(tester);

      expect(find.text('선택한 계좌를 사용할 수 없습니다'), findsOneWidget);
      expect(find.text('비밀번호가 맞지 않습니다'), findsNothing);
      final before = calls(server, 'GET /bankAccounts/of-user/u2');

      await tapId(tester, 'transaction-confirm-reselect');
      expect(byId('transaction-confirm-dialog'), findsNothing);
      // What was typed stays; the other side is read again.
      expect(find.text('x'), findsOneWidget);
      expect(calls(server, 'GET /bankAccounts/of-user/u2'), greaterThan(before));
    });

    testWidgets('the password became wrong between the two steps: type it again', (tester) async {
      final server = newServer()
        ..createTransactionStatus = 403
        ..createTransactionMessage = 'the password is not correct';
      await openTransfer(tester, server);
      await payNow(tester);

      expect(find.text('비밀번호가 맞지 않습니다'), findsOneWidget);
      expect(byId('transaction-confirm-reselect'), findsNothing);
    });

    testWidgets('done, but the new balance could not be read: 이체 완료 stays, reading is offered', (tester) async {
      final server = newServer();
      await openTransfer(tester, server);
      server.failAccountList = true;
      await payNow(tester);

      expect(find.text('이체 완료'), findsOneWidget);
      expect(find.text(staleText), findsOneWidget);

      server.failAccountList = false;
      await tapId(tester, 'transaction-create-refresh');
      expect(find.text(staleText), findsNothing);
      expect(find.text('이체 완료'), findsOneWidget);
      expect(calls(server, 'POST /transactions'), 1);
    });
  });

  group('sending again after an unknown result', () {
    Future<void> again(WidgetTester tester) async {
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-deposit');
      await enter(tester, 'deposit-amount-input', '9');
      await tapId(tester, 'deposit-submit-button');
    }

    testWidgets('a deposit: asks first, also after the dialog was closed and opened again', (tester) async {
      final server = newServer()..loseAnswer.add('POST /bankTransfers');
      await openDeposit(tester, server);
      await tapId(tester, 'deposit-submit-button');
      await tapId(tester, 'deposit-cancel-button'); // 닫기
      await tapId(tester, 'sidenav-home');
      server.loseAnswer.clear();

      await again(tester);
      expect(byId('unconfirmed-dialog'), findsOneWidget);
      expect(find.textContaining('First Bank에 입금 \$5'), findsOneWidget); // what it was, not the new amount
      expect(calls(server, 'POST /bankTransfers'), 1);

      await tapId(tester, 'unconfirmed-cancel');
      expect(calls(server, 'POST /bankTransfers'), 1);
      expect(byId('deposit-dialog'), findsOneWidget); // what was typed stays

      // Cancelling is not confirming: it asks again.
      await tapId(tester, 'deposit-submit-button');
      await tapId(tester, 'unconfirmed-send');
      expect(calls(server, 'POST /bankTransfers'), 2);

      // Confirmed once: not asked any more.
      await again(tester);
      expect(byId('unconfirmed-dialog'), findsNothing);
      expect(calls(server, 'POST /bankTransfers'), 3);
    });

    testWidgets('a deposit: 내역 확인 leads to the history and sends nothing', (tester) async {
      final server = newServer()..loseAnswer.add('POST /bankTransfers');
      await openDeposit(tester, server);
      await tapId(tester, 'deposit-submit-button');
      await tapId(tester, 'deposit-check-history');
      await again(tester);
      await tapId(tester, 'unconfirmed-check-history');
      expect(byId('deposit-dialog'), findsNothing);
      expect(find.text('입금 · First Bank'), findsOneWidget);
      expect(calls(server, 'POST /bankTransfers'), 1);
    });

    testWidgets('a transfer: asks before the password, and a deposit is not asked about', (tester) async {
      final server = newServer()..loseAnswer.add('POST /transactions');
      await openTransfer(tester, server);
      await payNow(tester);
      await tapId(tester, 'transaction-confirm-cancel'); // 닫기: back on the form
      server.loseAnswer.clear();

      await tapId(tester, 'transaction-create-submit-payment');
      expect(byId('unconfirmed-dialog'), findsOneWidget);
      expect(find.textContaining('Test Bob님에게 이체 \$5'), findsOneWidget);
      expect(byId('transaction-confirm-dialog'), findsNothing);
      await tapId(tester, 'unconfirmed-check-history');
      expect(byId('nav-transaction-tabs'), findsOneWidget);

      await again(tester); // a deposit
      expect(byId('unconfirmed-dialog'), findsNothing);
      expect(calls(server, 'POST /transactions'), 1);
    });

    testWidgets('a refusal, or a request that never left, is not asked about', (tester) async {
      final server = newServer();
      await openDeposit(tester, server);
      server.down = true;
      await tapId(tester, 'deposit-submit-button');
      server.down = false;
      server.moveMoneyStatus = 400;
      await tapId(tester, 'deposit-submit-button');
      server.moveMoneyStatus = null;
      await tapId(tester, 'deposit-submit-button');
      expect(byId('unconfirmed-dialog'), findsNothing);
      expect(server.transfers, hasLength(1));
    });

    testWidgets('another user is not asked about it', (tester) async {
      final server = newServer()..loseAnswer.add('POST /bankTransfers');
      await openDeposit(tester, server);
      await tapId(tester, 'deposit-submit-button');
      await tapId(tester, 'deposit-cancel-button');
      server.loseAnswer.clear();
      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      server.profile['id'] = 'u9';
      await enter(tester, 'signin-username', 'bbb');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');

      await again(tester);
      expect(byId('unconfirmed-dialog'), findsNothing);
    });
  });

  testWidgets('closing the password dialog does not bring the keyboard back over the form', (tester) async {
    await openTransfer(tester, newServer());
    await tester.tap(fieldIn('transaction-create-description-input'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tapId(tester, 'transaction-create-submit-payment');
    await tapId(tester, 'transaction-confirm-cancel');

    expect(byId('transaction-create-form'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  group('the accounts of the form', () {
    testWidgets('an account that was deleted somewhere else is not chosen any more (no crash)', (tester) async {
      final server = newServer(accounts: [
        testAccount('b1', bank: 'First Bank', balance: 20000),
        testAccount('b2', bank: 'Second Bank', balance: 20000),
        testAccount('b3', bank: 'Third Bank', balance: 20000),
      ])
        ..createTransactionStatus = 400
        ..createTransactionMessage = 'this bank account was deleted';
      await openTransfer(tester, server);
      await tapId(tester, 'transaction-create-my-account-b2');
      await payNow(tester);
      expect(find.text('삭제된 계좌입니다'), findsOneWidget);

      server.accounts.removeWhere((a) => a['id'] == 'b2');
      await tapId(tester, 'transaction-confirm-reselect');
      expect(byId('transaction-create-my-account-b2'), findsNothing);

      await tapId(tester, 'transaction-create-submit-payment');
      expect(tester.takeException(), isNull);
      expect(find.text('출금할 내 계좌를 선택하세요.'), findsOneWidget);
    });

    testWidgets('the same when the dialog is just closed after the refusal', (tester) async {
      final server = newServer(accounts: [
        testAccount('b1', bank: 'First Bank', balance: 20000),
        testAccount('b2', bank: 'Second Bank', balance: 20000),
        testAccount('b3', bank: 'Third Bank', balance: 20000),
      ])
        ..createTransactionStatus = 400
        ..createTransactionMessage = 'this bank account was deleted';
      await openTransfer(tester, server);
      await tapId(tester, 'transaction-create-my-account-b2');
      await payNow(tester);
      server.accounts.removeWhere((a) => a['id'] == 'b2');
      await tapId(tester, 'transaction-confirm-cancel');

      await tapId(tester, 'transaction-create-submit-payment');
      expect(tester.takeException(), isNull);
      expect(find.text('출금할 내 계좌를 선택하세요.'), findsOneWidget);
    });

    testWidgets('the other user has no account: 이체 is off and another user can be chosen', (tester) async {
      final server = newServer()..otherAccounts['u2'] = [];
      await openTransfer(tester, server);

      final button = tester.widget<FilledButton>(find.descendant(of: byId('transaction-create-submit-payment'), matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
      await tapId(tester, 'transaction-create-change-receiver');
      expect(byId('user-list-item-u2'), findsOneWidget);
    });
  });
}
