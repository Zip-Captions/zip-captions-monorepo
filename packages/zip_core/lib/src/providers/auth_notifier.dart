import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/providers/auth_service_provider.dart';
import 'package:zip_core/src/services/auth/auth_service.dart';

part 'auth_notifier.g.dart';

/// Broadcaster authentication orchestration (S-15).
///
/// Calls [AuthService] explicitly (this project's Riverpod convention is
/// explicit calls from notifiers, not reactive watchers) and republishes its
/// [AuthState] stream. Session restore (F-BA-2) reads [AuthService] state
/// synchronously in [build] — no network round trip blocks app start.
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  late AuthService _authService;
  StreamSubscription<AuthState>? _authSub;

  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);
    ref.onDispose(() => unawaited(_authSub?.cancel()));
    _authSub = _authService.authStateChanges.listen((authState) {
      state = authState;
    });
    final userId = _authService.currentUserId;
    return userId != null
        ? AuthState.signedIn(userId: userId)
        : const AuthState.signedOut();
  }

  /// Starts the OAuth flow for [providerId]. A no-op if an attempt is
  /// already in flight (Rule 1 — single in-flight sign-in).
  Future<void> signIn(String providerId) async {
    if (state is SigningInState) return;
    await _authService.signIn(providerId);
  }

  /// Signs out. Idempotent (Rule 8) — a no-op if already signed out.
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
