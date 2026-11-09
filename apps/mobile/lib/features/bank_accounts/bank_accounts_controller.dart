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

  /// The server keeps deleted accounts (soft delete) and returns them with
  /// `isDeleted: true`. The app only works with accounts in use.
  Future<List<BankAccount>> _fetch() async {
    final raw = await ref.read(apiClientProvider).getBankAccounts();
    return raw
        .where((json) => json['isDeleted'] != true)
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
    required String routingNumber,
    required String accountNumber,
  }) async {
    final json = await ref.read(apiClientProvider).createBankAccount(
          bankName: bankName,
          routingNumber: routingNumber,
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

final bankAccountsProvider =
    AsyncNotifierProvider<BankAccountsController, List<BankAccount>>(
  BankAccountsController.new,
);
