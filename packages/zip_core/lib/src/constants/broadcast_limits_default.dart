import 'package:zip_core/src/models/broadcast_limits.dart';

/// Spike 2.1's interim capacity limits (NFR Requirements Q1, Unit 5).
///
/// The harness never saw 100% join success even at `maxViewers=50` (best:
/// 84%); none of these three values are backed by production measurement
/// — revisit with real beta usage data (tracked Backlog item in
/// `aidlc-state.md`). A plain `const`, not `String.fromEnvironment`-style,
/// since there's no need to override this per-build, only per-code-change.
const defaultBroadcastLimits = BroadcastLimits(
  maxViewers: 50,
  presenceTimeout: Duration(seconds: 60),
  reconnectWindow: Duration(seconds: 120),
);
