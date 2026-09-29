import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session storage backed by the OS keychain/credential store
/// ([FlutterSecureStorage]), used in place of `supabase_flutter`'s default
/// plaintext `shared_preferences` storage on desktop.
///
/// A session token is a bearer credential, not a UI preference: unlike
/// mobile (where the OS already sandboxes each app's storage per-app),
/// desktop `shared_preferences` is an ordinary user-readable file with no
/// equivalent sandboxing. See `sr-01-oauth-approach.md` Section 4.
///
/// Used only on macOS/Windows/Linux (`!kIsWeb`) — never the default on
/// desktop under any code path (`business-rules.md` Rule 6).
class SecureDesktopLocalStorage extends LocalStorage {
  /// Creates a [SecureDesktopLocalStorage], optionally with a specific
  /// [FlutterSecureStorage] instance (for testing).
  const SecureDesktopLocalStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'zip_broadcast.supabase.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}
