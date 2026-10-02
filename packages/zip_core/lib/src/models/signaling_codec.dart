import 'dart:convert';

import 'package:zip_core/src/models/signaling_message.dart';

/// Encodes and decodes [SignalingMessage]s to/from the wire JSON shape.
///
/// `decode` is the sole boundary between raw, untrusted JSON (from any peer
/// — broadcaster or viewer) and the typed [SignalingMessage] model. It never
/// throws: malformed structure, an unknown `type`, an unsupported `version`,
/// a wrong field type, or an oversized payload all resolve to `null` (FR-3.2,
/// Rule 4 of `business-rules.md`).
abstract final class SignalingCodec {
  /// The only wire protocol version this codec currently accepts.
  static const int supportedVersion = 1;

  /// Payloads larger than this (encoded as UTF-8 JSON) are rejected without
  /// being parsed further — a cheap first line of defense against a crafted
  /// oversized payload.
  static const int maxEncodedBytes = 16 * 1024;

  /// Encodes [message] to its wire JSON shape.
  static Map<String, Object?> encode(SignalingMessage message) {
    final base = <String, Object?>{
      'type': message.type,
      'version': message.version,
    };
    return switch (message) {
      JoinRequest(:final fromPeerId, :final viewerIdentity) => {
          ...base,
          'fromPeerId': fromPeerId,
          'viewerIdentity': viewerIdentity,
        },
      JoinAccepted(:final toPeerId) => {...base, 'toPeerId': toPeerId},
      JoinRejected(:final toPeerId, :final reason) => {
          ...base,
          'toPeerId': toPeerId,
          'reason': reason.name,
        },
      SdpOffer(:final fromPeerId, :final toPeerId, :final sdp) => {
          ...base,
          'fromPeerId': fromPeerId,
          'toPeerId': toPeerId,
          'sdp': sdp,
        },
      SdpAnswer(:final fromPeerId, :final toPeerId, :final sdp) => {
          ...base,
          'fromPeerId': fromPeerId,
          'toPeerId': toPeerId,
          'sdp': sdp,
        },
      IceCandidate(
        :final fromPeerId,
        :final toPeerId,
        :final candidate,
        :final sdpMid,
        :final sdpMLineIndex,
      ) =>
        {
          ...base,
          'fromPeerId': fromPeerId,
          'toPeerId': toPeerId,
          'candidate': candidate,
          'sdpMid': sdpMid,
          'sdpMLineIndex': sdpMLineIndex,
        },
      IceRestart(:final fromPeerId, :final toPeerId) => {
          ...base,
          'fromPeerId': fromPeerId,
          'toPeerId': toPeerId,
        },
      Leave(:final fromPeerId) => {...base, 'fromPeerId': fromPeerId},
      BroadcastEnded() => base,
    };
  }

  /// Decodes [json] to a [SignalingMessage], or `null` if it is malformed,
  /// unrecognized, unsupported, or oversized. Never throws.
  static SignalingMessage? decode(Object? json) {
    try {
      return _decode(json);
    } on Object {
      return null;
    }
  }

  static SignalingMessage? _decode(Object? json) {
    if (json is! Map) return null;
    if (_encodedByteLength(json) > maxEncodedBytes) return null;

    final type = json['type'];
    final version = json['version'];
    if (type is! String || version is! int) return null;
    if (version != supportedVersion) return null;

    switch (type) {
      case 'joinRequest':
        final fromPeerId = json['fromPeerId'];
        final viewerIdentity = json['viewerIdentity'];
        if (fromPeerId is! String) return null;
        if (viewerIdentity != null && viewerIdentity is! String) return null;
        return JoinRequest(
          fromPeerId: fromPeerId,
          viewerIdentity: viewerIdentity as String?,
          version: version,
        );
      case 'joinAccepted':
        final toPeerId = json['toPeerId'];
        if (toPeerId is! String) return null;
        return JoinAccepted(toPeerId: toPeerId, version: version);
      case 'joinRejected':
        final toPeerId = json['toPeerId'];
        final reasonName = json['reason'];
        if (toPeerId is! String || reasonName is! String) return null;
        JoinRejection? reason;
        for (final candidate in JoinRejection.values) {
          if (candidate.name == reasonName) {
            reason = candidate;
            break;
          }
        }
        if (reason == null) return null;
        return JoinRejected(
          toPeerId: toPeerId,
          reason: reason,
          version: version,
        );
      case 'sdpOffer':
        final fromPeerId = json['fromPeerId'];
        final toPeerId = json['toPeerId'];
        final sdp = json['sdp'];
        if (fromPeerId is! String || toPeerId is! String || sdp is! String) {
          return null;
        }
        return SdpOffer(
          fromPeerId: fromPeerId,
          toPeerId: toPeerId,
          sdp: sdp,
          version: version,
        );
      case 'sdpAnswer':
        final fromPeerId = json['fromPeerId'];
        final toPeerId = json['toPeerId'];
        final sdp = json['sdp'];
        if (fromPeerId is! String || toPeerId is! String || sdp is! String) {
          return null;
        }
        return SdpAnswer(
          fromPeerId: fromPeerId,
          toPeerId: toPeerId,
          sdp: sdp,
          version: version,
        );
      case 'iceCandidate':
        final fromPeerId = json['fromPeerId'];
        final toPeerId = json['toPeerId'];
        final candidate = json['candidate'];
        final sdpMid = json['sdpMid'];
        final sdpMLineIndex = json['sdpMLineIndex'];
        if (fromPeerId is! String ||
            toPeerId is! String ||
            candidate is! String ||
            sdpMid is! String ||
            sdpMLineIndex is! int) {
          return null;
        }
        return IceCandidate(
          fromPeerId: fromPeerId,
          toPeerId: toPeerId,
          candidate: candidate,
          sdpMid: sdpMid,
          sdpMLineIndex: sdpMLineIndex,
          version: version,
        );
      case 'iceRestart':
        final fromPeerId = json['fromPeerId'];
        final toPeerId = json['toPeerId'];
        if (fromPeerId is! String || toPeerId is! String) return null;
        return IceRestart(
          fromPeerId: fromPeerId,
          toPeerId: toPeerId,
          version: version,
        );
      case 'leave':
        final fromPeerId = json['fromPeerId'];
        if (fromPeerId is! String) return null;
        return Leave(fromPeerId: fromPeerId, version: version);
      case 'broadcastEnded':
        return BroadcastEnded(version: version);
      default:
        return null;
    }
  }

  /// The actual UTF-8 byte length of the complete encoded payload,
  /// including nested maps/lists and multibyte characters.
  ///
  /// **Corrected (PR #24 review, 2026-10-02)**: the original version only
  /// summed top-level string values' `.length` (UTF-16 code units, not
  /// bytes) and ignored nested structures entirely — a message with a large
  /// nested field (e.g. an unrecognized `extra` key some decoder branch
  /// ignores) could pass this check while its real encoded size was many
  /// times over the limit, violating the oversized-input contract (Rule 4).
  /// `jsonEncode`'s cost here is acceptable: it only runs after the
  /// top-level shape has already passed the earlier cheap `is! Map` check,
  /// and oversized/malformed input is exactly the adversarial case worth
  /// spending real work to reject correctly.
  static int _encodedByteLength(Map<Object?, Object?> json) =>
      utf8.encode(jsonEncode(json)).length;
}
