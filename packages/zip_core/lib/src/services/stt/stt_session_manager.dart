import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';
import 'package:zip_core/src/stt/stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

/// Owns the full STT engine lifecycle for a single captioning session.
///
/// Delegates to [SttEngineRegistry] for engine resolution and handles
/// microphone permission checks, engine initialization, and the
/// one-attempt auto-restart recovery flow (REL-U2.1).
///
/// **Security (SECURITY-03)**: Never logs transcript text.
class SttSessionManager {
  /// Creates a [SttSessionManager].
  SttSessionManager({
    required SttEngineRegistry registry,
  }) : _registry = registry;

  static final _log = Logger('zip_core.SttSessionManager');

  final SttEngineRegistry _registry;
  SttEngine? _engine;
  String? _activeEngineId;

  /// Bumped by every [stop]; lets an in-flight [handleEngineError] notice it.
  int _stopGeneration = 0;
  String? _activeLocaleId;
  void Function(SttResult)? _onResult;
  void Function(RecordingError)? _onError;

  /// The currently active engine, if any.
  SttEngine? get activeEngine => _engine;

  /// Resolves the engine, checks microphone permission, and initializes.
  ///
  /// Returns `true` if the engine is ready for [startListening].
  /// On failure, calls [onError] with the appropriate error and returns
  /// `false`.
  Future<bool> initialize({
    required String engineId,
    required String localeId,
    required void Function(SttResult) onResult,
    required void Function(RecordingError) onError,
  }) async {
    _activeEngineId = engineId;
    _activeLocaleId = localeId;
    _onResult = onResult;
    _onError = onError;

    // Resolve engine from registry.
    _engine = _registry.getEngine(engineId);
    if (_engine == null) {
      _log.severe('Engine not found: $engineId');
      onError(RecordingErrorFactories.engineInitFailed());
      return false;
    }

    // Check microphone permission (Q6=A). Skipped for engines that do not
    // use the microphone (e.g. synthetic/fake engines).
    if (_engine!.requiresMicrophone) {
      final permissionOk = await _checkPermission(onError);
      if (!permissionOk) return false;
    }

    // Initialize engine.
    try {
      final ok = await _engine!.initialize();
      if (!ok) {
        _log.warning('Engine $engineId failed to initialize');
        onError(RecordingErrorFactories.engineInitFailed());
        return false;
      }
    } on Exception catch (e) {
      _log.severe('Engine $engineId initialization error: ${e.runtimeType}');
      onError(RecordingErrorFactories.engineInitFailed());
      return false;
    }

    // An engine that can report lasting errors after listening has started
    // (BR-U10-22): forward each one once through the same `onError` path as
    // every other engine error. Registered only once the engine is ready, so
    // a failed initialize leaves no stale listener behind.
    if (_engine case final SttErrorSource source) {
      source.setErrorListener(_forwardEngineError);
    }

    _log.info('Engine $engineId initialized for locale $localeId');
    return true;
  }

  /// Maps an engine's lasting error to an existing [RecordingError] factory
  /// and reports it once (Amendment 02, section 5). Only the kind is logged.
  void _forwardEngineError(SttEngineError error) {
    _log.warning('Engine error reported: ${error.kind.name}');
    final mapped = switch (error.kind) {
      SttEngineErrorKind.recognizerUnavailable =>
        RecordingErrorFactories.engineInitFailed(),
      SttEngineErrorKind.onDeviceModelMissing =>
        RecordingErrorFactories.onDeviceRecognitionUnavailable(),
      SttEngineErrorKind.localeUnsupported =>
        RecordingErrorFactories.localeNotSupported(_activeLocaleId ?? ''),
      SttEngineErrorKind.permissionRevoked =>
        RecordingErrorFactories.permissionDenied(),
      SttEngineErrorKind.restartCapReached =>
        RecordingErrorFactories.engineStartFailed(),
    };
    _onError?.call(mapped);
  }

  /// Begins listening on the initialized engine.
  Future<bool> startListening() async {
    if (_engine == null || _activeLocaleId == null || _onResult == null) {
      return false;
    }

    try {
      final ok = await _engine!.startListening(
        localeId: _activeLocaleId!,
        onResult: _onResult!,
      );
      if (!ok) {
        _log.warning('Engine $_activeEngineId failed to start listening');
        _onError?.call(RecordingErrorFactories.engineStartFailed());
        return false;
      }
      _log.info('Engine $_activeEngineId listening');
      return true;
    } on Exception catch (e) {
      _log.severe(
        'Engine $_activeEngineId startListening error: ${e.runtimeType}',
      );
      _onError?.call(RecordingErrorFactories.engineStartFailed());
      return false;
    }
  }

  /// Pauses the active engine.
  Future<bool> pause() async {
    if (_engine == null) return false;
    try {
      return await _engine!.pause();
    } on Exception catch (e) {
      _log.warning('Pause error: ${e.runtimeType}');
      return false;
    }
  }

  /// Resumes the active engine.
  Future<bool> resume() async {
    if (_engine == null) return false;
    try {
      return await _engine!.resume();
    } on Exception catch (e) {
      _log.warning('Resume error: ${e.runtimeType}');
      return false;
    }
  }

  /// Stops the active engine.
  ///
  /// Also tells an in-flight [handleEngineError] recovery that a stop was
  /// requested, so it will not start listening again afterwards (Unit 10,
  /// TP-2c: Stop must win against the REL-U2.1 recovery).
  Future<void> stop() async {
    _stopGeneration++;
    if (_engine == null) return;
    try {
      await _engine!.stopListening();
      _log.info('Engine $_activeEngineId stopped');
    } on Exception catch (e) {
      _log.warning('Stop error: ${e.runtimeType}');
    }
  }

  /// Attempts one automatic restart after an engine error (REL-U2.1).
  ///
  /// Returns `true` if recovery succeeded and the engine is listening again.
  Future<bool> handleEngineError(Object error) async {
    _log.warning(
      'Engine error (${error.runtimeType}), attempting restart',
    );

    // A user stop that arrives during this recovery bumps the generation; the
    // recovery then gives up before it can start the engine listening again.
    final generation = _stopGeneration;
    try {
      await _engine?.stopListening();
      if (generation != _stopGeneration) return false;
      final initOk = await _engine!.initialize();
      if (!initOk || generation != _stopGeneration) return false;
      return await _engine!.startListening(
        localeId: _activeLocaleId!,
        onResult: _onResult!,
      );
    } on Exception catch (e) {
      _log.severe('Restart failed: ${e.runtimeType}');
      return false;
    }
  }

  /// Releases all engine resources.
  void dispose() {
    if (_engine case final SttErrorSource source) {
      source.setErrorListener(null);
    }
    _engine?.dispose();
    _engine = null;
    _onResult = null;
    _onError = null;
  }

  // --- Private helpers ---

  Future<bool> _checkPermission(
    void Function(RecordingError) onError,
  ) async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      _log.info('Microphone permission permanently denied');
      onError(RecordingErrorFactories.permissionPermanentlyDenied());
      return false;
    }

    // Request permission (covers undetermined and denied).
    status = await Permission.microphone.request();

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      _log.info('Microphone permission permanently denied after request');
      onError(RecordingErrorFactories.permissionPermanentlyDenied());
      return false;
    }

    _log.info('Microphone permission denied');
    onError(RecordingErrorFactories.permissionDenied());
    return false;
  }
}
