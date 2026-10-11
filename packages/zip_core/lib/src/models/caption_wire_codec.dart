import 'dart:convert';

import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/stt_result.dart';

/// Encodes and decodes [CaptionWireMessage]s to/from the wire JSON shape.
///
/// `decode` is the sole boundary between raw, untrusted JSON (from the
/// broadcaster's own data channel) and the typed [CaptionWireMessage]
/// model. It never throws: malformed structure, an unknown `messageType`,
/// an unsupported `version`, a wrong field type, or an oversized payload
/// all resolve to `null` (`business-rules.md` Rule 7).
///
/// **The wire key is `messageType`, not `type`/`event`** — applying Unit
/// 3.1's `SignalingCodec` lesson from the start rather than discovering the
/// same bug twice: a discriminator key must never collide with a key an
/// envelope (Realtime's broadcast envelope, or any future transport) might
/// inject alongside the payload.
abstract final class CaptionWireCodec {
  /// The only wire protocol version this codec currently accepts.
  static const int supportedVersion = 1;

  /// Payloads larger than this (encoded as UTF-8 JSON) are rejected without
  /// being parsed further.
  static const int maxEncodedBytes = 16 * 1024;

  /// Encodes [message] to its wire JSON shape.
  static Map<String, Object?> encode(CaptionWireMessage message) {
    final base = <String, Object?>{
      'messageType': message.messageType,
      'version': message.version,
    };
    return switch (message) {
      Caption(:final result) => {
          ...base,
          'text': result.text,
          'isFinal': result.isFinal,
          'confidence': result.confidence,
          'timestamp': result.timestamp.toIso8601String(),
          'sourceId': result.sourceId,
          'speakerTag': result.speakerTag,
        },
      CaptionActivityChanged(:final activity) => {
          ...base,
          'activity': activity.name,
        },
      Ended() => base,
    };
  }

  /// Decodes [json] to a [CaptionWireMessage], or `null` if it is
  /// malformed, unrecognized, unsupported, or oversized. Never throws.
  static CaptionWireMessage? decode(Object? json) {
    try {
      return _decode(json);
    } on Object {
      return null;
    }
  }

  static CaptionWireMessage? _decode(Object? json) {
    if (json is! Map) return null;
    if (_encodedByteLength(json) > maxEncodedBytes) return null;

    final messageType = json['messageType'];
    final version = json['version'];
    if (messageType is! String || version is! int) return null;
    if (version != supportedVersion) return null;

    switch (messageType) {
      case 'caption':
        final text = json['text'];
        final isFinal = json['isFinal'];
        final confidence = json['confidence'];
        final timestampRaw = json['timestamp'];
        final sourceId = json['sourceId'];
        final speakerTag = json['speakerTag'];
        if (text is! String ||
            isFinal is! bool ||
            confidence is! num ||
            timestampRaw is! String ||
            sourceId is! String) {
          return null;
        }
        if (speakerTag != null && speakerTag is! String) return null;
        final timestamp = DateTime.tryParse(timestampRaw);
        if (timestamp == null) return null;
        return Caption(
          result: SttResult(
            text: text,
            isFinal: isFinal,
            confidence: confidence.toDouble(),
            timestamp: timestamp,
            sourceId: sourceId,
            speakerTag: speakerTag as String?,
          ),
          version: version,
        );
      case 'captionActivityChanged':
        final activityName = json['activity'];
        if (activityName is! String) return null;
        CaptionActivity? activity;
        for (final candidate in CaptionActivity.values) {
          if (candidate.name == activityName) {
            activity = candidate;
            break;
          }
        }
        if (activity == null) return null;
        return CaptionActivityChanged(activity: activity, version: version);
      case 'ended':
        return Ended(version: version);
      default:
        return null;
    }
  }

  /// The actual UTF-8 byte length of the complete encoded payload,
  /// including nested maps/lists and multibyte characters — matches
  /// `SignalingCodec`'s own corrected implementation (PR #24 review).
  static int _encodedByteLength(Map<Object?, Object?> json) =>
      utf8.encode(jsonEncode(json)).length;
}
