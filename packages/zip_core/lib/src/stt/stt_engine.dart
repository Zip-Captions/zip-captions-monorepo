import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';

/// Abstract interface for speech-to-text engines.
///
/// Phase 1 defines the full contract with metadata properties and a
/// unified [SttResult] callback. Concrete implementations are in Unit 2
/// (`PlatformSttEngine`, `SherpaOnnxSttEngine`).
///
/// **Security constraint (SECURITY-03)**: The `onResult` callback in
/// `startListening` delivers transcript text. Implementations and all code
/// handling this callback must never log, emit, or surface transcript text
/// content. Only state transitions and error messages may appear in logs.
abstract interface class SttEngine {
  /// Unique engine identifier (e.g., 'platform', 'sherpa-onnx').
  String get engineId;

  /// Human-readable engine name for UI display.
  String get displayName;

  /// Whether the engine requires internet connectivity.
  bool get requiresNetwork;

  /// Whether the engine requires a model download before use.
  bool get requiresDownload;

  /// Request permissions and prepare the engine.
  Future<bool> initialize();

  /// Check if the engine can run on the current device/platform.
  Future<bool> isAvailable();

  /// Locales this engine supports.
  Future<List<SpeechLocale>> supportedLocales();

  /// Begin an STT session.
  ///
  /// [localeId] specifies the recognition locale (BCP-47).
  /// [onResult] receives all recognition results (interim and final).
  ///
  /// **Security (SECURITY-03)**: [onResult] delivers transcript content
  /// that must never be logged.
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  });

  /// End the current STT session.
  Future<void> stopListening();

  /// Pause recognition (transparent stop/restart if not natively supported).
  Future<bool> pause();

  /// Resume recognition.
  Future<bool> resume();

  /// Release all resources.
  void dispose();
}
