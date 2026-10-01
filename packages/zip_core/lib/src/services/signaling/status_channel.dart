import 'package:zip_core/src/models/broadcast_status.dart';

/// A broadcaster's `status:{broadcast_id}` channel (SR-02 §4).
///
/// `publishLive`/`publishOffline` are broadcaster-only (enforced server-side
/// via RLS, not by this interface). `watch()` is open to any caller,
/// including anonymous viewers and resolvers — presence-expiry transitions
/// a stale live status to offline automatically (Realtime platform
/// behavior, Rule 6 of `business-rules.md`; no application-level heartbeat).
abstract interface class StatusChannel {
  /// Marks the broadcaster live for [sessionId]/[sessionName]. Broadcaster
  /// only — enforced server-side.
  Future<void> publishLive({
    required String sessionId,
    required String sessionName,
  });

  /// Marks the broadcaster offline. Broadcaster only — enforced
  /// server-side.
  Future<void> publishOffline();

  /// Live/offline updates, including the one Realtime produces
  /// automatically on presence expiry.
  Stream<BroadcastStatus> watch();

  /// Releases this channel's underlying Realtime subscription.
  Future<void> close();
}
