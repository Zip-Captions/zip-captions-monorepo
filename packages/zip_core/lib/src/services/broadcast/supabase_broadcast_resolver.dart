import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_resolution.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/services/broadcast/broadcast_resolver.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';

/// Two-step [BroadcastResolver] (SR-02 §2): a `resolve_broadcast_id` RPC
/// existence check, then a `status:{broadcast_id}` presence read.
///
/// A step-2 failure (the presence read itself errors or times out) resolves
/// to [BroadcastResolution.resolutionFailed], kept distinct from
/// [BroadcastResolution.offline] (NFR Design's design correction) — a
/// transient Realtime glitch must never be reported as the broadcast having
/// ended. A step-1 failure that isn't recognizable as a Kong rate-limit
/// rejection is treated the same way: "we couldn't check" is not "the code
/// doesn't exist."
class SupabaseBroadcastResolver implements BroadcastResolver {
  /// Creates a [SupabaseBroadcastResolver] backed by [client] (for the RPC
  /// call) and [signalingService] (for the presence read).
  const SupabaseBroadcastResolver({
    required SupabaseClient client,
    required SignalingService signalingService,
  })  : _client = client,
        _signalingService = signalingService;

  final SupabaseClient _client;
  final SignalingService _signalingService;

  /// Step-2's presence read is given this long to produce a value before
  /// resolving to [BroadcastResolution.resolutionFailed]. Not derived from
  /// a pinned NFR (NFR Requirements fixed no formal latency target for
  /// resolution) — a pragmatic default so a hung channel subscription can
  /// never hang `resolve()` forever. Revisit against real-world Realtime
  /// join latency once this is exercised in Build and Test / Infrastructure
  /// monitoring.
  static const Duration presenceReadTimeout = Duration(seconds: 5);

  @override
  Future<BroadcastResolution> resolve(BroadcastId id) async {
    final bool exists;
    try {
      exists = await _client.rpc<bool>(
        'resolve_broadcast_id',
        params: {'p_broadcast_id': id.value},
      );
    } on PostgrestException catch (error) {
      return _looksRateLimited(error)
          ? const BroadcastResolution.rateLimited()
          : const BroadcastResolution.resolutionFailed();
    } on Object {
      return const BroadcastResolution.resolutionFailed();
    }

    if (!exists) return const BroadcastResolution.notFound();

    final channel = _signalingService.statusChannel(id);
    try {
      final status =
          await channel.watch().first.timeout(presenceReadTimeout);
      return switch (status) {
        BroadcastStatusLive(:final sessionId, :final sessionName) =>
          BroadcastResolution.live(
            sessionId: sessionId,
            sessionName: sessionName,
          ),
        BroadcastStatusOffline() => const BroadcastResolution.offline(),
      };
    } on Object {
      return const BroadcastResolution.resolutionFailed();
    } finally {
      await channel.close();
    }
  }

  /// Best-effort detection of a Kong rate-limit rejection: Kong's
  /// `rate-limiting` plugin returns a plain HTTP 429 outside PostgREST's
  /// own error-response shape, which `postgrest-dart` surfaces as a
  /// [PostgrestException] with no Postgres `code` (unlike a genuine
  /// database error, which always has one). **Not yet verified against the
  /// real Kong + local Supabase stack** — Step 12's integration tests
  /// against the actual rate-limited route must confirm this heuristic
  /// before Unit 3 ships; if it's wrong, HTTP 429 would currently resolve
  /// to [BroadcastResolution.resolutionFailed] instead of
  /// [BroadcastResolution.rateLimited], which is a safe (if less precise)
  /// fallback either way.
  static bool _looksRateLimited(PostgrestException error) =>
      error.code == null &&
      error.message.toLowerCase().contains('rate limit');
}
