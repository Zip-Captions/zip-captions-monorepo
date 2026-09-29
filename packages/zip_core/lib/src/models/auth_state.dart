import 'package:zip_core/src/models/auth_failure.dart';

/// The broadcaster authentication state machine.
///
/// Sign-in is only required for remote broadcasting (FR-1.4); every other
/// state (local captioning, transcripts, output targets) is fully decoupled
/// from this and must not read it.
sealed class AuthState {
  const AuthState();

  /// Initial state, and the state after `AuthService.signOut()` completes
  /// locally (Rule 2) — including after a passive background session loss
  /// (Rule 3, F-BA-7), never [AuthState.authFailed] for that case.
  const factory AuthState.signedOut() = SignedOutState;

  /// Between `AuthService.signIn(providerId)` being called and the flow
  /// resolving. Transient — never restored across app restarts.
  const factory AuthState.signingIn({required String providerId}) =
      SigningInState;

  /// A signed-in broadcaster, identified only by their Supabase user id — no
  /// email, display name, avatar, or tokens ever appear on this state.
  const factory AuthState.signedIn({required String userId}) = SignedInState;

  /// A `signIn(providerId)` call failed. Only ever reached as the direct
  /// result of a user-initiated sign-in attempt (Rule 3) — carries the
  /// `providerId` that was attempted, ahead of Phase 3's multi-provider UI.
  const factory AuthState.authFailed({
    required String providerId,
    required AuthFailure reason,
  }) = AuthFailedState;
}

/// {@macro auth_state.signedOut}
final class SignedOutState extends AuthState {
  /// Creates the signed-out state.
  const SignedOutState();
}

/// {@macro auth_state.signingIn}
final class SigningInState extends AuthState {
  /// Creates the signing-in state for the given [providerId].
  const SigningInState({required this.providerId});

  /// The provider id passed to `AuthService.signIn`.
  final String providerId;
}

/// {@macro auth_state.signedIn}
final class SignedInState extends AuthState {
  /// Creates the signed-in state for the given [userId].
  const SignedInState({required this.userId});

  /// The Supabase user id. No other identity data is carried.
  final String userId;
}

/// {@macro auth_state.authFailed}
final class AuthFailedState extends AuthState {
  /// Creates the auth-failed state for the given [providerId] and [reason].
  const AuthFailedState({required this.providerId, required this.reason});

  /// The provider id that was attempted when the failure occurred.
  final String providerId;

  /// Why the attempt failed.
  final AuthFailure reason;
}
