import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';
import '../bank_accounts/bank_accounts_controller.dart';
import '../bank_transfers/bank_transfers_controller.dart';
import '../transactions/transaction_feed_controller.dart';

/// Whether the money on the screens is what the server has.
enum MoneyStatus {
  /// As far as the app knows, yes.
  fresh,

  /// Something arrived (a "received" notification). The user is asked to refresh.
  changed,

  /// Reading it again now.
  loading,

  /// Reading it again failed, at least in part. The screens show older values.
  stale,

  /// The same, right after a deposit or a transfer the server approved.
  staleAfterWrite,
}

/// Reads the money again: the user's total, the bank accounts, the deposit and
/// withdrawal history, and the transaction lists. Each part that could be read is
/// shown; the status is [MoneyStatus.fresh] only when all of them could.
class MoneyStatusController extends Notifier<MoneyStatus> {
  Future<bool>? _running;

  /// More arrived while [_running] was on its way, so what it read may be old.
  bool _changedAgain = false;

  @override
  MoneyStatus build() {
    // Another user (or nobody) starts fresh.
    ref.watch(sessionProvider.select((s) => s.user?['id']));
    _running = null;
    _changedAgain = false;
    return MoneyStatus.fresh;
  }

  /// New money arrived, so the screens may be old.
  void changed() {
    if (_running != null) _changedAgain = true;
    if (state == MoneyStatus.fresh) state = MoneyStatus.changed;
  }

  /// Returns true when everything could be read. While one is running, a second
  /// call waits for it instead of asking the server again.
  Future<bool> refresh({bool afterWrite = false}) async {
    final running = _running;
    if (running != null) {
      final ok = await running;
      // What was read may be from before the write.
      return afterWrite && ref.mounted ? refresh(afterWrite: true) : ok;
    }
    final run = _read();
    _running = run;
    _changedAgain = false;
    final quiet = state == MoneyStatus.fresh;
    if (!quiet || afterWrite) state = MoneyStatus.loading;
    final ok = await run;
    if (!ref.mounted) return false;
    if (identical(_running, run)) _running = null;
    state = ok
        ? (_changedAgain ? MoneyStatus.changed : MoneyStatus.fresh)
        : afterWrite
            ? MoneyStatus.staleAfterWrite
            : MoneyStatus.stale;
    return ok;
  }

  Future<bool> _read() async {
    final results = await Future.wait([
      ref.read(sessionProvider.notifier).refreshUser(),
      ref.read(bankAccountsProvider.notifier).reload(),
      if (ref.exists(bankTransfersProvider)) ref.read(bankTransfersProvider.notifier).refresh(),
      for (final feed in TransactionFeed.values)
        if (ref.exists(transactionFeedProvider(feed)))
          ref.read(transactionFeedProvider(feed).notifier).refresh(),
    ]);
    return results.every((ok) => ok);
  }
}

final moneyStatusProvider =
    NotifierProvider<MoneyStatusController, MoneyStatus>(MoneyStatusController.new);

/// The bar above the tabs: money arrived, or the latest money could not be read.
/// It stays until everything has been read.
class MoneyNotice extends ConsumerWidget {
  const MoneyNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(moneyStatusProvider);
    final text = switch (status) {
      MoneyStatus.fresh => null,
      MoneyStatus.changed => '금액 변동이 생겼어요. 새로고침을 해주세요.',
      MoneyStatus.loading => '잔액을 불러오는 중입니다.',
      MoneyStatus.stale => '최신 잔액을 불러오지 못했습니다.',
      MoneyStatus.staleAfterWrite => moneyStaleAfterWriteText,
    };
    if (text == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return TestId(
      'amounts-changed-notice',
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: colors.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(text, style: TextStyle(color: colors.onSecondaryContainer))),
                TestId(
                  'amounts-changed-reload',
                  child: TextButton(
                    onPressed: status == MoneyStatus.loading
                        ? null
                        : () => ref.read(moneyStatusProvider.notifier).refresh(),
                    child: const Text('새로고침'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const moneyStaleAfterWriteText = '처리는 완료됐지만 최신 잔액을 불러오지 못했습니다.';
