// Stream-driven fake AuthService for AuthNotifier tests and the stateful
// PBT (PBT-06) — a mocktail mock can't hold and emit state across a
// sequence of commands the way this fake can (NFR-7.3, testable-properties.md).

import 'dart:async';

import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/services/auth/auth_service.dart';

/// A programmatically-driven [AuthService] fake.
///
/// Tests push outcomes onto [authStateChanges] via [emit]; [signIn] and
/// [signOut] just record their calls (via [signInCalls]/[signOutCallCount])
/// unless a [onSignIn]/[onSignOut] callback is supplied to drive further
/// behavior (e.g. emitting a resulting state).
class FakeAuthService implements AuthService {
  /// Creates a [FakeAuthService], optionally starting from [initialState].
  FakeAuthService({AuthState initialState = const AuthState.signedOut()})
      : _current = initialState;

  AuthState _current;
  final _controller = StreamController<AuthState>.broadcast();

  /// Every `providerId` passed to [signIn], in call order.
  final List<String> signInCalls = [];

  /// How many times [signOut] was called.
  int signOutCallCount = 0;

  /// Optional hook invoked from [signIn] before returning.
  Future<void> Function(String providerId)? onSignIn;

  /// Optional hook invoked from [signOut] before returning.
  Future<void> Function()? onSignOut;

  @override
  Stream<AuthState> get authStateChanges => Stream<AuthState>.multi((
    controller,
  ) {
    controller.add(_current);
    final sub = _controller.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });

  @override
  String? get currentUserId =>
      _current is SignedInState ? (_current as SignedInState).userId : null;

  @override
  Future<void> signIn(String providerId) async {
    signInCalls.add(providerId);
    await onSignIn?.call(providerId);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    await onSignOut?.call();
  }

  /// Pushes [state] onto [authStateChanges], as if the real SDK had
  /// produced it.
  void emit(AuthState state) {
    _current = state;
    _controller.add(state);
  }

  /// Releases the underlying stream controller.
  void dispose() {
    unawaited(_controller.close());
  }
}
