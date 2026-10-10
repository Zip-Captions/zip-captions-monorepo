import 'package:freezed_annotation/freezed_annotation.dart';

part 'broadcast_limits.freezed.dart';

/// Capacity/liveness limits for one broadcast (fixed shape, Application
/// Design). Interim values (`maxViewers=50`, `presenceTimeout=60s`,
/// `reconnectWindow=120s`) are Spike 2.1's own recommendation, shipped as
/// `defaultBroadcastLimits` — revisable as a one-file edit once real beta
/// data exists.
@freezed
abstract class BroadcastLimits with _$BroadcastLimits {
  /// Creates a [BroadcastLimits].
  const factory BroadcastLimits({
    /// Maximum concurrent viewers.
    required int maxViewers,

    /// Not currently consumed by `ViewerAdmission` — reserved for a future
    /// presence-adjacent liveness check.
    required Duration presenceTimeout,

    /// How long a disconnected viewer's slot is reserved for reclaim before
    /// being released to a new viewer (`business-rules.md` Rule 6).
    required Duration reconnectWindow,
  }) = _BroadcastLimits;
}

/// The outcome of `ViewerAdmission.tryAdmit` (fixed shape, Application
/// Design).
@immutable
sealed class AdmissionDecision {
  const AdmissionDecision();
}

/// The viewer was admitted (as a new slot or a reconnect reclaim).
final class Admitted extends AdmissionDecision {
  /// Creates an [Admitted] decision.
  const Admitted();

  @override
  bool operator ==(Object other) => other is Admitted;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The broadcast is at `maxViewers` capacity.
final class Full extends AdmissionDecision {
  /// Creates a [Full] decision.
  const Full();

  @override
  bool operator ==(Object other) => other is Full;

  @override
  int get hashCode => runtimeType.hashCode;
}
