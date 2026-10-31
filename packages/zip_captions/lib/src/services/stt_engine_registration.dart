import 'package:flutter/foundation.dart';
import 'package:zip_core/zip_core.dart';

/// Registers the STT engines this build may use (Unit 10, P6).
///
/// A pure function: every input that decides the outcome is a parameter, and
/// nothing here consults the platform. The call site passes compile-time
/// constants (`kDebugMode` and `kDebugMode && bool.fromEnvironment(...)`), so
/// a release build strips the dev fake and the branch that registers it.
///
/// [platform] is the typed [TargetPlatform], not its name (Q-7): the name of
/// `TargetPlatform.iOS` is `'iOS'`, and a hand-typed `'ios'` never matched it,
/// so iOS debug builds captioned with the dev fake and iOS release builds
/// registered nothing. Web has no [TargetPlatform] of its own, so [isWeb]
/// guards it.
///
/// The rules (BR-U10-01 to 07a, and Amendment 03 section 3 for the engine
/// choice):
///
/// - a platform engine is registered only on iOS and Android, and only when
///   the app is not web; desktop and web have no engine in this unit;
/// - Android registers the silent segmented engine, iOS registers
///   `PlatformSttEngine`; both answer to `engineId == 'platform'`, so
///   nothing downstream changes;
/// - the dev fake is registered only when [allowDevEngines] and either
///   [forceFake] is set or the platform engine is not used (desktop, web);
/// - with [forceFake] the fake is the only engine, so a developer can drive
///   deterministic captions on a phone;
/// - with [allowDevEngines] `false` the fake is never registered at all.
///
/// The two create closures exist so that a build which never registers an
/// engine never constructs it: desktop, web and the non-native mobile
/// platform must not reach a speech API at all, and Android must not reach
/// `speech_to_text` (Amendment 03 section 2).
void registerSttEngines(
  SttEngineRegistry registry, {
  required TargetPlatform platform,
  required bool isWeb,
  required bool allowDevEngines,
  required bool forceFake,
  required SttEngine Function() createPlatformEngine,
  required SttEngine Function() createSegmentedEngine,
}) {
  final usesPlatformEngine = !isWeb && _mobilePlatforms.contains(platform);

  // Forced fake: the developer asked for deterministic captions, so the real
  // engine is not registered even where it is available.
  if (allowDevEngines && forceFake) {
    registry.register(FakeSttEngine());
    return;
  }

  if (usesPlatformEngine) {
    registry.register(
      platform == TargetPlatform.android
          ? createSegmentedEngine()
          : createPlatformEngine(),
    );
  }

  // The fake fills the gap off mobile, where there is no platform engine in
  // this unit, so the app still has something to caption with in debug.
  if (allowDevEngines && !usesPlatformEngine) {
    registry.register(FakeSttEngine());
  }
}

/// The platforms that have a platform STT engine in Unit 10.
const Set<TargetPlatform> _mobilePlatforms = {
  TargetPlatform.iOS,
  TargetPlatform.android,
};
