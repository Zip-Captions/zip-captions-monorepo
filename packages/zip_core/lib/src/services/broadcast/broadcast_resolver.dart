import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_resolution.dart';

/// Resolves a [BroadcastId] to a live/offline status (SR-02 §2).
// ignore: one_member_abstracts
abstract interface class BroadcastResolver {
  /// Resolves [id]. Never throws — every failure mode (not found, rate
  /// limited, a step-2 presence-read failure) is a [BroadcastResolution]
  /// variant, not an exception.
  Future<BroadcastResolution> resolve(BroadcastId id);
}
