import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'providers.dart';

enum SessionStatus {
  unknown,
  authenticated,
  unauthenticated,

  /// The server could not be asked, so nobody knows. The cookie is kept.
  offline,
}

class SessionState {
  const SessionState({
    required this.status,
    this.user,
    this.expired = false,
  });

  const SessionState.unknown() : this(status: SessionStatus.unknown);

  final SessionStatus status;
  final Map<String, dynamic>? user;

  /// True when the sign-in ended by itself (not by the sign-out button).
  final bool expired;
}

/// Holds who is signed in. Starts by asking the server about the saved cookie.
class SessionController extends Notifier<SessionState> {
  /// Goes up whenever the user changes, so a late answer for the old one is dropped.
  int _number = 0;

  void _next() => ref.read(apiClientProvider).sessionNumber = ++_number;

  @override
  SessionState build() {
    ref.read(apiClientProvider).onSessionExpired = expire;
    Future.microtask(restore);
    return const SessionState.unknown();
  }

  /// Asks the server who the saved cookie belongs to. When it cannot be asked the
  /// user is not signed out: the app says so and offers to ask again.
  Future<void> restore() async {
    final number = _number;
    state = const SessionState.unknown();
    try {
      final user = await ref.read(apiClientProvider).checkAuth();
      if (number != _number) return;
      state = user == null
          ? const SessionState(status: SessionStatus.unauthenticated)
          : SessionState(status: SessionStatus.authenticated, user: user);
    } on ApiException {
      if (number != _number) return;
      state = const SessionState(status: SessionStatus.offline);
    }
  }

  /// Asks the server for the signed-in user again, for example to get the new
  /// balance after a payment. Keeps the old data and returns false if the call
  /// fails. When the server says nobody is signed in, the sign-in is over.
  Future<bool> refreshUser() async {
    if (state.status != SessionStatus.authenticated) return false;
    final number = _number;
    try {
      final user = await ref.read(apiClientProvider).checkAuth();
      if (number != _number) return false;
      if (user == null) {
        expire();
        return false;
      }
      state = SessionState(status: SessionStatus.authenticated, user: user);
      return true;
    } on ApiException {
      return false;
    }
  }

  /// The server says the sign-in is over. The user signs in again; nothing that
  /// was being sent is sent again.
  void expire() {
    if (state.status != SessionStatus.authenticated) return;
    _next();
    state = const SessionState(status: SessionStatus.unauthenticated, expired: true);
    unawaited(ref.read(apiClientProvider).cookieJar.deleteAll());
  }

  /// Throws [ApiException] when the sign-in fails.
  Future<void> signIn({
    required String username,
    required String password,
    required bool remember,
  }) async {
    final number = _number;
    final user = await ref.read(apiClientProvider).login(
          username: username,
          password: password,
          remember: remember,
        );
    if (number != _number) return;
    _next();
    state = SessionState(status: SessionStatus.authenticated, user: user);
  }

  /// Always ends signed out on this device, even if the server call fails.
  Future<void> signOut() async {
    _next();
    try {
      await ref.read(apiClientProvider).logout();
    } on ApiException {
      // The local cookie is already removed by the client.
    }
    state = const SessionState(status: SessionStatus.unauthenticated);
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
