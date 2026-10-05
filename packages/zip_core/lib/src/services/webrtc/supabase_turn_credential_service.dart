import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/turn_credentials.dart';
import 'package:zip_core/src/services/webrtc/turn_credential_service.dart';

/// Postgres-RPC-backed [TurnCredentialService].
///
/// Calls `get_turn_credentials()` (Coturn Infrastructure, Unit 4) — a
/// single server-side round trip. The shared secret used to compute the
/// credential never leaves Postgres; this class only maps the function's
/// result into [TurnCredentials].
///
/// `sessionId` is accepted per the fixed interface but not yet used by the
/// server-side function — credentials aren't currently session-scoped.
class SupabaseTurnCredentialService implements TurnCredentialService {
  /// Creates a [SupabaseTurnCredentialService] backed by [client].
  const SupabaseTurnCredentialService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<TurnCredentials> fetch(String sessionId) async {
    final rows =
        await _client.rpc<List<dynamic>>('get_turn_credentials');
    final row = rows.single as Map<String, dynamic>;
    final ttlSeconds = row['ttl'] as int;
    return TurnCredentials(
      username: row['username'] as String,
      credential: row['credential'] as String,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: ttlSeconds)),
      urls: (row['urls'] as List<dynamic>).cast<String>(),
    );
  }
}
