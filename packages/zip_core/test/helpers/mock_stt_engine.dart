import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/stt/stt_engine.dart';

/// Mock STT engine for testing.
///
/// All async methods delay by [asyncDelay] (default 100ms, Q2=C).
/// Use [emitResult] to synchronously trigger the onResult callback.
class MockSttEngine implements SttEngine {
  MockSttEngine({
    this.engineId = 'mock',
    this.displayName = 'Mock Engine',
    this.requiresNetwork = false,
    this.requiresDownload = false,
    this.mockLocales = const [],
    this.mockIsAvailable = true,
    this.asyncDelay = const Duration(milliseconds: 100),
  });

  @override
  final String engineId;
  @override
  final String displayName;
  @override
  final bool requiresNetwork;
  @override
  final bool requiresDownload;

  final List<SpeechLocale> mockLocales;
  final bool mockIsAvailable;
  final Duration asyncDelay;

  bool _initialized = false;
  bool _listening = false;
  void Function(SttResult)? _onResult;
  String? _activeLocaleId;

  /// Whether [initialize] has been called successfully.
  bool get isInitialized => _initialized;

  /// Whether the engine is currently listening.
  bool get isListening => _listening;

  /// The locale ID passed to the most recent [startListening] call.
  String? get activeLocaleId => _activeLocaleId;

  @override
  Future<bool> initialize() async {
    await Future<void>.delayed(asyncDelay);
    _initialized = true;
    return true;
  }

  @override
  Future<bool> isAvailable() async {
    await Future<void>.delayed(asyncDelay);
    return mockIsAvailable;
  }

  @override
  Future<List<SpeechLocale>> supportedLocales() async {
    await Future<void>.delayed(asyncDelay);
    return mockLocales;
  }

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    await Future<void>.delayed(asyncDelay);
    _activeLocaleId = localeId;
    _onResult = onResult;
    _listening = true;
    return true;
  }

  @override
  Future<void> stopListening() async {
    await Future<void>.delayed(asyncDelay);
    _listening = false;
    _onResult = null;
  }

  @override
  Future<bool> pause() async {
    await Future<void>.delayed(asyncDelay);
    _listening = false;
    return true;
  }

  @override
  Future<bool> resume() async {
    await Future<void>.delayed(asyncDelay);
    _listening = true;
    return true;
  }

  @override
  void dispose() {
    _listening = false;
    _onResult = null;
  }

  /// Synchronously emit an STT result through the onResult callback.
  void emitResult(SttResult result) {
    _onResult?.call(result);
  }
}
