import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// Requests no longer exist (the server refuses new ones), but an old one can
/// still be in the list. It is shown like any transaction, with nothing to press.
void main() {
  testWidgets('an old pending request to me has no 수락 / 거절 buttons', (tester) async {
    final server = FakeServer(signedIn: true, accounts: [testAccount('b1', balance: 20000)])
      ..everyone.add(testTransaction(
        'r1',
        sender: 'Bob Test',
        receiver: 'Ada Kim',
        description: 'Share of dinner',
        amount: 700,
        requestStatus: 'pending',
        status: 'pending',
        senderId: 'u2',
        receiverId: 'u1',
      ));
    await pumpApp(tester, server);
    await tapId(tester, 'transaction-item-r1');

    expect(byId('transaction-detail-header'), findsOneWidget);
    expect(byId('transaction-accept-request-r1'), findsNothing);
    expect(byId('transaction-reject-request-r1'), findsNothing);
    expect(server.calls.where((c) => c.startsWith('PATCH')), isEmpty);
  });
}
