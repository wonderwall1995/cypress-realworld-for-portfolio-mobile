import 'dart:async';

import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/session.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_feed_controller.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_filters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

/// Late answers, without a screen: the order of the answers is in the test's hands.
final feed = transactionFeedProvider(TransactionFeed.everyone);

List<Map<String, dynamic>> items(String prefix, int n) =>
    [for (var i = 0; i < n; i++) testTransaction('$prefix$i', description: '$prefix$i')];

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<ProviderContainer> start(FakeServer server) async {
  final c = ProviderContainer(
    retry: noRetry,
    overrides: [apiClientProvider.overrideWithValue(server.client())],
  );
  addTearDown(c.dispose);
  c.listen(sessionProvider, (_, __) {});
  c.listen(feed, (_, __) {});
  await settle();
  return c;
}

List<String> ids(ProviderContainer c) => c.read(feed).requireValue.items.map((t) => t.id).toList();

void main() {
  late FakeServer server;
  late Completer<void> hold;

  setUp(() {
    server = FakeServer(signedIn: true)..everyone.addAll(items('a', 25));
    hold = Completer<void>();
  });

  /// The next answer of the list waits until [hold] is completed.
  void holdNext() {
    var first = true;
    server.gate = (key) {
      if (key != 'GET /transactions/public' || !first) return null;
      first = false;
      return hold.future;
    };
  }

  test('the next page is added to the list', () async {
    final c = await start(server);
    await c.read(feed.notifier).loadMore();
    expect(ids(c), hasLength(20));
    expect(ids(c).last, 'a19');
  });

  test('filters change while the next page is on its way: it is dropped', () async {
    final c = await start(server);
    holdNext();
    final more = c.read(feed.notifier).loadMore();
    await settle();
    server.filtered.addAll(items('filtered', 2));
    c.read(transactionFiltersProvider.notifier).setDate(DateTime(2026, 3, 5), null);
    await settle();
    expect(ids(c), ['filtered0', 'filtered1']);

    hold.complete();
    await more;
    await settle();
    expect(ids(c), ['filtered0', 'filtered1']);
  });

  test('a refresh while the next page is on its way: it is dropped', () async {
    final c = await start(server);
    holdNext();
    final more = c.read(feed.notifier).loadMore();
    await settle();
    server.everyone.insert(0, testTransaction('new'));
    expect(await c.read(feed.notifier).refresh(), isTrue);
    expect(ids(c).first, 'new');

    hold.complete();
    await more;
    expect(ids(c), hasLength(10));
    expect(ids(c).first, 'new');
    // The list can go on.
    await c.read(feed.notifier).loadMore();
    expect(ids(c), hasLength(20));
  });

  test('a refresh that fails while the next page is on its way: the list stays and can go on', () async {
    final c = await start(server);
    holdNext();
    final more = c.read(feed.notifier).loadMore();
    await settle();
    server.failPages.add(1);
    expect(await c.read(feed.notifier).refresh(), isFalse);
    hold.complete();
    await more;
    server.failPages.clear();

    expect(ids(c), hasLength(10));
    await c.read(feed.notifier).loadMore();
    expect(ids(c), hasLength(20));
  });

  test('another user while the next page is on its way: it is dropped', () async {
    final c = await start(server);
    holdNext();
    final more = c.read(feed.notifier).loadMore();
    await settle();

    server.everyone
      ..clear()
      ..addAll(items('b', 3));
    server.profile['id'] = 'u9';
    await c.read(sessionProvider.notifier).signIn(username: 'b', password: 'pw-1234', remember: false);
    await settle();
    expect(ids(c), ['b0', 'b1', 'b2']);

    hold.complete();
    await more;
    await settle();
    expect(ids(c), ['b0', 'b1', 'b2']);
  });

  test('an older refresh that answers last does not win', () async {
    final c = await start(server);
    holdNext();
    final older = c.read(feed.notifier).refresh();
    await settle();
    server.everyone.insert(0, testTransaction('new'));
    await c.read(feed.notifier).refresh();
    hold.complete();
    await older;
    expect(ids(c).first, 'new');
  });

  test('a transaction made in the meantime does not make another show twice', () async {
    final c = await start(server);
    server.everyone.insert(0, testTransaction('new')); // a9 moves to page 2
    await c.read(feed.notifier).loadMore();

    final all = ids(c);
    expect(all.toSet(), hasLength(all.length));
    expect(all.where((id) => id == 'a9'), hasLength(1));
  });
}
