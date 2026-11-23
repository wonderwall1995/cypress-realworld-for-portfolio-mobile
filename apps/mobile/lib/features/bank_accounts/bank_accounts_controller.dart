import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
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
    return readAnswer(
      () => raw
          .where((json) => json['isDeleted'] != true && json['visible'] != false)
          .map(BankAccount.fromJson)
          .toList(),
    );
  }

  /// Loads again without going through the loading state (the screen stays).
  /// Returns false when it failed; the old list stays then, so a failure is never
  /// shown as "no accounts".
  Future<bool> reload() async {
    final api = ref.read(apiClientProvider);
    final session = api.sessionNumber;
    try {
      final list = await _fetch();
      if (!ref.mounted || session != api.sessionNumber) return false;
      state = AsyncData(list);
      return true;
    } on ApiException catch (e, stack) {
      if (!ref.mounted || session != api.sessionNumber) return false;
      if (!state.hasValue) state = AsyncError(e, stack);
      return false;
    }
  }

  /// Throws [ApiException] when the server refuses.
  Future<void> create({
    required String bankName,
    required String accountNumber,
  }) async {
    final Map<String, dynamic> json;
    try {
      json = await ref.read(apiClientProvider).createBankAccount(
            bankName: bankName,
            accountNumber: accountNumber,
          );
    } on ApiException {
      // It may have been done (no answer), or the list here is old (refused).
      unawaited(reload());
      rethrow;
    }
    final account = readAnswer(() => BankAccount.fromJson(json));
    state = AsyncData([...?state.value, account]);
  }

  /// Throws [ApiException] when the server refuses.
  Future<void> remove(String id) async {
    try {
      await ref.read(apiClientProvider).deleteBankAccount(id);
    } on ApiException {
      unawaited(reload());
      rethrow;
    }
    state = AsyncData([...?state.value]..removeWhere((a) => a.id == id));
  }
}

/// Why the server refused the last delete, shown above the list. Null when there
/// is nothing to say (it is cleared by the next delete).
class BankAccountDeleteError extends Notifier<String?> {
  @override
  String? build() {
    // Another user starts without it.
    ref.watch(sessionProvider.select((s) => s.user?['id']));
    return null;
  }

  void set(String? message) => state = message;
}

final bankAccountDeleteErrorProvider =
    NotifierProvider<BankAccountDeleteError, String?>(BankAccountDeleteError.new);

final bankAccountsProvider =
    AsyncNotifierProvider<BankAccountsController, List<BankAccount>>(
  BankAccountsController.new,
);
