import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// Which part of the app the user may see.
///
/// The router listens to this one value, so it only moves when this changes
/// (not every time a bank account is added or deleted).
enum AppGate {
  /// Asking the server who is signed in. Show the splash screen.
  checking,

  /// The server could not be asked who is signed in. Offer to ask again.
  offline,

  /// Not signed in. Show sign-in and sign-up.
  signedOut,

  /// Signed in. Show the tabs. (A bank account is not needed for that.)
  ready,
}

final appGateProvider = Provider<AppGate>((ref) {
  final status = ref.watch(sessionProvider.select((s) => s.status));
  switch (status) {
    case SessionStatus.unknown:
      return AppGate.checking;
    case SessionStatus.offline:
      return AppGate.offline;
    case SessionStatus.unauthenticated:
      return AppGate.signedOut;
    case SessionStatus.authenticated:
      return AppGate.ready;
  }
});
