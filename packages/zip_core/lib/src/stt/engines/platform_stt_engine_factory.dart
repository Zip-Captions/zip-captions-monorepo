import 'package:speech_to_text/speech_to_text.dart';
import 'package:zip_core/src/services/audio/audio_device_service.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine.dart';
import 'package:zip_core/src/stt/on_device_support_checker.dart';

/// Builds the production [PlatformSttEngine] with its own [SpeechToText].
///
/// An app calls this instead of constructing the engine itself, so the
/// `speech_to_text` plugin stays declared in exactly one package
/// (`zip_core`), the one whose code classes and status behaviour the engine
/// is written against (Unit 10, SECURITY-10).
///
/// Constructing the plugin object makes no platform call, and nothing here
/// calls [onDeviceSupportChecker]: it is first called by the engine just
/// before a `listen()`. The engine's own constructor still takes a
/// [SpeechToText] so tests can inject a fake.
PlatformSttEngine createPlatformSttEngine({
  required OnDeviceSupportChecker onDeviceSupportChecker,
  required AudioDeviceService deviceService,
}) =>
    PlatformSttEngine(
      stt: SpeechToText(),
      deviceService: deviceService,
      onDeviceSupportChecker: onDeviceSupportChecker,
    );
