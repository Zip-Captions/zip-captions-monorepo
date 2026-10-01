import 'package:meta/meta.dart';

/// Versioned, `type`-discriminated signaling protocol messages exchanged on
/// a `signaling:{session_id}` Realtime channel.
///
/// Every variant carries a `type` and `version` (fixed at Application
/// Design). This type has zero Supabase coupling — it is the shared wire
/// shape Unit 5 and Unit 7 also depend on. Malformed/adversarial input never
/// reaches this type directly; `SignalingCodec.decode` is the sole boundary
/// and returns `null` instead of throwing (Rule 4, `business-rules.md`).
@immutable
sealed class SignalingMessage {
  const SignalingMessage({required this.version});

  /// The wire protocol version this message was constructed under.
  final int version;

  /// The wire `type` discriminator for this variant.
  String get type;
}

/// A viewer requesting to join a broadcaster's session.
final class JoinRequest extends SignalingMessage {
  /// Creates a join request from [fromPeerId].
  ///
  /// [viewerIdentity] is reserved for Phase 3 and must stay `null` in Phase 2
  /// (FR-3.5, Rule 7) — no Phase 2 code path may set or read a non-null
  /// value here.
  const JoinRequest({
    required this.fromPeerId,
    this.viewerIdentity,
    super.version = 1,
  });

  /// The requesting viewer's ephemeral peer id.
  final String fromPeerId;

  /// Reserved for Phase 3. Always `null` in Phase 2.
  final String? viewerIdentity;

  @override
  String get type => 'joinRequest';

  @override
  bool operator ==(Object other) =>
      other is JoinRequest &&
      other.version == version &&
      other.fromPeerId == fromPeerId &&
      other.viewerIdentity == viewerIdentity;

  @override
  int get hashCode => Object.hash(version, fromPeerId, viewerIdentity);
}

/// The broadcaster accepting a join request.
final class JoinAccepted extends SignalingMessage {
  /// Creates an accepted-join message addressed to [toPeerId].
  const JoinAccepted({required this.toPeerId, super.version = 1});

  /// The viewer peer id this acceptance is addressed to.
  final String toPeerId;

  @override
  String get type => 'joinAccepted';

  @override
  bool operator ==(Object other) =>
      other is JoinAccepted &&
      other.version == version &&
      other.toPeerId == toPeerId;

  @override
  int get hashCode => Object.hash(version, toPeerId);
}

/// Why a join request was rejected.
enum JoinRejection {
  /// The session is at its viewer capacity cap.
  full,

  /// The broadcast is not currently live.
  notLive,
}

/// The broadcaster rejecting a join request.
final class JoinRejected extends SignalingMessage {
  /// Creates a rejected-join message addressed to [toPeerId].
  const JoinRejected({
    required this.toPeerId,
    required this.reason,
    super.version = 1,
  });

  /// The viewer peer id this rejection is addressed to.
  final String toPeerId;

  /// Why the join was rejected.
  final JoinRejection reason;

  @override
  String get type => 'joinRejected';

  @override
  bool operator ==(Object other) =>
      other is JoinRejected &&
      other.version == version &&
      other.toPeerId == toPeerId &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(version, toPeerId, reason);
}

/// A WebRTC SDP offer, routed peer-to-peer over the signaling channel.
final class SdpOffer extends SignalingMessage {
  /// Creates an SDP offer from [fromPeerId] to [toPeerId].
  const SdpOffer({
    required this.fromPeerId,
    required this.toPeerId,
    required this.sdp,
    super.version = 1,
  });

  /// The sender's peer id.
  final String fromPeerId;

  /// The recipient's peer id.
  final String toPeerId;

  /// The raw SDP offer body.
  final String sdp;

  @override
  String get type => 'sdpOffer';

  @override
  bool operator ==(Object other) =>
      other is SdpOffer &&
      other.version == version &&
      other.fromPeerId == fromPeerId &&
      other.toPeerId == toPeerId &&
      other.sdp == sdp;

  @override
  int get hashCode => Object.hash(version, fromPeerId, toPeerId, sdp);
}

/// A WebRTC SDP answer, routed peer-to-peer over the signaling channel.
final class SdpAnswer extends SignalingMessage {
  /// Creates an SDP answer from [fromPeerId] to [toPeerId].
  const SdpAnswer({
    required this.fromPeerId,
    required this.toPeerId,
    required this.sdp,
    super.version = 1,
  });

  /// The sender's peer id.
  final String fromPeerId;

  /// The recipient's peer id.
  final String toPeerId;

  /// The raw SDP answer body.
  final String sdp;

  @override
  String get type => 'sdpAnswer';

  @override
  bool operator ==(Object other) =>
      other is SdpAnswer &&
      other.version == version &&
      other.fromPeerId == fromPeerId &&
      other.toPeerId == toPeerId &&
      other.sdp == sdp;

  @override
  int get hashCode => Object.hash(version, fromPeerId, toPeerId, sdp);
}

/// A WebRTC ICE candidate, routed peer-to-peer over the signaling channel.
final class IceCandidate extends SignalingMessage {
  /// Creates an ICE candidate message from [fromPeerId] to [toPeerId].
  const IceCandidate({
    required this.fromPeerId,
    required this.toPeerId,
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
    super.version = 1,
  });

  /// The sender's peer id.
  final String fromPeerId;

  /// The recipient's peer id.
  final String toPeerId;

  /// The candidate's SDP line.
  final String candidate;

  /// The media stream identification tag the candidate is associated with.
  final String sdpMid;

  /// The index (zero-based) of the m-line the candidate is associated with.
  final int sdpMLineIndex;

  @override
  String get type => 'iceCandidate';

  @override
  bool operator ==(Object other) =>
      other is IceCandidate &&
      other.version == version &&
      other.fromPeerId == fromPeerId &&
      other.toPeerId == toPeerId &&
      other.candidate == candidate &&
      other.sdpMid == sdpMid &&
      other.sdpMLineIndex == sdpMLineIndex;

  @override
  int get hashCode => Object.hash(
        version,
        fromPeerId,
        toPeerId,
        candidate,
        sdpMid,
        sdpMLineIndex,
      );
}

/// A request to restart ICE negotiation for an existing peer connection
/// (FR-7.5 — re-signaling on network change).
final class IceRestart extends SignalingMessage {
  /// Creates an ICE restart message from [fromPeerId] to [toPeerId].
  const IceRestart({
    required this.fromPeerId,
    required this.toPeerId,
    super.version = 1,
  });

  /// The sender's peer id.
  final String fromPeerId;

  /// The recipient's peer id.
  final String toPeerId;

  @override
  String get type => 'iceRestart';

  @override
  bool operator ==(Object other) =>
      other is IceRestart &&
      other.version == version &&
      other.fromPeerId == fromPeerId &&
      other.toPeerId == toPeerId;

  @override
  int get hashCode => Object.hash(version, fromPeerId, toPeerId);
}

/// A peer (broadcaster or viewer) leaving the session.
final class Leave extends SignalingMessage {
  /// Creates a leave message from [fromPeerId].
  const Leave({required this.fromPeerId, super.version = 1});

  /// The leaving peer's id.
  final String fromPeerId;

  @override
  String get type => 'leave';

  @override
  bool operator ==(Object other) =>
      other is Leave &&
      other.version == version &&
      other.fromPeerId == fromPeerId;

  @override
  int get hashCode => Object.hash(version, fromPeerId);
}

/// The broadcaster ending the session for every viewer.
///
/// Only the broadcaster may ever send this — enforcing that is Unit 5's
/// transport-layer responsibility (Rule 5), not this type's.
final class BroadcastEnded extends SignalingMessage {
  /// Creates a broadcast-ended message.
  const BroadcastEnded({super.version = 1});

  @override
  String get type => 'broadcastEnded';

  @override
  bool operator ==(Object other) =>
      other is BroadcastEnded && other.version == version;

  @override
  int get hashCode => version.hashCode;
}
