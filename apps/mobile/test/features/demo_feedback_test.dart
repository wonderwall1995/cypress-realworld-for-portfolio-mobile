import 'package:cypress_realworld_for_personal_portfolio_mobile/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';
import '../support/transfer_helpers.dart';

FakeServer newServer({List<Map<String, dynamic>>? accounts}) => FakeServer(
  signedIn: true,
  accounts: accounts ??
      [
        testAccount('b1', bank: 'First Bank', balance: 20000),
        testAccount('b2', bank: 'Small Bank', balance: 500),
        testAccount('b3', bank: 'Empty Bank', balance: 0),
      ],
)..users.add(testOtherUser('u2', 'Bob', 'Test', username: 'bob'));

Future<void> toForm(WidgetTester tester, FakeServer server) async {
  await pumpApp(tester, server);
  await tapId(tester, 'sidenav-my-account');
  await tapId(tester, 'sidenav-transfer');
  await tapId(tester, 'user-list-item-u2');
}

Text textOf(WidgetTester tester, String id) =>
    tester.widget<Text>(find.descendant(of: byId(id), matching: find.byType(Text)));

void main() {
  group('공개 / 비공개', () {
    for (final (saved, word, icon) in [
      (null, '공개', Icons.public),
      ('public', '공개', Icons.public),
      ('private', '비공개', Icons.lock_outline),
      ('contacts', '비공개', Icons.lock_outline),
    ]) {
      testWidgets('the bank accounts screen says what a saved "$saved" means', (tester) async {
        final server = newServer();
        server.profile['defaultPrivacyLevel'] = saved;
        await pumpApp(tester, server);
        await tapId(tester, 'sidenav-bankaccounts');

        expect(textOf(tester, 'bankaccount-privacy').data, '내 이체: $word');
        expect(find.byIcon(icon), findsOneWidget);
      });
    }

    testWidgets('변경 opens the settings, and the new choice is shown after saving', (tester) async {
      await pumpApp(tester, newServer());
      await tapId(tester, 'sidenav-bankaccounts');
      await tapId(tester, 'bankaccount-privacy-change');
      await tapId(tester, 'user-settings-privacy-private');
      await tapId(tester, 'user-settings-submit');
      await goBack(tester);

      expect(textOf(tester, 'bankaccount-privacy').data, '내 이체: 비공개');
    });

    testWidgets('a new user has no saved choice: the settings show 공개, and saving keeps it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      expect(server.profile.containsKey('defaultPrivacyLevel'), isFalse);
      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-user-settings');
      final chip = find.descendant(of: byId('user-settings-privacy-public'), matching: find.byType(ChoiceChip));
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      await tapId(tester, 'user-settings-submit');

      expect(server.profile['defaultPrivacyLevel'], 'public');
    });

    testWidgets('is there without an account too', (tester) async {
      await pumpApp(tester, newServer(accounts: []));
      await tapId(tester, 'sidenav-bankaccounts');
      expect(byId('bankaccount-privacy'), findsOneWidget);
    });

    testWidgets('only my own transfers say it, in the list and in the detail', (tester) async {
      final server = newServer()
        ..everyone.addAll([
          testTransaction('sent', senderId: 'u1')..['privacyLevel'] = 'private',
          testTransaction('got', receiverId: 'u1')..['privacyLevel'] = 'public',
          testTransaction('others')..['privacyLevel'] = 'public',
          testTransaction('deposit', senderId: 'external-deposit', receiverId: 'u1')..['privacyLevel'] = 'private',
          testTransaction('unsaid', senderId: 'u1'),
        ]);
      await pumpApp(tester, server);

      expect(textOf(tester, 'transaction-privacy-sent').data, '비공개');
      expect(textOf(tester, 'transaction-privacy-got').data, '공개');
      for (final id in ['others', 'deposit', 'unsaid']) {
        expect(byId('transaction-item-$id'), findsOneWidget);
        expect(byId('transaction-privacy-$id'), findsNothing);
      }
      await tapId(tester, 'transaction-item-sent');
      expect(byId('transaction-detail-header'), findsOneWidget);
      expect(textOf(tester, 'transaction-privacy-sent').data, '비공개');
    });

    testWidgets('a narrow phone with big letters has room for it', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final server = newServer()
        ..everyone.add(testTransaction('sent', senderId: 'u1', amount: 123456789)..['privacyLevel'] = 'private');
      await pumpApp(tester, server, size: const Size(320, 2000));
      expect(tester.takeException(), isNull);
      expect(byId('transaction-privacy-sent'), findsOneWidget);
    });
  });

  group('who can be paid', () {
    testWidgets('a user without a bank account is not in the list; one the server says nothing about is', (tester) async {
      final server = newServer()
        ..users.addAll([
          testOtherUser('u3', 'None', 'Test')..['hasBankAccount'] = false,
          testOtherUser('u4', 'Some', 'Test')..['hasBankAccount'] = true,
        ]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-transfer');

      expect(byId('user-list-item-u2'), findsOneWidget);
      expect(byId('user-list-item-u3'), findsNothing);
      expect(byId('user-list-item-u4'), findsOneWidget);
    });

    testWidgets('when nobody is left the list says so', (tester) async {
      final server = newServer()..users.clear();
      server.users.add(testOtherUser('u3', 'None', 'Test')..['hasBankAccount'] = false);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-transfer');
      expect(byId('user-list-empty'), findsOneWidget);
    });
  });

  testWidgets('the balance I can send from is green: there is money, and enough of it', (tester) async {
    await toForm(tester, newServer());
    bool green(String id) =>
        textOf(tester, 'transaction-create-my-account-$id-row-balance').style?.color == Colors.green.shade800;

    expect([green('b1'), green('b2'), green('b3')], [true, true, false]);
    await enter(tester, 'transaction-create-amount-input', '6');
    await tester.pump();
    expect([green('b1'), green('b2'), green('b3')], [true, false, false]);
    await enter(tester, 'transaction-create-amount-input', '5');
    await tester.pump();
    expect([green('b1'), green('b2'), green('b3')], [true, true, false]);
  });

  testWidgets('a transfer without a memo is sent, and nothing shows an empty memo', (tester) async {
    final server = newServer();
    await toForm(tester, server);
    await enter(tester, 'transaction-create-amount-input', '5');
    await tapId(tester, 'transaction-create-my-account-b1');
    await payNow(tester);

    expect(byId('transaction-create-result'), findsOneWidget);
    expect(find.textContaining('메모'), findsNothing);
    expect(server.mine.single['description'], '');

    expect(find.text('다른 이체 진행하기'), findsOneWidget);
    await tapId(tester, 'new-transaction-return-to-transactions');
    await tapId(tester, 'nav-personal-tab');
    final id = server.mine.single['id'] as String;
    expect(find.descendant(of: byId('transaction-item-$id'), matching: find.text('')), findsNothing);
    await tapId(tester, 'transaction-item-$id');
    expect(byId('transaction-description'), findsNothing);
  });

  testWidgets('the password dialog: my account, an arrow, the other account, a bigger amount', (tester) async {
    await toForm(tester, newServer());
    await enter(tester, 'transaction-create-amount-input', '25');
    await tapId(tester, 'transaction-create-my-account-b1');
    await tapId(tester, 'transaction-create-submit-payment');

    expect(textOf(tester, 'transaction-confirm-from').data, 'First Bank ····6789');
    expect(textOf(tester, 'transaction-confirm-to').data, 'Test Bob님 Other Bank ····5555');
    expect(textOf(tester, 'transaction-confirm-amount').data, '\$25');
    final ys = [
      byId('transaction-confirm-from'),
      find.byIcon(Icons.arrow_downward),
      byId('transaction-confirm-to'),
      byId('transaction-confirm-amount'),
    ].map((f) => tester.getRect(f)).toList();
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i].top, greaterThanOrEqualTo(ys[i - 1].bottom), reason: 'line $i');
    }
    expect(
      textOf(tester, 'transaction-confirm-amount').style!.fontSize,
      textOf(tester, 'transaction-confirm-from').style!.fontSize! + 3,
    );
    final field = tester.widget<TextField>(
      find.descendant(of: byId('transaction-confirm-password'), matching: find.byType(TextField)),
    );
    expect(field.decoration!.labelText, '계정의 비밀번호');
  });

  group('the round 만들기 button', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('is a circle at the bottom right, over the tabs, with the words inside (letters x$scale)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(tester, newServer(), size: const Size(360, 740));
        await tapId(tester, 'sidenav-bankaccounts');
        expect(tester.takeException(), isNull);

        final button = find.descendant(of: byId('bankaccount-new'), matching: find.byType(FilledButton));
        final rect = tester.getRect(button);
        expect(rect.width, rect.height);
        expect(tester.widget<FilledButton>(button).style!.shape!.resolve({}), isA<CircleBorder>());
        expect(360 - rect.right, inInclusiveRange(8, 24));
        expect(tester.getTopLeft(find.byType(NavigationBar)).dy - rect.bottom, inInclusiveRange(8, 24));

        // The corners of the words are inside the circle.
        final words = tester.getRect(find.text('+\n만들기'));
        for (final corner in [words.topLeft, words.topRight, words.bottomLeft, words.bottomRight]) {
          expect((corner - rect.center).distance, lessThanOrEqualTo(rect.width / 2));
        }
        // The same letters as the button that was in the header.
        final style = tester
            .widget<RichText>(find.descendant(of: button, matching: find.byType(RichText)))
            .text
            .style!;
        expect(style.fontSize, appTheme.textTheme.labelLarge?.fontSize ?? 14);
      });
    }

    testWidgets('the 삭제 button of the last account can be scrolled clear of it', (tester) async {
      final accounts = [for (var i = 0; i < 12; i++) testAccount('b$i')];
      await pumpApp(tester, newServer(accounts: accounts), size: const Size(360, 640));
      await tapId(tester, 'sidenav-bankaccounts');
      await tester.drag(byId('bankaccount-list'), const Offset(0, -5000));
      await tester.pumpAndSettle();

      final delete = find.descendant(of: byId('bankaccount-list-item-b11'), matching: byId('bankaccount-delete'));
      expect(tester.getRect(delete).overlaps(tester.getRect(byId('bankaccount-new'))), isFalse);
    });
  });

  group('comments', () {
    FakeServer withComments(List<(String, String)> comments) {
      final t = testTransaction('t1', senderId: 's1', receiverId: 'r1', sender: '김 보냄', receiver: '이 받음');
      t['comments'] = [
        for (final (i, (user, text)) in comments.indexed)
          {'id': 'c$i', 'content': text, 'userId': user, 'createdAt': '2026-11-09T18:51:10.224Z'},
      ];
      return newServer()
        ..everyone.add(t)
        ..users.add(testOtherUser('u7', '댓글', '최'));
    }

    testWidgets('each says who wrote it', (tester) async {
      final server = withComments([('s1', 'a'), ('r1', 'b'), ('u1', 'c'), ('u7', 'd'), ('gone', 'e')]);
      await pumpApp(tester, server);
      await tapId(tester, 'transaction-item-t1');

      expect([for (var i = 0; i < 5; i++) textOf(tester, 'comment-author-c$i').data], [
        '김 보냄',
        '이 받음',
        isNotEmpty,
        '최 댓글',
        '',
      ]);
    });

    testWidgets('the name the server sends is shown, and the list of users is not asked', (tester) async {
      final server = withComments([('s1', 'a'), ('u7', 'b'), ('u7', 'c')]);
      final comments = server.everyone.single['comments'] as List;
      (comments[0] as Map)['userFullName'] = '서버 이름';
      (comments[1] as Map)['userFullName'] = '박 댓글';
      (comments[2] as Map)['userFullName'] = '';
      await pumpApp(tester, server);
      await tapId(tester, 'transaction-item-t1');

      expect([for (var i = 0; i < 3; i++) textOf(tester, 'comment-author-c$i').data], ['서버 이름', '박 댓글', '']);
      expect(server.userQueries, isEmpty);
    });

    testWidgets('the list of users is asked only when a name is not known', (tester) async {
      final server = withComments([('s1', 'a'), ('u1', 'c')]);
      await pumpApp(tester, server);
      await tapId(tester, 'transaction-item-t1');
      expect(server.userQueries, isEmpty);
    });

    testWidgets('the times stand in one column; a name longer than the room ends with …', (tester) async {
      final server = withComments([('s1', 'a'), ('u8', 'b'), ('u9', 'c')])
        ..users.addAll([
          testOtherUser('u8', 'jwfdoiabcdefghijk', ''),
          testOtherUser('u9', 'jwfdoiabcdefghijkl and more', ''),
        ]);
      // (The letters of the test font are all square, so it needs more room than a phone's.)
      await pumpApp(tester, server);
      await tapId(tester, 'transaction-item-t1');

      bool cut(int i) => tester
          .renderObject<RenderParagraph>(
            find.descendant(of: byId('comment-author-c$i'), matching: find.byType(RichText)),
          )
          .didExceedMaxLines;
      expect([cut(0), cut(1), cut(2)], [false, false, true]);
      final lefts = [for (var i = 0; i < 3; i++) tester.getTopLeft(byId('comment-time-c$i')).dx];
      expect(lefts.toSet(), hasLength(1));
      expect(lefts.first - tester.getTopRight(byId('comment-author-c2')).dx, 8);
      // Under the comment, on the line of the time.
      expect(tester.getCenter(byId('comment-author-c0')).dy, tester.getCenter(byId('comment-time-c0')).dy);
      expect(tester.getTopLeft(byId('comment-author-c0')).dy, greaterThan(tester.getBottomLeft(find.text('a')).dy));
    });

    testWidgets('the text is 2 bigger than before, and nothing runs out with big letters', (tester) async {
      await pumpApp(tester, withComments([('u7', 'd')]));
      await tapId(tester, 'transaction-item-t1');
      expect(tester.widget<Text>(find.text('d')).style!.fontSize, 16);

      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 1200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the empty field says only 댓글', (tester) async {
      await pumpApp(tester, withComments([]));
      await tapId(tester, 'transaction-item-t1');
      final field = tester.widget<TextField>(
        find.descendant(of: byId('transaction-comment-input-t1'), matching: find.byType(TextField)),
      );
      expect(field.decoration!.hintText, '댓글');
    });
  });

  testWidgets('the like button is highlighted only on a transaction I liked', (tester) async {
    final server = newServer()
      ..everyone.addAll([
        testTransaction('mine', likedBy: ['u1']),
        testTransaction('others', likedBy: ['x', 'y']),
      ]);
    await pumpApp(tester, server);
    // In the list nothing is highlighted.
    expect(find.byIcon(Icons.thumb_up), findsNothing);

    Color colorOf(String id) => IconTheme.of(
      tester.element(find.descendant(of: byId('transaction-like-button-$id'), matching: find.byType(Icon))),
    ).color!;

    await tapId(tester, 'transaction-item-mine');
    expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    expect(colorOf('mine'), appColorScheme.primary);
    await goBack(tester);

    await tapId(tester, 'transaction-item-others');
    expect(find.byIcon(Icons.thumb_up), findsNothing);
    expect(colorOf('others'), appColorScheme.onSurfaceVariant);
    await tapId(tester, 'transaction-like-button-others');
    expect(colorOf('others'), appColorScheme.primary);
  });
}
