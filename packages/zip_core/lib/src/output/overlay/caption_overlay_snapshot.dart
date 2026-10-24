import 'package:flutter/foundation.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/zip_core.dart';

/// What the pop-out shows.
///
/// Phase 8's content setting (UX-PIP-06); in Phase 2 the field travels but is
/// always [PopOutContentMode.originalOnly], because translation does not exist
/// yet (FD domain-entities §1.3, §3.4).
enum PopOutContentMode {
  /// Original language captions only.
  originalOnly,

  /// Translated captions only.
  translatedOnly,

  /// Original and translated captions together.
  originalAndTranslated,
}

/// The payload a caption window renders.
///
/// Travels in the window's creation argument (inside `OverlayWindowLaunch`)
/// and in every `captionUpdate` message. It is the only permitted carrier of
/// caption text across the window boundary and is never logged, stringified
/// into an error, or sent off-device (BR-U8-18).
///
/// Equality and `hashCode` are hand-written because the codec's round-trip
/// property compares decoded snapshots structurally.
@immutable
class CaptionOverlaySnapshot {
  /// Creates a [CaptionOverlaySnapshot].
  const CaptionOverlaySnapshot({
    required this.activity,
    required this.entries,
    required this.settings,
    this.interim,
    this.contentMode = PopOutContentMode.originalOnly,
  });

  /// What the window shows, selected by the recognition state (D-5).
  final OverlayActivity activity;

  /// Final captions, oldest first.
  final List<CaptionDisplayEntry> entries;

  /// The trailing non-final entry, if any.
  final CaptionDisplayEntry? interim;

  /// The broadcaster's display settings at the moment of the update.
  final DisplaySettings settings;

  /// Which caption content the window shows (deferred picker; the wire field
  /// ships so Phase 8 adds the UI, not the transport).
  final PopOutContentMode contentMode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptionOverlaySnapshot &&
          other.activity == activity &&
          _sameEntries(other.entries, entries) &&
          _sameEntry(other.interim, interim) &&
          other.settings == settings &&
          other.contentMode == contentMode;

  @override
  int get hashCode => Object.hash(
        activity,
        Object.hashAll(entries.map(_entryHash)),
        interim == null ? null : _entryHash(interim!),
        settings,
        contentMode,
      );

  /// Compares entries by the three fields that cross the window boundary.
  ///
  /// `CaptionDisplayEntry` equality also compares `sessionId`, `sourceId` and
  /// `timestamp`, none of which are encoded (BR-U8-24), so model equality can
  /// never hold for a decoded entry.
  static bool _sameEntry(CaptionDisplayEntry? a, CaptionDisplayEntry? b) {
    if (a == null || b == null) return a == b;
    return a.entryId == b.entryId &&
        a.text == b.text &&
        a.isFinal == b.isFinal;
  }

  static int _entryHash(CaptionDisplayEntry entry) =>
      Object.hash(entry.entryId, entry.text, entry.isFinal);

  static bool _sameEntries(
    List<CaptionDisplayEntry> a,
    List<CaptionDisplayEntry> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameEntry(a[i], b[i])) return false;
    }
    return true;
  }
}
