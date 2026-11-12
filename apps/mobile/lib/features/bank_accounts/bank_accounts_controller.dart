import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session.dart';
import 'bank_account.dart';

/// The signed-in user's bank accounts.
///
/// Loads again when the signed-in user changes. When nobody is signed in the
/// list is empty and the server is not called.
class BankAccountsController extends AsyncNotifier<List<BankAccount>> {
  @override
  Future<List<BankAccount>> build() async {
    final userId = ref.watch(sessionProvider.select((s) => s.user?['id']));
    if (userId == null) return const [];
    return _fetch();
  }

  /// A deleted account stays on the server (soft delete). The newer server marks it
  /// `visible: false` and does not return it; an older one returned it with
  /// `isDeleted: true`. The app only works with accounts in use, so it hides both.
  Future<List<BankAccount>> _fetch() async {
    final raw = await ref.read(apiClientProvider).getBankAccounts();
    return raw
        .where((json) => json['isDeleted'] != true && json['visible'] != false)
        .map(BankAccount.fromJson)
        .toList();
  }

  /// Loads again without going through the loading state (the screen stays).
  Future<void> reload() async {
    state = await AsyncValue.guard(_fetch);
  }

  /// Throws [ApiException] when the server refuses.
  Future<void> create({
    required String bankName,
    required String accountNumber,
  }) async {
    final json = await ref.read(apiClientProvider).createBankAccount(
          bankName: bankName,
          accountNumber: accountNumber,
        );
    state = AsyncData([...?state.value, BankAccount.fromJson(json)]);
  }

  /// Throws [ApiException] when the server refuses.
  Future<void> remove(String id) async {
    await ref.read(apiClientProvider).deleteBankAccount(id);
    state = AsyncData([...?state.value]..removeWhere((a) => a.id == id));
  }
}

/// Why the server refused the last delete, shown above the list. Null when there
/// is nothing to say (it is cleared by the next delete).
class BankAccountDeleteError extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) => state = message;
}

final bankAccountDeleteErrorProvider =
    NotifierProvider<BankAccountDeleteError, String?>(BankAccountDeleteError.new);

final bankAccountsProvider =
    AsyncNotifierProvider<BankAccountsController, List<BankAccount>>(
  BankAccountsController.new,
);
