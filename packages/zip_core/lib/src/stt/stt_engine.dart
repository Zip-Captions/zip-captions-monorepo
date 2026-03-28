import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/speech_locale.dart';

/// Abstract interface for speech-to-text engines.
///
/// Phase 0 defines the contract only; no concrete implementation.
///
/// **Security constraint**: Callbacks in [startListening] receive transcript
/// text. The `SttEngine` implementation and all code handling these callbacks
/// must never log, emit, or surface transcript text content. Only state
/// transitions and error messages may appear in logs.
abstract interface class SttEngine {
  /// Request permissions and prepare the engine.
  Future<bool> initialize();

  /// Check if the engine can run on the current device/platform.
  Future<bool> isAvailable();

  /// Begin an STT session with callbacks for results and errors.
  ///
  /// [localeId] optionally specifies the recognition locale. If null, the
  /// engine uses its default locale.
  ///
  /// [onInterimResult] receives partial recognition text as it becomes
  /// available. [onFinalResult] receives finalized recognition text for a
  /// completed utterance. [onError] receives errors with severity to
  /// determine state machine impact.
  ///
  /// **Security**: [onInterimResult] and [onFinalResult] deliver transcript
  /// content that must never be logged.
  Future<bool> startListening({
    required void Function(String text) onInterimResult,
    required void Function(String text) onFinalResult,
    required void Function(RecordingError error) onError,
    String? localeId,
  });

  /// End the current STT session.
  Future<void> stopListening();

  /// Pause recognition.
  Future<bool> pause();

  /// Resume recognition.
  Future<bool> resume();

  /// List supported STT locales.
  Future<List<SpeechLocale>> getAvailableLocales();

  /// Release resources.
  void dispose();
}
