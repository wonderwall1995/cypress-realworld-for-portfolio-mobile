import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// The signed-in user is `u1`.
FakeServer serverWith(List<Map<String, dynamic>> items) =>
    FakeServer(signedIn: true, accounts: [testAccount('b1')])..everyone.addAll(items);

Future<void> openDetail(WidgetTester tester, String id) => tapId(tester, 'transaction-item-$id');

Finder textIn(String id, String text) =>
    find.descendant(of: byId(id), matching: find.text(text));

Finder commentField(String id) =>
    find.descendant(of: byId('transaction-comment-input-$id'), matching: find.byType(TextField));

void main() {
  group('like', () {
    testWidgets('one tap likes it; the count goes up and the button is off', (tester) async {
      final server = serverWith([testTransaction('t1', likedBy: ['other'])]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');
      expect(textIn('transaction-like-count-t1', '1'), findsOneWidget);

      await tapId(tester, 'transaction-like-button-t1');

      expect(server.calls.where((c) => c == 'POST /likes/t1'), hasLength(1));
      expect(textIn('transaction-like-count-t1', '2'), findsOneWidget);
      expect(tester.widget<IconButton>(find.descendant(of: byId('transaction-like-button-t1'), matching: find.byType(IconButton))).onPressed, isNull);
      expect(find.byIcon(Icons.favorite), findsOneWidget); // filled heart
    });

    testWidgets('a transaction I already liked has the button off', (tester) async {
      final server = serverWith([testTransaction('t1', likedBy: ['u1'])]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');

      expect(tester.widget<IconButton>(find.descendant(of: byId('transaction-like-button-t1'), matching: find.byType(IconButton))).onPressed, isNull);
      expect(server.calls, isNot(contains('POST /likes/t1')));
    });

    testWidgets('two quick taps send only one like (the server would accept both)', (tester) async {
      final server = serverWith([testTransaction('t1')]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');

      await tester.tap(byId('transaction-like-button-t1'));
      await tester.tap(byId('transaction-like-button-t1'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(server.calls.where((c) => c == 'POST /likes/t1'), hasLength(1));
    });

    testWidgets('a failed like shows a message and can be tried again', (tester) async {
      final server = serverWith([testTransaction('t1')])..failLike = true;
      await pumpApp(tester, server);
      await openDetail(tester, 't1');

      await tapId(tester, 'transaction-like-button-t1');

      expect(find.text('좋아요를 누르지 못했습니다.'), findsOneWidget);
      expect(textIn('transaction-like-count-t1', '0'), findsOneWidget);

      server.failLike = false;
      await tapId(tester, 'transaction-like-button-t1');
      expect(textIn('transaction-like-count-t1', '1'), findsOneWidget);
    });

    testWidgets('the count in the list is new after going back', (tester) async {
      final server = serverWith([testTransaction('t1')]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');
      await tapId(tester, 'transaction-like-button-t1');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.descendant(of: byId('transaction-item-t1'), matching: find.text('1')), findsWidgets);
      final likeCount = find.descendant(of: byId('transaction-item-t1'), matching: byId('transaction-like-count'));
      expect(find.descendant(of: likeCount, matching: find.text('1')), findsOneWidget);
    });
  });

  group('comments', () {
    testWidgets('shows the comments in order, with the count', (tester) async {
      final server = serverWith([testTransaction('t1', commentTexts: ['First one', 'Second one'])]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');

      expect(find.text('댓글 2'), findsOneWidget);
      expect(byId('comments-list'), findsOneWidget);
      expect(byId('comment-list-item-c0'), findsOneWidget);
      expect(find.text('First one').evaluate().isNotEmpty, isTrue);
      final first = tester.getTopLeft(find.text('First one'));
      final second = tester.getTopLeft(find.text('Second one'));
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('no comments says so', (tester) async {
      await pumpApp(tester, serverWith([testTransaction('t1')]));
      await openDetail(tester, 't1');

      expect(byId('comments-empty'), findsOneWidget);
      expect(find.text('아직 댓글이 없습니다.'), findsOneWidget);
    });

    testWidgets('the send button is off until there is text', (tester) async {
      await pumpApp(tester, serverWith([testTransaction('t1')]));
      await openDetail(tester, 't1');
      IconButton send() => tester.widget<IconButton>(
          find.descendant(of: byId('transaction-comment-submit-t1'), matching: find.byType(IconButton)));

      expect(send().onPressed, isNull);

      await tester.enterText(commentField('t1'), '   ');
      await tester.pump();
      expect(send().onPressed, isNull);

      await tester.enterText(commentField('t1'), 'Hi');
      await tester.pump();
      expect(send().onPressed, isNotNull);
    });

    testWidgets('sending posts the trimmed text, clears the box, and shows the comment', (tester) async {
      final server = serverWith([testTransaction('t1')]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');

      await tester.enterText(commentField('t1'), '  Nice one  ');
      await tester.pump();
      await tapId(tester, 'transaction-comment-submit-t1');

      expect(server.bodies['POST /comments/t1'], {'content': 'Nice one'});
      expect(tester.widget<TextField>(commentField('t1')).controller!.text, '');
      expect(find.text('Nice one'), findsOneWidget);
      expect(find.text('댓글 1'), findsOneWidget);
      expect(byId('comments-empty'), findsNothing);
    });

    testWidgets('the keyboard send key also sends', (tester) async {
      final server = serverWith([testTransaction('t1')]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');

      await tester.enterText(commentField('t1'), 'By keyboard');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(server.bodies['POST /comments/t1'], {'content': 'By keyboard'});
    });

    testWidgets('a failed send keeps the text and shows a message', (tester) async {
      final server = serverWith([testTransaction('t1')])..failComment = true;
      await pumpApp(tester, server);
      await openDetail(tester, 't1');

      await tester.enterText(commentField('t1'), 'Keep me');
      await tester.pump();
      await tapId(tester, 'transaction-comment-submit-t1');

      expect(find.text('댓글을 남기지 못했습니다.'), findsOneWidget);
      expect(tester.widget<TextField>(commentField('t1')).controller!.text, 'Keep me');
    });

    testWidgets('the comment count in the list is new after going back', (tester) async {
      final server = serverWith([testTransaction('t1')]);
      await pumpApp(tester, server);
      await openDetail(tester, 't1');
      await tester.enterText(commentField('t1'), 'Hello');
      await tester.pump();
      await tapId(tester, 'transaction-comment-submit-t1');

      await tester.pageBack();
      await tester.pumpAndSettle();

      final count = find.descendant(of: byId('transaction-item-t1'), matching: byId('transaction-comment-count'));
      expect(find.descendant(of: count, matching: find.text('1')), findsOneWidget);
    });
  });
}
