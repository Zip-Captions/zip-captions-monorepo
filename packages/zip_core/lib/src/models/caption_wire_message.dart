import 'package:meta/meta.dart';
import 'package:zip_core/src/models/stt_result.dart';

/// Whether captions are currently flowing, paused, or stopped — surfaced to
/// a connected viewer so it can render "captions paused" rather than
/// silence (FR-5.4). Mapping fixed at Application Design:
/// `RecordingActiveState` → [active]; `PausedState`/`ReconnectingState` →
/// [paused]; `IdleState`/`StoppedState` → [inactive].
enum CaptionActivity {
  /// Actively recognizing and sending captions.
  active,

  /// Recording paused or reconnecting — no new captions, but not ended.
  paused,

  /// Idle or stopped — no caption activity at all.
  inactive,
}

/// Versioned, `messageType`-discriminated wire messages exchanged over a
/// viewer's data channel.
///
/// Mirrors `SignalingMessage`'s exact pattern, including the wire-key
/// lesson from Unit 3.1: the discriminator key is `messageType`, never
/// `type`/`event` — those collide with envelope fields other transports
/// inject. `CaptionWireCodec.decode` is the sole boundary and returns
/// `null` instead of throwing (`business-rules.md` Rule 7).
@immutable
sealed class CaptionWireMessage {
  const CaptionWireMessage({required this.version});

  /// The wire protocol version this message was constructed under.
  final int version;

  /// The wire `messageType` discriminator for this variant.
  String get messageType;
}

/// A single caption result.
final class Caption extends CaptionWireMessage {
  /// Creates a [Caption] message from [result].
  const Caption({required this.result, super.version = 1});

  /// The underlying recognition result.
  final SttResult result;

  @override
  String get messageType => 'caption';

  @override
  bool operator ==(Object other) =>
      other is Caption && other.version == version && other.result == result;

  @override
  int get hashCode => Object.hash(version, result);
}

/// The broadcaster's caption activity changed.
final class CaptionActivityChanged extends CaptionWireMessage {
  /// Creates a [CaptionActivityChanged] message for [activity].
  const CaptionActivityChanged({required this.activity, super.version = 1});

  /// The new caption activity.
  final CaptionActivity activity;

  @override
  String get messageType => 'captionActivityChanged';

  @override
  bool operator ==(Object other) =>
      other is CaptionActivityChanged &&
      other.version == version &&
      other.activity == activity;

  @override
  int get hashCode => Object.hash(version, activity);
}

/// The broadcast ended; no further captions will arrive on this channel.
final class Ended extends CaptionWireMessage {
  /// Creates an [Ended] message.
  const Ended({super.version = 1});

  @override
  String get messageType => 'ended';

  @override
  bool operator ==(Object other) => other is Ended && other.version == version;

  @override
  int get hashCode => version.hashCode;
}
