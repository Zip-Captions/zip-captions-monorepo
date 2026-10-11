import 'package:zip_core/src/models/broadcast_limits.dart';

/// Tracks capacity admission for one broadcast against its
/// [BroadcastLimits] (fixed shape, Application Design).
///
/// Reconnection-aware (`business-rules.md` Rule 6): a released slot is
/// reserved for [BroadcastLimits.reconnectWindow] before it's handed to a
/// new viewer, so a viewer reconnecting within that window reclaims its
/// own slot rather than losing it to someone else.
///
/// The constructor's `now` parameter overrides the wall-clock source;
/// defaults to [DateTime.now]
/// (matching `transcript_writer_target.dart`'s identical existing idiom —
/// NFR Design Q1, corrected 2026-10-08). Expiry is checked lazily, at the
/// start of every [tryAdmit]/[release]/[count] call, never by a background
/// `Timer` — this class owns no timer lifecycle at all.
class ViewerAdmission {
  /// Creates a [ViewerAdmission] for [limits].
  ViewerAdmission(this.limits, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// This broadcast's capacity limits.
  final BroadcastLimits limits;

  final DateTime Function() _now;
  final Map<String, DateTime?> _reservedUntil = {};

  /// Atomic check-and-reserve; [count] never exceeds
  /// [BroadcastLimits.maxViewers] under any interleaving of [tryAdmit]/
  /// [release] calls.
  AdmissionDecision tryAdmit(String peerId) {
    _sweepExpired();
    if (_reservedUntil.containsKey(peerId)) {
      // Reclaim path: the same peerId reconnecting within its window.
      // No net change to count.
      _reservedUntil[peerId] = null;
      return const Admitted();
    }
    if (_reservedUntil.length >= limits.maxViewers) {
      return const Full();
    }
    _reservedUntil[peerId] = null;
    return const Admitted();
  }

  /// Releases [peerId]'s slot, starting its [BroadcastLimits.reconnectWindow]
  /// grace period rather than freeing the slot immediately.
  void release(String peerId) {
    _sweepExpired();
    if (!_reservedUntil.containsKey(peerId)) return;
    _reservedUntil[peerId] = _now().add(limits.reconnectWindow);
  }

  /// The number of currently-tracked peers (active + reserved-for-reclaim),
  /// after sweeping any expired reservations.
  int get count {
    _sweepExpired();
    return _reservedUntil.length;
  }

  void _sweepExpired() {
    final now = _now();
    _reservedUntil.removeWhere(
      (_, reservedUntil) =>
          reservedUntil != null && !now.isBefore(reservedUntil),
    );
  }
}
