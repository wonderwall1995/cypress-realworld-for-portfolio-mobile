import '../../core/header_credit.dart';
import 'package:flutter/material.dart';

import '../../core/test_id.dart';
import 'transaction_feed_controller.dart';
import 'transaction_filter_bar.dart';
import 'transaction_list_view.dart';

/// The "홈" tab: a "새 거래" button on the left of the tab row, then three
/// lists (전체, 내 거래) under tabs.
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TransactionFeed.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('홈'),
          actions: const [HeaderCredit()],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: TestId(
              'nav-transaction-tabs',
              child: TabBar(
                tabs: [
                  for (final feed in TransactionFeed.values)
                    TestId(feed.tabId, child: Tab(text: feed.label)),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            const TransactionFilterBar(),
            Expanded(
              child: TabBarView(
                children: [
                  for (final feed in TransactionFeed.values) TransactionListView(feed: feed),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
