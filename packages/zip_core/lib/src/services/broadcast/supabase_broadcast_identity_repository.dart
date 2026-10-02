import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/broadcast/broadcast_identity_repository.dart';

/// Postgres-RPC-backed [BroadcastIdentityRepository].
///
/// Calls `get_or_create_my_broadcast_id()` (SR-02 §3) — a single
/// server-side round trip. All collision-retry logic (both a `broadcast_id`
/// candidate collision and a same-`owner_id` concurrent-call race,
/// business-rules.md Rule 1) is implemented inside that Postgres function,
/// not here: this class never retries client-side, it only maps the
/// function's outcome.
class SupabaseBroadcastIdentityRepository
    implements BroadcastIdentityRepository {
  /// Creates a [SupabaseBroadcastIdentityRepository] backed by [client].
  const SupabaseBroadcastIdentityRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  /// Postgres error code for a row-level-security policy rejection
  /// (`new row violates row-level security policy` / insufficient
  /// privilege).
  static const String _insufficientPrivilegeCode = '42501';

  @override
  Future<BroadcastId> getOrCreateMine() async {
    try {
      final result =
          await _client.rpc<String>('get_or_create_my_broadcast_id');
      return BroadcastId.parse(result);
    } on PostgrestException catch (error) {
      if (error.code == _insufficientPrivilegeCode) {
        throw BroadcastAuthorizationException(error.message);
      }
      rethrow;
    }
  }
}
