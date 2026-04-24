import 'package:zip_core/zip_core.dart';

/// Controllable [SttEngine] for unit tests.
///
/// Each instance tracks call counts and can be configured to fail
/// initialisation, enabling partial-failure scenarios in
/// [BroadcastRecordingNotifier] tests (TEST-U6.2, PBT-1).
class MockSttEngine implements SttEngine {
  /// Whether [initialize] should return `false`.
  bool shouldFailInit = false;

  /// Whether [startListening] should return `false`.
  bool shouldFailStart = false;

  int initCount = 0;
  int startCount = 0;
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;

  void Function(SttResult)? _onResult;

  @override
  String get engineId => 'mock';

  @override
  String get displayName => 'Mock';

  @override
  bool get requiresNetwork => false;

  @override
  bool get requiresDownload => false;

  @override
  bool get requiresMicrophone => false;

  @override
  Future<bool> initialize() async {
    initCount++;
    return !shouldFailInit;
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<SpeechLocale>> supportedLocales() async => const [
        SpeechLocale(localeId: 'en-US', displayName: 'English (US)'),
      ];

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    startCount++;
    if (shouldFailStart) return false;
    _onResult = onResult;
    return true;
  }

  @override
  Future<void> stopListening() async => stopCount++;

  @override
  Future<bool> pause() async {
    pauseCount++;
    return true;
  }

  @override
  Future<bool> resume() async {
    resumeCount++;
    return true;
  }

  @override
  void dispose() {}

  /// Push a fake [SttResult] through the registered callback.
  void emit(SttResult result) => _onResult?.call(result);
}
