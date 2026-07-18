import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/zip_core.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Minimal controllable [SttEngine] — no async delay, no permission required.
class _MockSttEngine implements SttEngine {
  void Function(SttResult)? _onResult;

  bool isListening = false;

  @override
  String get engineId => 'mock';
  @override
  String get displayName => 'Mock';
  @override
  bool get requiresNetwork => false;
  @override
  bool get requiresDownload => false;
  // false → SttSessionManager skips microphone permission check.
  @override
  bool get requiresMicrophone => false;

  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<SpeechLocale>> supportedLocales() async => const [];

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    _onResult = onResult;
    isListening = true;
    return true;
  }

  @override
  Future<void> stopListening() async {
    isListening = false;
    _onResult = null;
  }

  @override
  Future<bool> pause() async {
    isListening = false;
    return true;
  }

  @override
  Future<bool> resume() async {
    isListening = true;
    return true;
  }

  @override
  void dispose() {
    _onResult = null;
    isListening = false;
  }

  void emit(SttResult result) => _onResult?.call(result);
}

/// [CaptionBus] that records all published events for assertion.
class _RecordingCaptionBus extends CaptionBus {
  final List<CaptionEvent> published = [];

  @override
  void publish(CaptionEvent event) {
    published.add(event);
    super.publish(event);
  }
}

/// No-op [WakeLockService].
class _FakeWakeLockService implements WakeLockService {
  @override
  WakeLockSettings get settings => const WakeLockSettings();
  @override
  void updateSettings(WakeLockSettings settings) {}
  @override
  Future<void> acquire() async {}
  @override
  Future<void> release() async {}
  @override
  Future<void> onPause() async {}
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _buildContainer(
  _MockSttEngine engine,
  _RecordingCaptionBus bus,
  SharedPreferences prefs,
) {
  final registry = SttEngineRegistry()..register(engine);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      captionBusProvider.overrideWithValue(bus),
      wakeLockServiceProvider.overrideWithValue(_FakeWakeLockService()),
      resolvedLocaleIdProvider.overrideWithValue('en-US'),
      sttEngineRegistryProvider.overrideWithValue(registry),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests — INT-ZC-01: full recording pipeline
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('INT-ZC-01: RecordingStateNotifier full pipeline', () {
    test('start → RecordingActiveState + SessionStateEvent(recording) on bus',
        () async {
      final engine = _MockSttEngine();
      final bus = _RecordingCaptionBus();
      final container = _buildContainer(engine, bus, prefs);

      await container.read(recordingStateNotifierProvider.notifier).start();

      expect(
        container.read(recordingStateNotifierProvider),
        isA<RecordingActiveState>(),
      );

      final stateEvents = bus.published.whereType<SessionStateEvent>().toList();
      expect(stateEvents, isNotEmpty);
      expect(stateEvents.last.state, isA<RecordingActiveState>());
      expect(engine.isListening, isTrue);
    });

    test('emit final SttResult → SttResultEvent on bus', () async {
      final engine = _MockSttEngine();
      final bus = _RecordingCaptionBus();
      final container = _buildContainer(engine, bus, prefs);

      await container.read(recordingStateNotifierProvider.notifier).start();

      engine.emit(SttResult(text: 'hello world', isFinal: true, confidence: 1.0, timestamp: DateTime(2026), sourceId: 'default'));
      await pumpEventQueue();

      final resultEvents = bus.published.whereType<SttResultEvent>().toList();
      expect(resultEvents, hasLength(1));
      expect(resultEvents.first.result.text, equals('hello world'));
      expect(resultEvents.first.result.isFinal, isTrue);
    });

    test('emit partial SttResult → SttResultEvent on bus + state carries segment',
        () async {
      final engine = _MockSttEngine();
      final bus = _RecordingCaptionBus();
      final container = _buildContainer(engine, bus, prefs);

      await container.read(recordingStateNotifierProvider.notifier).start();

      engine.emit(SttResult(text: 'hel', isFinal: false, confidence: 0.8, timestamp: DateTime(2026), sourceId: 'default'));
      await pumpEventQueue();

      final state = container.read(recordingStateNotifierProvider);
      expect(state, isA<RecordingActiveState>());
      expect((state as RecordingActiveState).currentSegment, equals('hel'));
    });

    test('pause → PausedState + SessionStateEvent(paused) on bus', () async {
      final engine = _MockSttEngine();
      final bus = _RecordingCaptionBus();
      final container = _buildContainer(engine, bus, prefs);

      final notifier = container.read(recordingStateNotifierProvider.notifier);
      await notifier.start();
      await notifier.pause();

      expect(
        container.read(recordingStateNotifierProvider),
        isA<PausedState>(),
      );

      final stateEvents = bus.published.whereType<SessionStateEvent>().toList();
      expect(stateEvents.last.state, isA<PausedState>());
      expect(engine.isListening, isFalse);
    });

    test('resume → RecordingActiveState + SessionStateEvent(recording) on bus',
        () async {
      final engine = _MockSttEngine();
      final bus = _RecordingCaptionBus();
      final container = _buildContainer(engine, bus, prefs);

      final notifier = container.read(recordingStateNotifierProvider.notifier);
      await notifier.start();
      await notifier.pause();
      await notifier.resume();

      expect(
        container.read(recordingStateNotifierProvider),
        isA<RecordingActiveState>(),
      );

      final stateEvents = bus.published.whereType<SessionStateEvent>().toList();
      expect(stateEvents.last.state, isA<RecordingActiveState>());
      expect(engine.isListening, isTrue);
    });

    test('stop → StoppedState + SessionStateEvent(stopped) on bus', () async {
      final engine = _MockSttEngine();
      final bus = _RecordingCaptionBus();
      final container = _buildContainer(engine, bus, prefs);

      final notifier = container.read(recordingStateNotifierProvider.notifier);
      await notifier.start();
      await notifier.stop();

      expect(
        container.read(recordingStateNotifierProvider),
        isA<StoppedState>(),
      );

      final stateEvents = bus.published.whereType<SessionStateEvent>().toList();
      expect(stateEvents.last.state, isA<StoppedState>());
      expect(engine.isListening, isFalse);
    });

    test('full lifecycle: start → emit → pause → resume → emit → stop',
        () async {
      final engine = _MockSttEngine();
      final bus = _RecordingCaptionBus();
      final container = _buildContainer(engine, bus, prefs);

      final notifier = container.read(recordingStateNotifierProvider.notifier);

      await notifier.start();
      engine.emit(SttResult(text: 'before pause', isFinal: true, confidence: 1.0, timestamp: DateTime(2026), sourceId: 'default'));
      await pumpEventQueue();

      await notifier.pause();

      // Events while paused must not appear on the bus.
      engine.emit(SttResult(text: 'during pause', isFinal: true, confidence: 1.0, timestamp: DateTime(2026), sourceId: 'default'));
      await pumpEventQueue();

      await notifier.resume();
      engine.emit(SttResult(text: 'after resume', isFinal: true, confidence: 1.0, timestamp: DateTime(2026), sourceId: 'default'));
      await pumpEventQueue();

      await notifier.stop();

      final results = bus.published
          .whereType<SttResultEvent>()
          .map((e) => e.result.text)
          .toList();

      expect(results, contains('before pause'));
      expect(results, isNot(contains('during pause')));
      expect(results, contains('after resume'));

      final stateEvents = bus.published
          .whereType<SessionStateEvent>()
          .map((e) => e.state)
          .toList();
      expect(stateEvents.last, isA<StoppedState>());
    });
  });
}
