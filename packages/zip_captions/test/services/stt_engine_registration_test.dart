// Tests for Unit 10, P6 (BR-U10-01 to 07a) and Amendment 03 Step G7: the
// compile-time gating seam and the per-platform engine choice.
//
// `registerSttEngines` is a pure function: it decides which engines reach the
// registry from values the caller passes, and never consults the platform
// itself. That is what lets a release build strip the dev fake entirely.
// Amendment 03 gives Android its own engine: Android registers the segmented
// engine and never reaches the `speech_to_text` closure, iOS keeps
// `PlatformSttEngine`, and both answer to `engineId == 'platform'`.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/services/stt_engine_registration.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/pbt.dart' as pbt;

/// A stand-in for `PlatformSttEngine`: it only has to answer [engineId], and
/// the seam must be shown to call its factory exactly when it registers it.
class _PlatformEngineStub implements SttEngine {
  @override
  String get engineId => 'platform';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A stand-in for `SegmentedSpeechEngine`: same `engineId` (Amendment 03
/// section 3), distinguished only by its runtime type.
class _SegmentedEngineStub implements SttEngine {
  @override
  String get engineId => 'platform';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The platforms the seam distinguishes.
const List<TargetPlatform> _mobilePlatforms = [
  TargetPlatform.iOS,
  TargetPlatform.android,
];
const List<TargetPlatform> _otherPlatforms = [
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
];

void main() {
  group('registerSttEngines', () {
    late SttEngineRegistry registry;
    late int createCalls;
    late int createSegmentedCalls;

    setUp(() {
      registry = SttEngineRegistry();
      createCalls = 0;
      createSegmentedCalls = 0;
    });

    SttEngine createEngine() {
      createCalls++;
      return _PlatformEngineStub();
    }

    SttEngine createSegmentedEngine() {
      createSegmentedCalls++;
      return _SegmentedEngineStub();
    }

    /// Runs the seam with both closures wired to the counters.
    void register({
      required TargetPlatform platform,
      required bool isWeb,
      required bool allowDevEngines,
      required bool forceFake,
    }) {
      registerSttEngines(
        registry,
        platform: platform,
        isWeb: isWeb,
        allowDevEngines: allowDevEngines,
        forceFake: forceFake,
        createPlatformEngine: createEngine,
        createSegmentedEngine: createSegmentedEngine,
      );
    }

    /// The engine ids the registry holds, sorted for comparison.
    List<String> registeredIds() =>
        registry.listAvailable().map((e) => e.engineId).toList()..sort();

    test('TP-3: with allowDevEngines false the fake is never registered', () {
      for (final platform in [..._mobilePlatforms, ..._otherPlatforms]) {
        for (final isWeb in [false, true]) {
          for (final forceFake in [false, true]) {
            registry = SttEngineRegistry();
            register(
              platform: platform,
              isWeb: isWeb,
              allowDevEngines: false,
              forceFake: forceFake,
            );

            expect(
              registry.getEngine('fake'),
              isNull,
              reason: 'platform=$platform isWeb=$isWeb forceFake=$forceFake',
            );
          }
        }
      }
    });

    test('TP-10: with allowDevEngines false a mobile registry holds exactly '
        'the platform engine', () {
      for (final platform in _mobilePlatforms) {
        registry = SttEngineRegistry();
        register(
          platform: platform,
          isWeb: false,
          allowDevEngines: false,
          forceFake: false,
        );

        expect(registry.listAvailable(), hasLength(1), reason: '$platform');
        expect(registry.getEngine('platform')!.engineId, 'platform');
        // The engine is the platform's own (Amendment 03 section 3).
        expect(
          registry.getEngine('platform'),
          platform == TargetPlatform.android
              ? isA<_SegmentedEngineStub>()
              : isA<_PlatformEngineStub>(),
          reason: '$platform',
        );
      }
    });

    test('TP-10: with allowDevEngines false nothing else registers', () {
      for (final platform in _otherPlatforms) {
        for (final isWeb in [false, true]) {
          registry = SttEngineRegistry();
          createCalls = 0;
          createSegmentedCalls = 0;
          register(
            platform: platform,
            isWeb: isWeb,
            allowDevEngines: false,
            forceFake: false,
          );

          expect(
            registry.listAvailable(),
            isEmpty,
            reason: 'platform=$platform isWeb=$isWeb',
          );
          expect(
            createCalls,
            0,
            reason:
                '$platform builds no platform '
                'engine',
          );
          expect(
            createSegmentedCalls,
            0,
            reason:
                '$platform builds no '
                'segmented engine',
          );
        }
      }
    });

    test('TP-10 pin: an iOS release build registers the platform engine', () {
      register(
        platform: TargetPlatform.iOS,
        isWeb: false,
        allowDevEngines: false,
        forceFake: false,
      );

      expect(registeredIds(), ['platform']);
      expect(registry.getEngine('platform'), isA<_PlatformEngineStub>());
      expect(createCalls, 1);
      expect(createSegmentedCalls, 0, reason: 'iOS keeps PlatformSttEngine');
    });

    test('TP-10 pin: an Android release build registers the segmented '
        'engine as the platform engine', () {
      register(
        platform: TargetPlatform.android,
        isWeb: false,
        allowDevEngines: false,
        forceFake: false,
      );

      expect(registeredIds(), ['platform']);
      expect(registry.getEngine('platform'), isA<_SegmentedEngineStub>());
      expect(createSegmentedCalls, 1);
      expect(
        createCalls,
        0,
        reason:
            'Android no longer uses speech_to_text (Amendment 03 '
            'section 2)',
      );
    });

    test('TP-4: debug on mobile without forceFake registers the platform '
        'engine and no fake', () {
      for (final platform in _mobilePlatforms) {
        registry = SttEngineRegistry();
        register(
          platform: platform,
          isWeb: false,
          allowDevEngines: true,
          forceFake: false,
        );

        expect(registeredIds(), ['platform'], reason: '$platform');
        expect(registry.getEngine('fake'), isNull);
        expect(
          registry.getEngine('platform'),
          platform == TargetPlatform.android
              ? isA<_SegmentedEngineStub>()
              : isA<_PlatformEngineStub>(),
          reason: '$platform',
        );
      }
    });

    test('TP-4: debug on mobile with forceFake registers only the fake', () {
      for (final platform in _mobilePlatforms) {
        registry = SttEngineRegistry();
        createCalls = 0;
        createSegmentedCalls = 0;
        register(
          platform: platform,
          isWeb: false,
          allowDevEngines: true,
          forceFake: true,
        );

        expect(registeredIds(), ['fake'], reason: '$platform');
        expect(registry.getEngine('platform'), isNull);
        expect(
          createCalls,
          0,
          reason:
              'the forced fake builds nothing '
              'real',
        );
        expect(
          createSegmentedCalls,
          0,
          reason:
              'the forced fake builds '
              'nothing real',
        );
      }
    });

    test('TP-4: debug on desktop or web registers only the fake', () {
      for (final platform in _otherPlatforms) {
        for (final isWeb in [false, true]) {
          registry = SttEngineRegistry();
          register(
            platform: platform,
            isWeb: isWeb,
            allowDevEngines: true,
            forceFake: false,
          );

          expect(
            registeredIds(),
            ['fake'],
            reason: 'platform=$platform isWeb=$isWeb',
          );
        }
      }
    });

    test('TP-5: each mobile create closure is called exactly when its '
        'engine is registered, and never otherwise', () {
      final cases = <(TargetPlatform, bool, bool, bool)>[
        (TargetPlatform.iOS, false, false, false), // release mobile
        (TargetPlatform.android, false, false, true), // forced fake is moot
        (TargetPlatform.iOS, false, true, true), // debug mobile, forced fake
        (TargetPlatform.android, false, true, true), // debug Android, forced
        (TargetPlatform.macOS, false, true, false), // debug desktop
        (TargetPlatform.android, true, true, false), // debug web
        (TargetPlatform.iOS, false, true, false), // debug iOS, real engine
        (TargetPlatform.android, false, true, false), // debug Android, real
      ];

      for (final (platform, isWeb, allowDevEngines, forceFake) in cases) {
        registry = SttEngineRegistry();
        createCalls = 0;
        createSegmentedCalls = 0;
        register(
          platform: platform,
          isWeb: isWeb,
          allowDevEngines: allowDevEngines,
          forceFake: forceFake,
        );

        final platformRegistered = registry.getEngine('platform') != null;
        expect(
          createCalls,
          platformRegistered && platform == TargetPlatform.iOS ? 1 : 0,
          reason:
              'platform=$platform isWeb=$isWeb '
              'allowDevEngines=$allowDevEngines forceFake=$forceFake',
        );
        expect(
          createSegmentedCalls,
          platformRegistered && platform == TargetPlatform.android ? 1 : 0,
          reason:
              'platform=$platform isWeb=$isWeb '
              'allowDevEngines=$allowDevEngines forceFake=$forceFake',
        );
      }
    });

    test('TP-5: createPlatformEngine is never called on Android', () {
      for (final allowDevEngines in [false, true]) {
        for (final forceFake in [false, true]) {
          registry = SttEngineRegistry();
          createCalls = 0;
          register(
            platform: TargetPlatform.android,
            isWeb: false,
            allowDevEngines: allowDevEngines,
            forceFake: forceFake,
          );

          expect(
            createCalls,
            0,
            reason: 'allowDevEngines=$allowDevEngines forceFake=$forceFake',
          );
        }
      }
    });

    test('TP-5: createSegmentedEngine is never called on iOS', () {
      for (final allowDevEngines in [false, true]) {
        for (final forceFake in [false, true]) {
          registry = SttEngineRegistry();
          createSegmentedCalls = 0;
          register(
            platform: TargetPlatform.iOS,
            isWeb: false,
            allowDevEngines: allowDevEngines,
            forceFake: forceFake,
          );

          expect(
            createSegmentedCalls,
            0,
            reason: 'allowDevEngines=$allowDevEngines forceFake=$forceFake',
          );
        }
      }
    });

    test('TP-5: a desktop or web build never calls either mobile closure', () {
      for (final platform in _otherPlatforms) {
        for (final forceFake in [false, true]) {
          registry = SttEngineRegistry();
          createCalls = 0;
          createSegmentedCalls = 0;
          register(
            platform: platform,
            isWeb: false,
            allowDevEngines: true,
            forceFake: forceFake,
          );

          expect(createCalls, 0, reason: '$platform');
          expect(createSegmentedCalls, 0, reason: '$platform');
        }
      }
    });

    // Q-7: bootstrap feeds the seam the platform's own identifier, never a
    // hand-typed literal, so the test does the same for every platform.
    test('Q-7: over every TargetPlatform, exactly iOS and Android register a '
        'platform engine', () {
      for (final p in TargetPlatform.values) {
        registry = SttEngineRegistry();
        createCalls = 0;
        createSegmentedCalls = 0;
        register(
          platform: p,
          isWeb: false,
          allowDevEngines: false,
          forceFake: false,
        );

        switch (p) {
          case TargetPlatform.iOS:
            expect(registeredIds(), ['platform'], reason: '$p');
            expect(registry.getEngine('platform'), isA<_PlatformEngineStub>());
            expect(createCalls, 1, reason: '$p');
            expect(createSegmentedCalls, 0, reason: '$p');
          case TargetPlatform.android:
            expect(registeredIds(), ['platform'], reason: '$p');
            expect(registry.getEngine('platform'), isA<_SegmentedEngineStub>());
            expect(createCalls, 0, reason: '$p');
            expect(createSegmentedCalls, 1, reason: '$p');
          case TargetPlatform.fuchsia ||
              TargetPlatform.linux ||
              TargetPlatform.macOS ||
              TargetPlatform.windows:
            expect(registeredIds(), isEmpty, reason: '$p');
            expect(createCalls, 0, reason: '$p');
            expect(createSegmentedCalls, 0, reason: '$p');
        }
      }
    });

    // PBT-10: the seam is total over the cross product of its inputs. Every
    // combination must leave a registry the app can use, with no exception.
    pbt.Glados<(TargetPlatform, bool, bool, bool)>(
      pbt.any.combine2(
        pbt.any.choose([..._mobilePlatforms, ..._otherPlatforms]),
        pbt.any.combine2(
          pbt.any.boolGen,
          pbt.any.boolGen,
          (isWeb, allowDevEngines) => (isWeb, allowDevEngines),
        ),
        (platform, rest) => (platform, rest.$1, rest.$2, false),
      ),
    ).test('TP-3/TP-4/TP-5: no input combination throws and the dev engine '
        'only appears when allowed', (inputs) {
      final (platform, isWeb, allowDevEngines, _) = inputs;
      final local = SttEngineRegistry();
      var calls = 0;
      var segmentedCalls = 0;

      registerSttEngines(
        local,
        platform: platform,
        isWeb: isWeb,
        allowDevEngines: allowDevEngines,
        forceFake: false,
        createPlatformEngine: () {
          calls++;
          return _PlatformEngineStub();
        },
        createSegmentedEngine: () {
          segmentedCalls++;
          return _SegmentedEngineStub();
        },
      );

      final ids = local.listAvailable().map((e) => e.engineId).toList();
      if (!allowDevEngines) {
        expect(
          ids,
          isNot(contains('fake')),
          reason:
              'platform=$platform isWeb=$isWeb '
              'allowDevEngines=$allowDevEngines',
        );
      }
      if (!isWeb && _mobilePlatforms.contains(platform)) {
        expect(ids, contains('platform'), reason: '$platform');
        expect(
          local.getEngine('platform'),
          platform == TargetPlatform.android
              ? isA<_SegmentedEngineStub>()
              : isA<_PlatformEngineStub>(),
          reason: '$platform',
        );
        // Exactly one closure runs, the one the platform owns.
        expect(calls + segmentedCalls, 1, reason: '$platform');
        expect(
          calls,
          platform == TargetPlatform.iOS ? 1 : 0,
          reason: '$platform',
        );
        expect(
          segmentedCalls,
          platform == TargetPlatform.android ? 1 : 0,
          reason: '$platform',
        );
      } else {
        expect(ids, isNot(contains('platform')), reason: '$platform');
        expect(calls, 0);
        expect(segmentedCalls, 0);
      }
    });
  });
}
