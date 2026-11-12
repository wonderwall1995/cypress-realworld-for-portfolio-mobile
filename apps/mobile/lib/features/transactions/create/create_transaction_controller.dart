import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/session.dart';
import '../../bank_accounts/bank_accounts_controller.dart';
import '../../bank_accounts/other_account.dart';
import '../transaction_feed_controller.dart';
import 'user_summary.dart';

/// Users to choose from. [query] is empty for everyone, or a search text.
final usersProvider =
    FutureProvider.autoDispose.family<List<UserSummary>, String>((ref, query) async {
  final raw = await ref.watch(apiClientProvider).getUsers(query: query);
  return raw.map(UserSummary.fromJson).toList();
});

/// The bank accounts of the user who would receive the money.
final otherAccountsProvider =
    FutureProvider.autoDispose.family<List<OtherAccount>, String>((ref, userId) async {
  final raw = await ref.watch(apiClientProvider).getAccountsOfUser(userId);
  return raw.map(OtherAccount.fromJson).toList();
});

enum CreateStep { selectContact, payment, complete }

/// What was created, for the last step.
class CreatedTransaction {
  const CreatedTransaction({
    required this.isPayment,
    required this.dollars,
    required this.description,
    required this.receiver,
  });

  final bool isPayment;
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

/// The three steps of "새 거래": choose a user, enter the amount, done.
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

  /// Throws [ApiException] when the server refuses. [type] is `payment` or `request`.
  /// A payment needs [otherAccountId] and the user's [password]; a request needs
  /// only [myAccountId] (the account that will receive the money).
  Future<void> submit({
    required String type,
    required int dollars,
    required String description,
    required String myAccountId,
    String? otherAccountId,
    String? password,
  }) async {
    final receiver = state.receiver;
    if (receiver == null) return;

    await ref.read(apiClientProvider).createTransaction(
          transactionType: type,
          receiverId: receiver.id,
          description: description,
          amount: dollars,
          myAccountId: myAccountId,
          otherAccountId: otherAccountId,
          password: password,
          // The user's own choice in the settings (public when there is none).
          privacyLevel: _privacyLevel(),
        );

    state = CreateState(
      step: CreateStep.complete,
      receiver: receiver,
      created: CreatedTransaction(
        isPayment: type == 'payment',
        dollars: dollars,
        description: description,
        receiver: receiver,
      ),
    );

    // The lists, the bank accounts and the balance have changed.
    ref.invalidate(transactionFeedProvider);
    await ref.read(bankAccountsProvider.notifier).reload();
    await ref.read(sessionProvider.notifier).refreshUser();
  }

  String _privacyLevel() {
    final saved = ref.read(sessionProvider).user?['defaultPrivacyLevel'];
    return saved is String && const ['public', 'private'].contains(saved) ? saved : 'public';
  }
}

final createTransactionProvider =
    NotifierProvider.autoDispose<CreateTransactionController, CreateState>(
  CreateTransactionController.new,
);
