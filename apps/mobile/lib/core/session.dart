import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'providers.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionState {
  const SessionState({
    required this.status,
    this.user,
    this.connectionError = false,
  });

  const SessionState.unknown() : this(status: SessionStatus.unknown);

  final SessionStatus status;
  final Map<String, dynamic>? user;

  /// True when the last check could not reach the server.
  final bool connectionError;
}

/// Holds who is signed in. Starts by asking the server about the saved cookie.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionState.unknown();
  }

  Future<void> restore() async {
    try {
      final user = await ref.read(apiClientProvider).checkAuth();
      state = user == null
          ? const SessionState(status: SessionStatus.unauthenticated)
          : SessionState(status: SessionStatus.authenticated, user: user);
    } on ApiException catch (e) {
      state = SessionState(
        status: SessionStatus.unauthenticated,
        connectionError: e.isConnection,
      );
    }
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
