// Tests for Unit 8 (S-20): the versioned snapshot and launch codecs (B-7).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/models/overlay_position.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/zip_core.dart';

const _settings = DisplaySettings(
  scrollDirection: ScrollDirection.bottomToTop,
  captionTextSize: CaptionTextSize.md,
  captionFont: CaptionFont.atkinsonHyperlegible,
  themeModeSetting: ThemeModeSetting.dark,
  maxVisibleLines: 3,
);

CaptionDisplayEntry _entry(String id, String text, {bool isFinal = true}) =>
    CaptionDisplayEntry(
      entryId: id,
      sessionId: 'session-secret',
      text: text,
      isFinal: isFinal,
      sourceId: 'source-secret',
      timestamp: DateTime.utc(2026, 10, 20),
    );

void main() {
  group('snapshot round-trip', () {
    test('interim absent', () {
      final snapshot = CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: [_entry('a', 'hello'), _entry('b', 'world')],
        settings: _settings,
      );

      expect(decodeSnapshot(encodeSnapshot(snapshot)), snapshot);
    });

    test('interim present and multibyte text', () {
      final snapshot = CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: [_entry('a', 'Grüße, 世界')],
        interim: _entry('b', 'parti', isFinal: false),
        settings: _settings,
      );

      final decoded = decodeSnapshot(encodeSnapshot(snapshot))!;
      expect(decoded, snapshot);
      expect(decoded.interim!.text, 'parti');
      expect(decoded.entries.single.text, 'Grüße, 世界');
    });

    test('the wire shape is exactly the B-7 shape', () {
      final json =
          jsonDecode(
                encodeSnapshot(
                  const CaptionOverlaySnapshot(
                    activity: OverlayActivity.standby,
                    entries: [],
                    settings: _settings,
                  ),
                ),
              )
              as Map<String, dynamic>;

      // Shape change 2: `contentMode` joins the snapshot so the pop-out's
      // Phase 8 picker needs no transport change; the version stays 1.
      expect(json.keys.toSet(), {
        'v',
        'activity',
        'entries',
        'interim',
        'contentMode',
        'settings',
      });
      expect(json['v'], 1);
      expect(json['activity'], 'standby');
      expect(json['interim'], isNull);
      expect((json['settings'] as Map).keys.toSet(), {
        'scrollDirection',
        'captionTextSize',
        'captionFont',
        'themeModeSetting',
        'maxVisibleLines',
      });
    });

    test('the key is the entryId and sessionId/sourceId never cross', () {
      final encoded = encodeSnapshot(
        CaptionOverlaySnapshot(
          activity: OverlayActivity.live,
          entries: [_entry('segment-7', 'text')],
          settings: _settings,
        ),
      );

      expect(encoded, isNot(contains('session-secret')));
      expect(encoded, isNot(contains('source-secret')));

      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final entry = (json['entries'] as List).single as Map<String, dynamic>;
      expect(entry.keys.toSet(), {'key', 'text', 'isFinal'});
      expect(entry['key'], 'segment-7');

      final decoded = decodeSnapshot(encoded)!;
      expect(decoded.entries.single.entryId, 'segment-7');
    });

    test('the pause marker travels as a mirrored buffer entry', () {
      final pause = CaptionDisplayEntry(
        entryId: 'pause-1',
        sessionId: 'session-secret',
        text: '',
        isFinal: true,
        sourceId: '__pause__',
        timestamp: DateTime.utc(2026, 10, 20),
      );
      final snapshot = CaptionOverlaySnapshot(
        activity: OverlayActivity.paused,
        entries: [pause],
        settings: _settings,
      );

      final decoded = decodeSnapshot(encodeSnapshot(snapshot))!;
      // The entry is mirrored, but its source id is never encoded: the window
      // rebuilds it with a fixed placeholder, never `__pause__`.
      expect(decoded.activity, OverlayActivity.paused);
      expect(decoded.entries.single.entryId, 'pause-1');
      expect(decoded.entries.single.sourceId, isNot('__pause__'));
    });
  });

  group('launch round-trip', () {
    test('both caption positions', () {
      for (final position in <OverlayPosition>[
        const OverlayPositionTop(),
        const OverlayPositionBottom(),
      ]) {
        final launch = OverlayWindowLaunch(
          config: OverlayConfig(position: position),
          snapshot: const CaptionOverlaySnapshot(
            activity: OverlayActivity.standby,
            entries: [],
            settings: _settings,
          ),
        );

        expect(decodeLaunch(encodeLaunch(launch)), launch);
      }
    });

    test('a custom position is encoded as the decodable fallback', () {
      const launch = OverlayWindowLaunch(
        config: OverlayConfig(position: OverlayPositionCustom(x: 10, y: 10)),
        snapshot: CaptionOverlaySnapshot(
          activity: OverlayActivity.standby,
          entries: [],
          settings: _settings,
        ),
      );

      final decoded = decodeLaunch(encodeLaunch(launch));

      expect(decoded, isNotNull);
      expect(decoded!.config.position, isA<OverlayPositionBottom>());
    });

    test('exactly one mode source: config.mode', () {
      final json =
          jsonDecode(
                encodeLaunch(
                  const OverlayWindowLaunch(
                    config: OverlayConfig(),
                    snapshot: CaptionOverlaySnapshot(
                      activity: OverlayActivity.standby,
                      entries: [],
                      settings: _settings,
                    ),
                  ),
                ),
              )
              as Map<String, dynamic>;

      expect(json.keys.toSet(), {'v', 'config', 'snapshot'});
      expect((json['config'] as Map).keys.toSet(), {'mode', 'position'});
      expect(json.containsKey('mode'), isFalse);
      expect((json['config'] as Map)['mode'], 'externalDisplay');
      expect((json['config'] as Map)['position'], 'bottom');
    });
  });

  group('the encoder stays within the wire budget', () {
    test('the oldest final entries are dropped until the payload fits', () {
      final entries = [
        for (var i = 0; i < 400; i++) _entry('e$i', 'x' * 100),
      ];
      final snapshot = CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: entries,
        settings: _settings,
      );

      final encoded = encodeSnapshot(snapshot);

      expect(
        utf8.encode(encoded).length,
        lessThanOrEqualTo(CaptionOverlayCodec.maxEncodedBytes),
      );
      final decoded = decodeSnapshot(encoded)!;
      expect(decoded.entries, isNotEmpty);
      // The kept entries are the newest ones.
      expect(decoded.entries.last.entryId, 'e399');
    });

    test('the interim entry is dropped before any final entry', () {
      final snapshot = CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: [_entry('a', 'x' * 200)],
        interim: _entry('i', 'y' * 20000, isFinal: false),
        settings: _settings,
      );

      final decoded = decodeSnapshot(encodeSnapshot(snapshot))!;

      expect(decoded.interim, isNull);
      expect(decoded.entries.single.entryId, 'a');
    });

    test('a launch payload whose snapshot is trimmed still decodes', () {
      final snapshot = CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: [for (var i = 0; i < 400; i++) _entry('e$i', 'x' * 100)],
        settings: _settings,
      );
      final launch = OverlayWindowLaunch(
        config: const OverlayConfig(),
        snapshot: snapshot,
      );

      final encoded = encodeLaunch(launch);

      expect(
        utf8.encode(encoded).length,
        lessThanOrEqualTo(CaptionOverlayCodec.maxEncodedBytes),
      );
      expect(decodeLaunch(encoded), isNotNull);
    });
  });

  group('decode returns null (never throws) on', () {
    String validSnapshot() => encodeSnapshot(
      CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: [_entry('a', 'hello')],
        settings: _settings,
      ),
    );

    test('truncated json', () {
      expect(decodeSnapshot(validSnapshot().substring(0, 12)), isNull);
    });

    test('a wrong field type', () {
      final json = jsonDecode(validSnapshot()) as Map<String, dynamic>;
      json['entries'] = 'not-a-list';
      expect(decodeSnapshot(jsonEncode(json)), isNull);
    });

    test('an unknown version', () {
      final json = jsonDecode(validSnapshot()) as Map<String, dynamic>;
      json['v'] = 2;
      expect(decodeSnapshot(jsonEncode(json)), isNull);
    });

    test('an unknown activity', () {
      final json = jsonDecode(validSnapshot()) as Map<String, dynamic>;
      json['activity'] = 'dancing';
      expect(decodeSnapshot(jsonEncode(json)), isNull);
    });

    test('an unknown settings enum value', () {
      final json = jsonDecode(validSnapshot()) as Map<String, dynamic>;
      (json['settings'] as Map<String, dynamic>)['captionFont'] = 'comicSans';
      expect(decodeSnapshot(jsonEncode(json)), isNull);
    });

    test('an unknown launch position', () {
      final launch =
          jsonDecode(
                encodeLaunch(
                  const OverlayWindowLaunch(
                    config: OverlayConfig(),
                    snapshot: CaptionOverlaySnapshot(
                      activity: OverlayActivity.standby,
                      entries: [],
                      settings: _settings,
                    ),
                  ),
                ),
              )
              as Map<String, dynamic>;
      (launch['config'] as Map<String, dynamic>)['position'] = 'middle';
      expect(decodeLaunch(jsonEncode(launch)), isNull);
    });

    test('an unknown launch mode', () {
      final launch =
          jsonDecode(
                encodeLaunch(
                  const OverlayWindowLaunch(
                    config: OverlayConfig(),
                    snapshot: CaptionOverlaySnapshot(
                      activity: OverlayActivity.standby,
                      entries: [],
                      settings: _settings,
                    ),
                  ),
                ),
              )
              as Map<String, dynamic>;
      // `popOut` is a real mode now, so the unknown token is a third value.
      (launch['config'] as Map<String, dynamic>)['mode'] = 'slideshow';
      expect(decodeLaunch(jsonEncode(launch)), isNull);
    });

    test('a second mode source on the launch', () {
      final launch =
          jsonDecode(
                encodeLaunch(
                  const OverlayWindowLaunch(
                    config: OverlayConfig(),
                    snapshot: CaptionOverlaySnapshot(
                      activity: OverlayActivity.standby,
                      entries: [],
                      settings: _settings,
                    ),
                  ),
                ),
              )
              as Map<String, dynamic>;
      launch['mode'] = 'externalDisplay';
      expect(decodeLaunch(jsonEncode(launch)), isNull);
    });

    test('an over-size payload', () {
      // Built by hand: the encoder now trims to fit, so it cannot produce one.
      final oversized = jsonEncode({
        'v': 1,
        'activity': 'live',
        'entries': [
          {
            'key': 'a',
            'text': 'x' * (CaptionOverlayCodec.maxEncodedBytes),
            'isFinal': true,
          },
          {'key': 'b', 'text': 'y', 'isFinal': true},
        ],
        'interim': null,
        'settings': {
          'scrollDirection': 'bottomToTop',
          'captionTextSize': 'md',
          'captionFont': 'atkinsonHyperlegible',
          'themeModeSetting': 'dark',
          'maxVisibleLines': 3,
        },
      });
      expect(
        utf8.encode(oversized).length,
        greaterThan(CaptionOverlayCodec.maxEncodedBytes),
      );
      expect(decodeSnapshot(oversized), isNull);
    });

    test('a non-string input', () {
      expect(decodeSnapshot(''), isNull);
      expect(decodeLaunch('null'), isNull);
      expect(decodeSnapshot('[]'), isNull);
    });
  });
}
