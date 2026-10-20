import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/zip_core.dart';

/// The launch payload handed to the secondary window.
///
/// `config.mode` is the **only** mode source; the superseded design carried a
/// second copy of the field directly on the launch (B-7).
@immutable
class OverlayWindowLaunch {
  /// Creates an [OverlayWindowLaunch].
  const OverlayWindowLaunch({required this.config, required this.snapshot});

  /// The window configuration: mode and caption position.
  final OverlayConfig config;

  /// The first frame the window renders.
  final CaptionOverlaySnapshot snapshot;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayWindowLaunch &&
          other.config == config &&
          other.snapshot == snapshot;

  @override
  int get hashCode => Object.hash(config, snapshot);
}

/// Hand-written, versioned codecs for the window boundary (D-8, B-7).
///
/// `zip_core` models are not serialised by generated JSON, so this follows the
/// `CaptionWireCodec` precedent instead: a `v` version field, enums encoded by
/// name, and a decode that is **total on error** — malformed structure, an
/// unknown version, an unknown enum value or an oversized payload all return
/// `null` and never throw (BR-U8-24).
///
/// **Forward notes (not implemented here).** The per-entry `key` **is**
/// `CaptionDisplayEntry.entryId`, the segment id Phase 8 keys translations by,
/// and `v` is the field a bilingual codec bumps. Unit 8 adds no translation
/// fields (YAGNI).
abstract final class CaptionOverlayCodec {
  /// The only wire version this codec accepts.
  static const int supportedVersion = 1;

  /// Payloads larger than this (encoded as UTF-8 JSON) are rejected without
  /// being parsed further. Applied to the full payload, nested fields and
  /// multibyte characters included.
  static const int maxEncodedBytes = 16 * 1024;

  static const String _modeExternalDisplay = 'externalDisplay';

  /// Placeholder session id for entries rebuilt in the window.
  ///
  /// `sessionId` never crosses the boundary; the window has no use for it and
  /// the widget only reads `sourceId` and `text`.
  static const String _placeholderSessionId = '';

  /// Placeholder source id for entries rebuilt in the window. Never
  /// [pauseSourceId]: which entries are pause markers is carried by
  /// `activity`, not by a per-entry field (B-7).
  static const String _placeholderSourceId = 'external_display';

  /// Encodes [snapshot] to its wire shape.
  static String encodeSnapshot(CaptionOverlaySnapshot snapshot) => jsonEncode({
        'v': supportedVersion,
        'activity': snapshot.activity.name,
        'entries': snapshot.entries.map(_encodeEntry).toList(),
        'interim': snapshot.interim == null
            ? null
            : _encodeEntry(snapshot.interim!),
        'settings': _encodeSettings(snapshot.settings),
      });

  /// Decodes [payload] to a [CaptionOverlaySnapshot], or `null` if it is
  /// malformed, unrecognised or oversized. Never throws.
  static CaptionOverlaySnapshot? decodeSnapshot(String payload) {
    try {
      if (!_withinSizeGuard(payload)) return null;
      final json = jsonDecode(payload);
      if (json is! Map) return null;
      return _decodeSnapshot(json);
    } on Object {
      return null;
    }
  }

  /// Encodes [launch] to its wire shape.
  static String encodeLaunch(OverlayWindowLaunch launch) => jsonEncode({
        'v': supportedVersion,
        'config': _encodeConfig(launch.config),
        'snapshot': jsonDecode(encodeSnapshot(launch.snapshot)),
      });

  /// Decodes [payload] to an [OverlayWindowLaunch], or `null` if it is
  /// malformed, unrecognised or oversized. Never throws.
  static OverlayWindowLaunch? decodeLaunch(String payload) {
    try {
      if (!_withinSizeGuard(payload)) return null;
      final json = jsonDecode(payload);
      if (json is! Map) return null;
      // A second mode source is a shape this codec does not accept: the
      // launch carries the mode under `config` only (B-7).
      if (json.containsKey('mode')) return null;
      if (json['v'] != supportedVersion) return null;
      final config = _decodeConfig(json['config']);
      if (config == null) return null;
      final snapshotJson = json['snapshot'];
      if (snapshotJson is! Map) return null;
      final snapshot = _decodeSnapshot(snapshotJson);
      if (snapshot == null) return null;
      return OverlayWindowLaunch(config: config, snapshot: snapshot);
    } on Object {
      return null;
    }
  }

  /// Whether [payload]'s UTF-8 byte length is within [maxEncodedBytes].
  static bool _withinSizeGuard(String payload) =>
      utf8.encode(payload).length <= maxEncodedBytes;

  static Map<String, Object?> _encodeEntry(CaptionDisplayEntry entry) => {
        // The entry id is the Phase 8 translation key (forward note).
        'key': entry.entryId,
        'text': entry.text,
        'isFinal': entry.isFinal,
      };

  static Map<String, Object?> _encodeSettings(DisplaySettings settings) => {
        'scrollDirection': settings.scrollDirection.name,
        'captionTextSize': settings.captionTextSize.name,
        'captionFont': settings.captionFont.name,
        'themeModeSetting': settings.themeModeSetting.name,
        'maxVisibleLines': settings.maxVisibleLines,
      };

  static Map<String, Object?> _encodeConfig(OverlayConfig config) => {
        'mode': _modeExternalDisplay,
        'position': switch (config.position) {
          OverlayPositionTop() => 'top',
          OverlayPositionBottom() => 'bottom',
          // Not offerable for the external display: it cannot be encoded, and
          // the decode rejects anything but top/bottom (BR-U8-26).
          OverlayPositionCustom() => 'custom',
        },
      };

  static CaptionOverlaySnapshot? _decodeSnapshot(Map<Object?, Object?> json) {
    if (json['v'] != supportedVersion) return null;

    final activity = _enumByName(OverlayActivity.values, json['activity']);
    if (activity == null) return null;

    final entriesJson = json['entries'];
    if (entriesJson is! List) return null;
    final entries = <CaptionDisplayEntry>[];
    for (final raw in entriesJson) {
      final entry = _decodeEntry(raw);
      if (entry == null) return null;
      entries.add(entry);
    }

    final interimJson = json['interim'];
    final CaptionDisplayEntry? interim;
    if (interimJson == null) {
      interim = null;
    } else {
      interim = _decodeEntry(interimJson);
      if (interim == null) return null;
    }

    final settingsJson = json['settings'];
    if (settingsJson is! Map) return null;
    final settings = _decodeSettings(settingsJson);
    if (settings == null) return null;

    return CaptionOverlaySnapshot(
      activity: activity,
      entries: entries,
      interim: interim,
      settings: settings,
    );
  }

  static CaptionDisplayEntry? _decodeEntry(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final text = raw['text'];
    final isFinal = raw['isFinal'];
    if (key is! String || text is! String || isFinal is! bool) return null;
    return CaptionDisplayEntry(
      entryId: key,
      sessionId: _placeholderSessionId,
      text: text,
      isFinal: isFinal,
      sourceId: _placeholderSourceId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static DisplaySettings? _decodeSettings(Map<Object?, Object?> json) {
    final scrollDirection =
        _enumByName(ScrollDirection.values, json['scrollDirection']);
    final captionTextSize =
        _enumByName(CaptionTextSize.values, json['captionTextSize']);
    final captionFont = _enumByName(CaptionFont.values, json['captionFont']);
    final themeModeSetting =
        _enumByName(ThemeModeSetting.values, json['themeModeSetting']);
    final maxVisibleLines = json['maxVisibleLines'];
    if (scrollDirection == null ||
        captionTextSize == null ||
        captionFont == null ||
        themeModeSetting == null ||
        maxVisibleLines is! int) {
      return null;
    }
    return DisplaySettings(
      scrollDirection: scrollDirection,
      captionTextSize: captionTextSize,
      captionFont: captionFont,
      themeModeSetting: themeModeSetting,
      maxVisibleLines: maxVisibleLines,
    );
  }

  static OverlayConfig? _decodeConfig(Object? raw) {
    if (raw is! Map) return null;
    if (raw['mode'] != _modeExternalDisplay) return null;
    // The mode's display id is informational and never encoded, so the
    // default externalDisplay mode is the decoded one; the persisted selection
    // stays authoritative (BR-U8-07).
    final OverlayPosition position;
    switch (raw['position']) {
      case 'top':
        position = const OverlayPositionTop();
      case 'bottom':
        position = const OverlayPositionBottom();
      default:
        return null;
    }
    return OverlayConfig(position: position);
  }

  /// Looks up an enum value by name, returning `null` for anything unknown.
  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
/// Encodes [snapshot] for the window boundary. See [CaptionOverlayCodec].
String encodeSnapshot(CaptionOverlaySnapshot snapshot) =>
    CaptionOverlayCodec.encodeSnapshot(snapshot);

/// Decodes a snapshot payload, or `null`. See [CaptionOverlayCodec].
CaptionOverlaySnapshot? decodeSnapshot(String payload) =>
    CaptionOverlayCodec.decodeSnapshot(payload);

/// Encodes [launch] for the window's creation argument.
/// See [CaptionOverlayCodec].
String encodeLaunch(OverlayWindowLaunch launch) =>
    CaptionOverlayCodec.encodeLaunch(launch);

/// Decodes a launch payload, or `null`. See [CaptionOverlayCodec].
OverlayWindowLaunch? decodeLaunch(String payload) =>
    CaptionOverlayCodec.decodeLaunch(payload);
