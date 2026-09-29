import 'package:zip_core/src/models/auth_state.dart';

/// Broadcaster authentication. No tokens cross this interface — every method
/// and stream deals only in [AuthState] and opaque provider/user ids.
///
/// Lives in `zip_core` (not `zip_broadcast`) so Zip Captions can reuse it in
/// Phase 3 without changes (FR-1.1) — implementations must never depend on
/// anything broadcast-specific.
abstract interface class AuthService {
  /// Emits the current [AuthState] on subscribe, then on every change.
  Stream<AuthState> get authStateChanges;

  /// The signed-in user's id, or `null` if signed out.
  String? get currentUserId;

  /// Starts the OAuth flow for the provider identified by [providerId] (an
  /// `AuthProviderConfig` entry's `id`, never a raw SDK provider type).
  Future<void> signIn(String providerId);

  /// Clears the session and tokens, locally and server-side.
  Future<void> signOut();
}
