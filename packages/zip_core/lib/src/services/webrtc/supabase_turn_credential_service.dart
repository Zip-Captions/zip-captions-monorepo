import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/turn_credentials.dart';
import 'package:zip_core/src/services/webrtc/turn_credential_service.dart';

/// Postgres-RPC-backed [TurnCredentialService].
///
/// Two server-side entry points, both a single round trip, and in both cases
/// the shared secret used to compute the credential never leaves Postgres;
/// this class only maps each function's result into [TurnCredentials].
///
/// - [fetch] calls `get_turn_credentials()` (Coturn Infrastructure, Unit 4)
///   for an authenticated caller, such as the broadcaster.
/// - [fetchBroadcast] calls `get_broadcast_turn_credentials()` (Unit 9, B2)
///   for an anonymous viewer, which has no account to authenticate as.
class SupabaseTurnCredentialService implements TurnCredentialService {
  /// Creates a [SupabaseTurnCredentialService] backed by [client].
  const SupabaseTurnCredentialService({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<TurnCredentials> fetch(String sessionId) =>
      _fetchFrom('get_turn_credentials');

  @override
  Future<TurnCredentials> fetchBroadcast(String broadcastId) => _fetchFrom(
    'get_broadcast_turn_credentials',
    params: {'p_broadcast_id': broadcastId},
  );

  /// Both RPCs return the same single-row shape
  /// (`username, credential, ttl, urls`), so the mapping is shared rather
  /// than duplicated — anything that diverges between the two paths belongs
  /// server-side, not here.
  Future<TurnCredentials> _fetchFrom(
    String function, {
    Map<String, dynamic>? params,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(function, params: params);
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
