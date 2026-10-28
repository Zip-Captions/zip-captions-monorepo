import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/models/recording_error.dart';

/// Named factory constructors for common [RecordingError] instances.
///
/// These provide consistent error messages and severities across the app.
/// The UI can distinguish error types by message content.
extension RecordingErrorFactories on RecordingError {
  /// Microphone permission was denied but can be re-requested.
  static RecordingError permissionDenied() => RecordingError(
        message: 'Microphone access denied.',
        severity: RecordingErrorSeverity.fatal,
        timestamp: DateTime.now(),
      );

  /// Microphone permission is permanently denied; user must open Settings.
  static RecordingError permissionPermanentlyDenied() => RecordingError(
        message:
            'Microphone access is blocked. Enable it in system Settings.',
        severity: RecordingErrorSeverity.fatal,
        timestamp: DateTime.now(),
      );

  /// The STT engine failed to initialize.
  static RecordingError engineInitFailed() => RecordingError(
        message: 'Speech recognition engine failed to initialize.',
        severity: RecordingErrorSeverity.fatal,
        timestamp: DateTime.now(),
      );

  /// The STT engine failed to start listening.
  static RecordingError engineStartFailed() => RecordingError(
        message: 'Speech recognition engine failed to start.',
        severity: RecordingErrorSeverity.fatal,
        timestamp: DateTime.now(),
      );

  /// The selected engine requires a model download before use.
  static RecordingError engineRequiresModelDownload() => RecordingError(
        message: 'A speech model must be downloaded before use.',
        severity: RecordingErrorSeverity.fatal,
        timestamp: DateTime.now(),
      );

  /// On-device speech recognition is not available, so captioning did not
  /// start (Unit 10, Amendment 02).
  ///
  /// A separate message is needed because [engineRequiresModelDownload] says a
  /// model "must be downloaded", which is wrong for a device or locale with
  /// no on-device support at all (nothing to download), and
  /// [engineInitFailed] and [engineStartFailed] say nothing about why. The
  /// text makes no claim about where audio went.
  static RecordingError onDeviceRecognitionUnavailable() => RecordingError(
        message: 'On-device speech recognition is not available.',
        severity: RecordingErrorSeverity.fatal,
        timestamp: DateTime.now(),
      );

  /// The requested locale is not supported by the active engine.
  static RecordingError localeNotSupported(String localeId) =>
      RecordingError(
        message: 'Locale $localeId is not supported by the active engine.',
        severity: RecordingErrorSeverity.fatal,
        timestamp: DateTime.now(),
      );
}
