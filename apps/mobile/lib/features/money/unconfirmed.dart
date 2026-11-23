import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';

enum MoneyKind { deposit, transfer }

/// What was sent without an answer, by kind: a short text for the user.
///
/// It belongs to what the user approved, not to a dialog, so it stays when the
/// dialog is closed or another screen is opened. It ends when the user says they
/// looked, or with the sign-in. (It does not survive closing the app; only an id
/// that the server knows could do that.)
class UnconfirmedMoney extends Notifier<Map<MoneyKind, String>> {
  @override
  Map<MoneyKind, String> build() {
    ref.watch(sessionProvider.select((s) => s.user?['id']));
    return const {};
  }

  void add(MoneyKind kind, String what) => state = {...state, kind: what};

  void clear(MoneyKind kind) => state = {...state}..remove(kind);
}

final unconfirmedMoneyProvider =
    NotifierProvider<UnconfirmedMoney, Map<MoneyKind, String>>(UnconfirmedMoney.new);

enum BeforeSending { send, history, cancel }

/// Asks before the same kind is sent again while the result of an earlier one is not
/// known. Answers [BeforeSending.send] at once when there is nothing to ask.
Future<BeforeSending> askBeforeSending(BuildContext context, WidgetRef ref, MoneyKind kind) async {
  final what = ref.read(unconfirmedMoneyProvider)[kind];
  if (what == null) return BeforeSending.send;
  final notifier = ref.read(unconfirmedMoneyProvider.notifier);
  final answer = await showDialog<BeforeSending>(
    context: context,
    barrierDismissible: false,
    builder: (context) => TestId(
      'unconfirmed-dialog',
      child: AlertDialog(
        scrollable: true,
        title: const Text('앞선 요청의 결과를 확인하지 못했습니다'),
        content: Text(
          '$what\n\n이미 처리됐을 수 있습니다. 내역에 없는 것을 확인한 뒤에 보내세요. '
          '금액과 시각이 비슷한 내역이 다른 거래일 수도 있습니다.',
        ),
        actions: [
          TestId(
            'unconfirmed-cancel',
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(BeforeSending.cancel),
              child: const Text('취소'),
            ),
          ),
          TestId(
            'unconfirmed-send',
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(BeforeSending.send),
              child: const Text('확인했습니다. 보내기'),
            ),
          ),
          TestId(
            'unconfirmed-check-history',
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(BeforeSending.history),
              child: const Text('내역 확인'),
            ),
          ),
        ],
      ),
    ),
  );
  if (answer == BeforeSending.send) notifier.clear(kind);
  return answer ?? BeforeSending.cancel;
}
