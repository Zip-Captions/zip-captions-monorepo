// Tests for Unit 8.1 (S-21): the one codec, two modes (FD §5 POP-6;
// BR-U8.1-08). N-06.
//
// The two modes share the version and every field; only the mode token
// differs. These tests pin that a payload always decodes to the type it was
// encoded from, so a pop-out launch can never be rendered as an external
// display or the reverse.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/zip_core.dart';

OverlayWindowLaunch _launch(OverlayWindowMode mode) => OverlayWindowLaunch(
  config: OverlayConfig(mode: mode),
  snapshot: CaptionOverlaySnapshot(
    activity: OverlayActivity.standby,
    entries: const [],
    settings: DisplaySettings.defaults(),
  ),
);

Map<String, dynamic> _decodeJson(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  test('each mode token decodes to its own type', () {
    expect(
      decodeLaunch(
        encodeLaunch(_launch(const ExternalDisplayMode())),
      )!.config.mode,
      isA<ExternalDisplayMode>(),
    );
    expect(
      decodeLaunch(encodeLaunch(_launch(const PopOutMode())))!.config.mode,
      isA<PopOutMode>(),
    );
  });

  test('an external display payload never decodes as a pop-out', () {
    final decoded = decodeLaunch(
      encodeLaunch(_launch(const ExternalDisplayMode())),
    );

    expect(decoded!.config.mode, isNot(isA<PopOutMode>()));
  });

  test('a pop-out payload never decodes as an external display', () {
    final decoded = decodeLaunch(encodeLaunch(_launch(const PopOutMode())));

    expect(decoded!.config.mode, isNot(isA<ExternalDisplayMode>()));
  });

  test('the two tokens differ and the version does not', () {
    final external = _decodeJson(
      encodeLaunch(_launch(const ExternalDisplayMode())),
    );
    final popOut = _decodeJson(encodeLaunch(_launch(const PopOutMode())));

    expect(
      (external['config'] as Map)['mode'],
      isNot((popOut['config'] as Map)['mode']),
    );
    expect(external['v'], popOut['v']);
  });

  test('an unknown token is null', () {
    final encoded = encodeLaunch(_launch(const ExternalDisplayMode()));
    final tampered = encoded.replaceFirst('"externalDisplay"', '"slideshow"');

    expect(decodeLaunch(tampered), isNull);
  });

  test('both modes round-trip', () {
    for (final mode in <OverlayWindowMode>[
      const ExternalDisplayMode(),
      const PopOutMode(),
    ]) {
      final launch = _launch(mode);
      expect(decodeLaunch(encodeLaunch(launch)), launch);
    }
  });
}
