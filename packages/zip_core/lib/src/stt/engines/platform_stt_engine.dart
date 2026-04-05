import 'dart:async';

import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/audio/audio_device_service.dart';
import 'package:zip_core/src/stt/stt_engine.dart';

/// Wraps [SpeechToText] for Tier 1 platforms (iOS, macOS, Android, Windows).
///
/// Implements [SttEngine]. Accepts [SpeechToText] and [AudioDeviceService]
/// via constructor injection for testability (TEST-U2.1).
///
/// **Security (SECURITY-03)**: Never logs transcript text from results.
class PlatformSttEngine implements SttEngine {
  /// Creates a [PlatformSttEngine].
  PlatformSttEngine({
    required SpeechToText stt,
    required AudioDeviceService deviceService,
  })  : _stt = stt,
        _deviceService = deviceService;

  static final _log = Logger('zip_core.PlatformSttEngine');

  final SpeechToText _stt;
  final AudioDeviceService _deviceService;

  String? _activeLocaleId;
  void Function(SttResult)? _onResult;
  bool _paused = false;

  @override
  String get engineId => 'platform';

  @override
  String get displayName => 'Platform Speech Recognition';

  @override
  bool get requiresNetwork => false;

  @override
  bool get requiresDownload => false;

  @override
  Future<bool> initialize() async {
    try {
      final available = await _stt.initialize();
      _log.info('Platform STT initialized: $available');
      return available;
    } on Exception catch (e) {
      _log.severe('Initialize error: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return _stt.isAvailable;
    } on Exception {
      return false;
    }
  }

  @override
  Future<List<SpeechLocale>> supportedLocales() async {
    try {
      final locales = await _stt.locales();
      return locales
          .map(
            (l) => SpeechLocale(
              localeId: l.localeId,
              displayName: l.name,
            ),
          )
          .toList();
    } on Exception catch (e) {
      _log.warning('supportedLocales error: ${e.runtimeType}');
      return [];
    }
  }

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    _activeLocaleId = localeId;
    _onResult = onResult;
    _paused = false;

    // Set preferred device before listening (BR-U2-16).
    final preferredDevice = _deviceService.currentPreferredDeviceId;
    if (preferredDevice != null) {
      await _deviceService.setPreferredInputDevice(preferredDevice);
    }

    try {
      await _stt.listen(
        localeId: localeId,
        onResult: (result) {
          _onResult?.call(
            SttResult(
              text: result.recognizedWords,
              isFinal: result.finalResult,
              confidence: result.confidence,
              timestamp: DateTime.now(),
              sourceId: engineId,
            ),
          );
        },
      );
      _log.info('Listening started for locale $localeId');
      return true;
    } on Exception catch (e) {
      _log.severe('startListening error: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _stt.stop();
      await _stt.cancel();
      _log.info('Listening stopped');
    } on Exception catch (e) {
      _log.warning('stopListening error: ${e.runtimeType}');
    }
  }

  @override
  Future<bool> pause() async {
    // speech_to_text has no native pause — stop and record paused state.
    try {
      await _stt.stop();
      _paused = true;
      _log.info('Paused (via stop)');
      return true;
    } on Exception catch (e) {
      _log.warning('Pause error: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> resume() async {
    if (!_paused ||
        _activeLocaleId == null ||
        _onResult == null) {
      return false;
    }
    _paused = false;
    // Transparent restart with same locale and callback.
    return startListening(
      localeId: _activeLocaleId!,
      onResult: _onResult!,
    );
  }

  @override
  void dispose() {
    unawaited(_stt.cancel());
    _onResult = null;
  }
}
