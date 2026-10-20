// PBT generator library for zip_broadcast tests.
//
// Centralized Generator<T> instances for zip_broadcast domain types.

import 'dart:math';
import 'dart:ui';

import 'package:zip_broadcast/src/models/obs_connection_state.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_broadcast/src/output/overlay/display_info.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/zip_core.dart';

import 'pbt.dart';

/// Generates all sealed [ObsConnectionState] variants with plausible fields.
final Generator<ObsConnectionState> arbitraryObsConnectionState =
    any.choose(<ObsConnectionState>[
  const ObsDisconnected(),
  const ObsConnecting(),
  const ObsConnected(),
  const ObsReconnecting(attempt: 1, nextRetryMs: 1000),
  const ObsReconnecting(attempt: 3, nextRetryMs: 4000),
  const ObsReconnecting(attempt: 6, nextRetryMs: 30000),
  const ObsError(message: 'connection failed'),
  const ObsError(message: 'Could not connect to OBS after 10 minutes.'),
]);

/// Generates [OutputTargetSettings] with random bool toggles and a valid port.
final Generator<OutputTargetSettings> arbitraryOutputTargetSettings =
    any.combine5(
  any.boolGen,
  any.boolGen,
  any.boolGen,
  any.boolGen,
  any.intInRange(1024, 65536),
  (onScreen, obs, browser, overlay, port) =>
      OutputTargetSettings(
    onScreenEnabled: onScreen,
    obsEnabled: obs,
    browserSourceEnabled: browser,
    overlayEnabled: overlay,
    browserSourcePort: port,
  ),
);

/// Generates a logical work-area [Rect] anywhere on a virtual desktop.
final Generator<Rect> arbitraryBounds = any.combine4(
  any.doubleInRange(-2000, 4000),
  any.doubleInRange(-2000, 2000),
  any.doubleInRange(0, 3000),
  any.doubleInRange(0, 2000),
  Rect.fromLTWH,
);

/// Scale factors a display realistically reports, including the degenerate
/// `0` that the Windows conversion treats as `1`.
final Generator<double> arbitraryScaleFactor =
    any.choose<double>(<double>[0, 1, 1.25, 1.5, 2, 3]);

/// Generates a single [DisplayInfo]. Ids cover the opaque platform form, the
/// Linux-normalised `display-<n>` form and the empty string; labels may be
/// empty (BR-U8-08).
final Generator<DisplayInfo> arbitraryDisplayInfo = any.combine5(
  any.combine2(
    any.intInRange(0, 4),
    any.letterOrDigits,
    (index, suffix) => switch (index) {
      0 => 'display-$index',
      1 => '',
      _ => 'id-$suffix',
    },
  ),
  any.letterOrDigits,
  arbitraryBounds,
  arbitraryScaleFactor,
  any.boolGen,
  (id, label, bounds, scaleFactor, isPrimary) => DisplayInfo(
    id: id,
    label: label,
    bounds: bounds,
    scaleFactor: scaleFactor,
    isPrimary: isPrimary,
  ),
);

/// Generates a display list of 0..4 entries with **at most one** primary
/// display, at an arbitrary platform position.
List<DisplayInfo> _generateDisplayList(Random random) {
  final length = random.nextInt(5);
  final primaryIndex = length == 0 ? -1 : random.nextInt(length);
  return List<DisplayInfo>.generate(length, (index) {
    final display = arbitraryDisplayInfo(random);
    return display.copyWith(isPrimary: index == primaryIndex);
  });
}

const Generator<List<DisplayInfo>> arbitraryDisplayList =
    _generateDisplayList;

/// Generates a display list that contains a display with [id], honouring the
/// at-most-one-primary rule.
Generator<List<DisplayInfo>> arbitraryDisplayListContaining(String id) =>
    (random) {
      final displays = arbitraryDisplayList(random);
      if (displays.isEmpty) {
        final display = arbitraryDisplayInfo(random);
        return [display.copyWith(id: id, isPrimary: true)];
      }
      final target = random.nextInt(displays.length);
      return [
        for (var i = 0; i < displays.length; i++)
          i == target ? displays[i].copyWith(id: id) : displays[i],
      ];
    };

/// A generated snapshot together with the entry count it used, so a caller can
/// assert the generator's own bounds.
class CaptionOverlaySnapshotFixture {
  /// Creates a [CaptionOverlaySnapshotFixture].
  const CaptionOverlaySnapshotFixture(this.snapshot);

  /// The generated snapshot.
  final CaptionOverlaySnapshot snapshot;
}

/// A generated launch config.
class OverlayWindowLaunchFixture {
  /// Creates an [OverlayWindowLaunchFixture].
  const OverlayWindowLaunchFixture(this.launch);

  /// The generated launch.
  final OverlayWindowLaunch launch;
}

const List<String> _captionWords = <String>[
  'hello',
  'Grüße',
  '世界',
  'naïve café',
  'کلمات',
  'a',
  '',
];

String _generateCaptionText(Random random) {
  final wordCount = random.nextInt(4);
  return List<String>.generate(
    wordCount,
    (_) => _captionWords[random.nextInt(_captionWords.length)],
  ).join(' ');
}

const Generator<String> _captionText = _generateCaptionText;

CaptionDisplayEntry _generateSnapshotEntry(Random random) => CaptionDisplayEntry(
      // Each `key` travels as the entryId (BR-U8-24); the session and source
      // ids are never encoded.
      entryId: 'entry-${random.nextInt(1000)}-${random.nextInt(1000)}',
      sessionId: 'ignored-session',
      text: _captionText(random),
      isFinal: true,
      sourceId: random.nextBool() ? 'default' : '__pause__',
      // A timestamp the codec cannot represent exactly (it is not encoded), and
      // neither is the session or source id.
      timestamp: DateTime.utc(2026, 10, 20, 3, 4, 5, 6),
    );

const Generator<CaptionDisplayEntry> _snapshotEntry = _generateSnapshotEntry;

final Generator<DisplaySettings> _displaySettings = any.combine5(
  any.choose(ScrollDirection.values),
  any.choose(CaptionTextSize.values),
  any.choose(CaptionFont.values),
  any.choose(ThemeModeSetting.values),
  any.intInRange(0, 10),
  (scrollDirection, captionTextSize, captionFont, themeModeSetting, maxVisibleLines) =>
      DisplaySettings(
        scrollDirection: scrollDirection,
        captionTextSize: captionTextSize,
        captionFont: captionFont,
        themeModeSetting: themeModeSetting,
        maxVisibleLines: maxVisibleLines,
      ),
);

CaptionOverlaySnapshot _generateSnapshot(Random random) {
  final entryCount = random.nextInt(6);
  final hasInterim = random.nextBool();
  return CaptionOverlaySnapshot(
    activity: OverlayActivity.values[random.nextInt(3)],
    entries: List<CaptionDisplayEntry>.generate(
      entryCount,
      (_) => _snapshotEntry(random),
    ),
    interim: hasInterim
        ? _snapshotEntry(random).copyWith(isFinal: false)
        : null,
    settings: _displaySettings(random),
  );
}

const Generator<CaptionOverlaySnapshotFixture> arbitraryCaptionOverlaySnapshot =
    _generateSnapshotFixture;

CaptionOverlaySnapshotFixture _generateSnapshotFixture(Random random) =>
    CaptionOverlaySnapshotFixture(_generateSnapshot(random));

OverlayWindowLaunchFixture _generateLaunch(Random random) {
  final position = random.nextBool()
      ? const OverlayPositionTop()
      : const OverlayPositionBottom();
  return OverlayWindowLaunchFixture(
    OverlayWindowLaunch(
      config: OverlayConfig(position: position),
      snapshot: _generateSnapshot(random),
    ),
  );
}

const Generator<OverlayWindowLaunchFixture> arbitraryOverlayWindowLaunch =
    _generateLaunch;

String _malformedWindowJson(Random random) {
  switch (random.nextInt(10)) {
    case 0:
      // Truncated JSON.
      return '{"v":1,"activity":"live","entries":[';
    case 1:
      // Not an object at all.
      return any.choose<String>(<String>['[]', '"a string"', '42', 'null', ''])(
        random,
      );
    case 2:
      // Unknown version.
      return '{"v":${2 + random.nextInt(5)},"activity":"live","entries":[],'
          '"interim":null,"settings":{"scrollDirection":"bottomToTop",'
          '"captionTextSize":"md","captionFont":"poppins",'
          '"themeModeSetting":"dark","maxVisibleLines":0}}';
    case 3:
      // Unknown activity.
      return '{"v":1,"activity":"dancing","entries":[],"interim":null,'
          '"settings":{"scrollDirection":"bottomToTop",'
          '"captionTextSize":"md","captionFont":"poppins",'
          '"themeModeSetting":"dark","maxVisibleLines":0}}';
    case 4:
      // Unknown settings enum value.
      return '{"v":1,"activity":"live","entries":[],"interim":null,'
          '"settings":{"scrollDirection":"sideways",'
          '"captionTextSize":"md","captionFont":"poppins",'
          '"themeModeSetting":"dark","maxVisibleLines":0}}';
    case 5:
      // Unknown launch position (a launch-only field).
      return '{"v":1,"config":{"mode":"externalDisplay","position":"middle"},'
          '"snapshot":{"v":1,"activity":"live","entries":[],"interim":null,'
          '"settings":{"scrollDirection":"bottomToTop",'
          '"captionTextSize":"md","captionFont":"poppins",'
          '"themeModeSetting":"dark","maxVisibleLines":0}}}';
    case 6:
      // Unknown launch mode.
      return '{"v":1,"config":{"mode":"popOut","position":"top"},'
          '"snapshot":{"v":1,"activity":"live","entries":[],"interim":null,'
          '"settings":{"scrollDirection":"bottomToTop",'
          '"captionTextSize":"md","captionFont":"poppins",'
          '"themeModeSetting":"dark","maxVisibleLines":0}}}';
    case 7:
      // Wrong field type for entries.
      return '{"v":1,"activity":"live","entries":"nope","interim":null,'
          '"settings":{"scrollDirection":"bottomToTop",'
          '"captionTextSize":"md","captionFont":"poppins",'
          '"themeModeSetting":"dark","maxVisibleLines":0}}';
    case 8:
      // Over the size guard.
      return '{"v":1,"activity":"live","entries":[{"key":"a","text":"'
          '${'x' * (CaptionOverlayCodec.maxEncodedBytes + 1)}"'
          ',"isFinal":true}],"interim":null,"settings":{"scrollDirection":'
          '"bottomToTop","captionTextSize":"md","captionFont":"poppins",'
          '"themeModeSetting":"dark","maxVisibleLines":0}}';
    default:
      // A truncated multibyte payload.
      return '{"v":1,"activity":"live","entries":[{"key":"a","text":"Grüße';
  }
}

const Generator<String> arbitraryMalformedWindowJson = _malformedWindowJson;
