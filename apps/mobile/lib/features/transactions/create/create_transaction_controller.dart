import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/session.dart';
import '../../bank_accounts/other_account.dart';
import '../../money/money_status.dart';
import '../../settings/privacy.dart';
import 'user_summary.dart';

/// Users to choose from. [query] is empty for everyone, or a search text.
final usersProvider =
    FutureProvider.autoDispose.family<List<UserSummary>, String>((ref, query) async {
  final raw = await ref.watch(apiClientProvider).getUsers(query: query);
  return readAnswer(() => raw.map(UserSummary.fromJson).toList());
});

/// The bank accounts of the user who would receive the money.
final otherAccountsProvider =
    FutureProvider.autoDispose.family<List<OtherAccount>, String>((ref, userId) async {
  final raw = await ref.watch(apiClientProvider).getAccountsOfUser(userId);
  return readAnswer(() => raw.map(OtherAccount.fromJson).toList());
});

enum CreateStep { selectContact, payment, complete }

/// What was created, for the last step.
class CreatedTransaction {
  const CreatedTransaction({
    required this.dollars,
    required this.description,
    required this.receiver,
  });

  final int dollars;
  final String description;
  final UserSummary receiver;
}

class CreateState {
  const CreateState({this.step = CreateStep.selectContact, this.receiver, this.created});

  final CreateStep step;
  final UserSummary? receiver;
  final CreatedTransaction? created;
}

/// The three steps of "이체": choose a user, enter the amount, done.
/// Starts again each time the screen is opened.
class CreateTransactionController extends Notifier<CreateState> {
  @override
  CreateState build() => const CreateState();

  void selectReceiver(UserSummary user) {
    state = CreateState(step: CreateStep.payment, receiver: user);
  }

  /// Step 2 back to step 1.
  void backToContacts() {
    state = const CreateState();
  }

  /// "다른 거래 만들기"
  void startOver() {
    state = const CreateState();
  }

  /// Throws [ApiException] when the server refuses.
  Future<void> submit({
    required int dollars,
    required String description,
    required String myAccountId,
    required String otherAccountId,
    required String password,
  }) async {
    final receiver = state.receiver;
    if (receiver == null) return;

    final session = ref.read(apiClientProvider).sessionNumber;
    await ref.read(apiClientProvider).createTransaction(
          receiverId: receiver.id,
          description: description,
          amount: dollars,
          myAccountId: myAccountId,
          otherAccountId: otherAccountId,
          password: password,
          // The user's own choice in the settings.
          privacyLevel: _privacyLevel(),
        );

    // The user left or signed out while it was on its way. It is done, but there
    // is no screen to show it on.
    if (!ref.mounted || session != ref.read(apiClientProvider).sessionNumber) return;
    state = CreateState(
      step: CreateStep.complete,
      receiver: receiver,
      created: CreatedTransaction(
        dollars: dollars,
        description: description,
        receiver: receiver,
      ),
    );

    // Approved. Reading the money again is a separate thing: when it fails the
    // transfer is still done, and only the reading is offered again.
    unawaited(ref.read(moneyStatusProvider.notifier).refresh(afterWrite: true));
  }

  String _privacyLevel() {
    return privacyOf(ref.read(sessionProvider).user?['defaultPrivacyLevel']);
  }
}

final createTransactionProvider =
    NotifierProvider.autoDispose<CreateTransactionController, CreateState>(
  CreateTransactionController.new,
);
