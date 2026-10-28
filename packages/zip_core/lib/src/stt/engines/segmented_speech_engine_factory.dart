import 'package:zip_core/src/stt/engines/segmented_recognizer_bridge.dart';
import 'package:zip_core/src/stt/engines/segmented_speech_engine.dart';
import 'package:zip_core/src/stt/on_device_support_checker.dart';

/// Builds the production [SegmentedSpeechEngine] around [bridge].
///
/// The app supplies the bridge (the Android method and event channels), so
/// the engine keeps no platform code and `zip_core` stays free of the
/// runner. Nothing here calls [onDeviceSupportChecker] or the bridge: the
/// engine calls the checker just before every start, and the bridge only when
/// a session starts, so construction makes no platform call.
///
/// The factory exists (rather than an app constructing the engine itself) so
/// that registration, the limits and the check identity live in one place, as
/// they do for `createPlatformSttEngine`.
SegmentedSpeechEngine createSegmentedSpeechEngine({
  required SegmentedRecognizerBridge bridge,
  required OnDeviceSupportChecker onDeviceSupportChecker,
}) =>
    SegmentedSpeechEngine(
      bridge: bridge,
      onDeviceSupportChecker: onDeviceSupportChecker,
    );
