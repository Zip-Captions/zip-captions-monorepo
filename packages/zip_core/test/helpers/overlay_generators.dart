// PBT generator library for the overlay window machinery (Unit 8.1).
//
// Moved from zip_broadcast ahead of the promotion (FD BLM §7 shape change 4:
// an app cannot import another package's test/ directory, so the overlay
// generators live here and zip_broadcast keeps only the generators its own
// remaining tests need).

import 'dart:math';
import 'dart:ui';

import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/models/overlay_position.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/zip_core.dart';

import 'pbt.dart';

/// Generates a logical work-area [Rect] anywhere on a virtual desktop.
final Generator<Rect> arbitraryBounds = any.combine4(
  any.doubleInRange(-2000, 4000),
  any.doubleInRange(-2000, 2000),
  any.doubleInRange(0, 3000),
  any.doubleInRange(0, 2000),
  Rect.fromLTWH,
);

/// One command in the external display controller's FP-5 sequence.
sealed class OverlayCommand {
  const OverlayCommand();
}

/// A toggle-on gesture (T5/T16).
final class ToggleOnCommand extends OverlayCommand {
  /// Creates a [ToggleOnCommand].
  const ToggleOnCommand({required this.savedId});

  /// The broadcaster's saved display id, if any.
  final String? savedId;
}

/// A toggle-off gesture (T13).
final class ToggleOffCommand extends OverlayCommand {
  /// Creates a [ToggleOffCommand].
  const ToggleOffCommand();
}

/// A display-list change (T3/T4/T10/T11/T15/T17).
final class DisplaysChangedCommand extends OverlayCommand {
  /// Creates a [DisplaysChangedCommand].
  const DisplaysChangedCommand({required this.keepSaved, required this.noise});

  /// Whether the saved display is still present.
  final bool keepSaved;

  /// Whether the surviving display's bounds moved (T15).
  final bool noise;
}

/// The sub-engine reports ready (T7).
final class OverlayReadyCommand extends OverlayCommand {
  /// Creates an [OverlayReadyCommand].
  const OverlayReadyCommand();
}

/// The ready timeout elapses (T8).
final class AdvanceReadyTimeoutCommand extends OverlayCommand {
  /// Creates an [AdvanceReadyTimeoutCommand].
  const AdvanceReadyTimeoutCommand();
}

/// The window reported `'-1'` (T14).
final class WindowGoneCommand extends OverlayCommand {
  /// Creates a [WindowGoneCommand].
  const WindowGoneCommand();
}

/// A window call failed with a non-`'-1'` code (B-5).
final class OtherPlatformErrorCommand extends OverlayCommand {
  /// Creates an [OtherPlatformErrorCommand].
  const OtherPlatformErrorCommand();
}

/// `createWindow` throws (T6).
final class CreateWindowFailsCommand extends OverlayCommand {
  /// Creates a [CreateWindowFailsCommand].
  const CreateWindowFailsCommand();
}

/// A caption event reaches the controller's push path (T9).
final class CaptionEventCommand extends OverlayCommand {
  /// Creates a [CaptionEventCommand].
  const CaptionEventCommand({required this.activity});

  /// The recognition activity the snapshot carries.
  final OverlayActivity activity;
}

/// The caption coalescing interval elapses (P1).
final class ElapseCommand extends OverlayCommand {
  /// Creates an [ElapseCommand].
  const ElapseCommand();
}

const List<String> _overlayIds = <String>['a', 'b'];

OverlayCommand _overlayCommand(Random random) {
  final savedId = random.nextBool()
      ? null
      : _overlayIds[random.nextInt(_overlayIds.length)];
  switch (random.nextInt(12)) {
    case 0:
    case 1:
      return ToggleOnCommand(savedId: savedId);
    case 2:
    case 3:
      return const ToggleOffCommand();
    case 4:
    case 5:
      return DisplaysChangedCommand(
        keepSaved: random.nextBool(),
        noise: random.nextBool(),
      );
    case 6:
      return const OverlayReadyCommand();
    case 7:
      return const AdvanceReadyTimeoutCommand();
    case 8:
      return const WindowGoneCommand();
    case 9:
      return const OtherPlatformErrorCommand();
    case 10:
      return const CreateWindowFailsCommand();
    case 11:
      return CaptionEventCommand(
        activity: OverlayActivity.values[random.nextInt(3)],
      );
    default:
      return const ElapseCommand();
  }
}

/// Generates a short command sequence for FP-5.
List<OverlayCommand> _overlayCommandSequence(Random random) {
  final length = 1 + random.nextInt(12);
  return List<OverlayCommand>.generate(
    length,
    (_) => _overlayCommand(random),
  );
}

const Generator<List<OverlayCommand>> arbitraryOverlayCommandSequence =
    _overlayCommandSequence;

/// Generates a logical top-left frame, including negative offsets and frames
/// taller than the display they sit on.
final Generator<Rect> arbitraryLogicalFrame = any.combine4(
  any.doubleInRange(-2000, 4000),
  any.doubleInRange(-2000, 2000),
  any.doubleInRange(1, 3000),
  any.doubleInRange(1, 2000),
  Rect.fromLTWH,
);

/// Generates a primary display's full height, menu bar included.
final Generator<double> arbitraryDisplayHeight = any.doubleInRange(600, 2400);

/// Scale factors a display realistically reports, including the degenerate
/// `0` that the Windows conversion treats as `1`.
final Generator<double> arbitraryScaleFactor = any.choose<double>(<double>[
  0,
  1,
  1.25,
  1.5,
  2,
  3,
]);

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

const Generator<List<DisplayInfo>> arbitraryDisplayList = _generateDisplayList;

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

CaptionDisplayEntry _generateSnapshotEntry(Random random) =>
    CaptionDisplayEntry(
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
  (
    scrollDirection,
    captionTextSize,
    captionFont,
    themeModeSetting,
    maxVisibleLines,
  ) => DisplaySettings(
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
      // Unknown launch mode token: neither of the two accepted modes.
      return '{"v":1,"config":{"mode":"slideshow","position":"top"},'
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

/// Scale factors a pop-out geometry input can see, matching the display
/// generator's realistic set (including the degenerate `0`).
const Generator<double> arbitraryTextScale = any.choose<double>(
  <double>[1, 1.2, 1.5, 2, 3],
);

/// Generates a work-area width together with a text
/// scaler, the two inputs POP-4's monotonicity clauses vary (FD §5).
class PopOutGeometryInput {
  /// Creates a [PopOutGeometryInput].
  const PopOutGeometryInput({
    required this.workAreaWidth,
    required this.textScale,
  });

  /// The display work area's width in logical pixels.
  final double workAreaWidth;

  /// The window's text scaler.
  final double textScale;
}

final Generator<PopOutGeometryInput> _popOutGeometryInput = any.combine2(
  any.doubleInRange(320, 4000),
  arbitraryTextScale,
  (workAreaWidth, textScale) => PopOutGeometryInput(
    workAreaWidth: workAreaWidth,
    textScale: textScale,
  ),
);

/// Generates a [PopOutGeometryInput] (PBT-07).
const Generator<PopOutGeometryInput> arbitraryPopOutGeometryInput =
    _popOutGeometryInput;
