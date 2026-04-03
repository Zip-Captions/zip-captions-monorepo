# NFR Design Patterns — Unit 2: Platform STT + Audio

## 1. Engine Crash Recovery + Reconnecting State Pattern (REL-U2.1, USA-U2.2)

### RecordingState.reconnecting Variant (Q2=B)

A new `reconnecting` variant is added to the `RecordingState` union type. The state machine transitions through it during the one-attempt auto-restart.

```dart
@freezed
class RecordingState with _$RecordingState {
  const factory RecordingState.idle() = IdleState;
  const factory RecordingState.recording({required String sessionId}) = RecordingRecordingState;
  const factory RecordingState.paused({required String sessionId}) = PausedState;
  const factory RecordingState.reconnecting({required String sessionId}) = ReconnectingState;
  const factory RecordingState.stopped({required String sessionId}) = StoppedState;
}
```

### State Machine Transitions

```
recording ──(engine error)──> reconnecting ──(restart success)──> recording
                                            ──(restart failure)──> stopped
```

The `sessionId` is **preserved** across the reconnecting transition — it is the same session.

### Implementation in SttSessionManager

```dart
class SttSessionManager {
  final SttEngineRegistry _registry;
  SttEngine? _engine;
  String? _activeEngineId;
  String? _activeLocaleId;
  void Function(SttResult)? _onResult;
  void Function(RecordingError)? _onError;

  Future<bool> handleEngineError(Object error) async {
    // Called by the engine's error handler (e.g., onError stream)
    // Attempt one restart with the same configuration
    try {
      await _engine?.stopListening();
      final ok = await _engine!.initialize();
      if (!ok) return false;
      return await _engine!.startListening(
        localeId: _activeLocaleId!,
        onResult: _onResult!,
      );
    } catch (_) {
      return false;
    }
  }
}
```

### Implementation in RecordingStateNotifier

```dart
// Inside the onError callback passed to SttSessionManager.initialize():
void _handleEngineError(RecordingError error) {
  final currentState = state;
  if (currentState is! RecordingRecordingState) return;

  final sessionId = currentState.sessionId;
  state = RecordingState.reconnecting(sessionId: sessionId);

  _sessionManager.handleEngineError(error).then((recovered) {
    if (recovered) {
      state = RecordingState.recording(sessionId: sessionId);
    } else {
      _lastError = RecordingErrorFactories.engineStartFailed();
      state = RecordingState.stopped(sessionId: sessionId);
      _wakeLockService.release();
    }
  });
}
```

### Key Design Decisions

- **One attempt only**: No retry loop. If `handleEngineError` returns `false`, the session is over.
- **Session continuity**: The `sessionId` does not change. From the caption bus perspective, this is the same session with a brief interruption.
- **Wake lock**: Held during `reconnecting` — the screen stays on. Released only on transition to `stopped`.
- **CaptionBus**: No `SessionStateEvent` is emitted for `reconnecting`. The bus continues to hold the session open. A `SessionStateEvent(stopped)` is only emitted if recovery fails.

---

## 2. OnlineRecognizerAdapter Pattern (TEST-U2.2, Q1=A)

### Minimal Adapter Interface

A thin abstract class that mirrors only the `OnlineRecognizer` methods used by `SherpaOnnxSttEngine`. The production implementation delegates to the real native class.

```dart
/// Test seam for sherpa_onnx OnlineRecognizer.
/// Production: SherpaOnlineRecognizerAdapter (delegates to native OnlineRecognizer).
/// Test: MockOnlineRecognizerAdapter (mocktail).
abstract class OnlineRecognizerAdapter {
  /// Creates a new recognition stream.
  OnlineStream createStream();

  /// Feeds PCM16 audio samples to the stream.
  void acceptWaveform(OnlineStream stream, {required int sampleRate, required Float32List samples});

  /// Returns true if enough audio has been buffered to run a decode step.
  bool isReady(OnlineStream stream);

  /// Runs one decode step on the stream.
  void decode(OnlineStream stream);

  /// Returns the current partial/final result text.
  String getResult(OnlineStream stream);

  /// Resets the stream state for the next utterance.
  void reset(OnlineStream stream);

  /// Frees native resources.
  void dispose();
}
```

### Production Implementation

```dart
class SherpaOnlineRecognizerAdapter implements OnlineRecognizerAdapter {
  SherpaOnlineRecognizerAdapter(this._recognizer);
  final OnlineRecognizer _recognizer;

  @override
  OnlineStream createStream() => _recognizer.createStream();

  @override
  void acceptWaveform(OnlineStream stream, {required int sampleRate, required Float32List samples}) =>
      _recognizer.acceptWaveform(stream, sampleRate: sampleRate, samples: samples);

  @override
  bool isReady(OnlineStream stream) => _recognizer.isReady(stream);

  @override
  void decode(OnlineStream stream) => _recognizer.decode(stream);

  @override
  String getResult(OnlineStream stream) => _recognizer.getResult(stream);

  @override
  void reset(OnlineStream stream) => _recognizer.reset(stream);

  @override
  void dispose() => _recognizer.free();
}
```

### SherpaOnnxSttEngine Constructor

```dart
class SherpaOnnxSttEngine implements SttEngine {
  SherpaOnnxSttEngine({
    required SherpaModelManager modelManager,
    required AudioDeviceService deviceService,
    OnlineRecognizerAdapter? recognizerAdapter, // null until initialize()
  });
}
```

The adapter is `null` at construction and created during `initialize()` when the model is loaded. Tests inject a pre-built `MockOnlineRecognizerAdapter`.

### OnlineStream Handling

`OnlineStream` is also a native class. Since `SherpaOnnxSttEngine` only passes it opaquely between adapter methods, the mock can return a stub `OnlineStream`. If `OnlineStream` cannot be instantiated in tests, introduce a second thin wrapper or use `any()` matchers.

### Coverage Exclusion

Per TEST-U2.6, `SherpaOnlineRecognizerAdapter` is excluded from coverage measurement — it is a pure pass-through with no logic. It is validated only by integration tests on real devices.

**Location**: `packages/zip_core/lib/src/stt/adapters/online_recognizer_adapter.dart`

---

## 3. PlatformSttEngine Mock Strategy (TEST-U2.1, Q1=A)

### SpeechToText Injection

`PlatformSttEngine` accepts a `SpeechToText` instance via constructor injection. Tests use mocktail to mock it.

```dart
class PlatformSttEngine implements SttEngine {
  PlatformSttEngine({
    required SpeechToText stt,
    required AudioDeviceService deviceService,
  }) : _stt = stt, _deviceService = deviceService;

  final SpeechToText _stt;
  final AudioDeviceService _deviceService;
}
```

### Mock Setup Pattern

```dart
class MockSpeechToText extends Mock implements SpeechToText {}
class MockAudioDeviceService extends Mock implements AudioDeviceService {}

void main() {
  late MockSpeechToText mockStt;
  late MockAudioDeviceService mockDeviceService;
  late PlatformSttEngine engine;

  setUp(() {
    mockStt = MockSpeechToText();
    mockDeviceService = MockAudioDeviceService();
    engine = PlatformSttEngine(stt: mockStt, deviceService: mockDeviceService);
  });

  test('initialize() returns true when stt.initialize() succeeds', () async {
    when(() => mockStt.initialize()).thenAnswer((_) async => true);
    expect(await engine.initialize(), isTrue);
    verify(() => mockStt.initialize()).called(1);
  });

  test('startListening() sets preferred device before listening', () async {
    when(() => mockDeviceService.currentPreferredDeviceId).thenReturn('usb-mic');
    when(() => mockDeviceService.setPreferredInputDevice('usb-mic'))
        .thenAnswer((_) async {});
    when(() => mockStt.listen(
      localeId: any(named: 'localeId'),
      onResult: any(named: 'onResult'),
    )).thenAnswer((_) async {});

    await engine.startListening(localeId: 'en-US', onResult: (_) {});

    verifyInOrder([
      () => mockDeviceService.setPreferredInputDevice('usb-mic'),
      () => mockStt.listen(
        localeId: any(named: 'localeId'),
        onResult: any(named: 'onResult'),
      ),
    ]);
  });
}
```

### AudioDeviceService Mock

`AudioDeviceService` is already abstract (defined in FD). Tests mock it directly with mocktail. No additional adapter needed.

```dart
class MockAudioDeviceService extends Mock implements AudioDeviceService {}
```

**Location**: `packages/zip_core/test/helpers/mock_audio_device_service.dart`

---

## 4. dio Mock + Download Resume Pattern (REL-U2.2, TEST-U2.5, Q4=A)

### http_mock_adapter Setup

`SherpaModelManager` accepts a `Dio` instance via constructor. Tests provide a `Dio` with a `DioAdapter` from `http_mock_adapter`.

```dart
class SherpaModelManager {
  SherpaModelManager({
    required Dio dio,
    required Directory storageDir,
  }) : _dio = dio, _storageDir = storageDir;

  final Dio _dio;
  final Directory _storageDir;
}
```

### Download Resume Implementation (REL-U2.2)

```dart
Stream<SherpaModelDownloadProgress> downloadModel(String modelId) async* {
  final entry = _catalogEntryById(modelId);
  final partialFile = File('${_storageDir.path}/$modelId.partial');
  final int existingBytes = partialFile.existsSync() ? partialFile.lengthSync() : 0;

  final response = await _dio.get<ResponseBody>(
    entry.downloadUrl,
    options: Options(
      responseType: ResponseType.stream,
      headers: existingBytes > 0 ? {'Range': 'bytes=$existingBytes-'} : null,
    ),
  );

  final bool isResume = response.statusCode == 206;
  if (!isResume && existingBytes > 0) {
    // Server does not support Range — restart
    await partialFile.delete();
  }

  final totalBytes = isResume
      ? existingBytes + (response.headers.contentLength ?? 0)
      : response.headers.contentLength ?? 0;

  final sink = partialFile.openWrite(mode: isResume ? FileMode.append : FileMode.write);
  int receivedBytes = isResume ? existingBytes : 0;

  await for (final chunk in response.data!.stream) {
    sink.add(chunk);
    receivedBytes += chunk.length;
    yield SherpaModelDownloadProgress(
      modelId: modelId,
      downloadedBytes: receivedBytes,
      totalBytes: totalBytes,
    );
  }
  await sink.close();

  // Verify integrity (REL-U2.4) then extract
  await _verifyAndExtract(modelId, partialFile, entry.sha256Checksum);
}
```

### Test Patterns with DioAdapter

```dart
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late SherpaModelManager manager;
  late Directory tempDir;

  setUp(() async {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    tempDir = await Directory.systemTemp.createTemp('sherpa_test_');
    manager = SherpaModelManager(dio: dio, storageDir: tempDir);
  });

  test('download resumes with 206 response', () async {
    // Pre-create a partial file (simulates interrupted download)
    final partial = File('${tempDir.path}/model-1.partial');
    await partial.writeAsBytes(List.filled(1000, 0)); // 1000 bytes already downloaded

    dioAdapter.onGet(
      'https://cdn.example.com/models/model-1.tar.bz2',
      headers: {'Range': 'bytes=1000-'},
      (server) => server.reply(
        206,
        Stream.fromIterable([List.filled(500, 1)]),
        headers: {
          'content-length': ['500'],
          'content-range': ['bytes 1000-1499/1500'],
        },
      ),
    );

    final events = await manager.downloadModel('model-1').toList();
    expect(events.last.downloadedBytes, equals(1500));
  });

  test('download restarts when server returns 200 instead of 206', () async {
    final partial = File('${tempDir.path}/model-1.partial');
    await partial.writeAsBytes(List.filled(1000, 0));

    dioAdapter.onGet(
      'https://cdn.example.com/models/model-1.tar.bz2',
      (server) => server.reply(
        200,
        Stream.fromIterable([List.filled(1500, 1)]),
        headers: {'content-length': ['1500']},
      ),
    );

    final events = await manager.downloadModel('model-1').toList();
    expect(events.last.downloadedBytes, equals(1500));
    // Partial file was deleted and restarted
  });
}
```

---

## 5. Stale-While-Revalidate Catalog Caching Pattern (REL-U2.3, PERF-U2.3, Q3=B)

### File-Based Cache

The catalog cache uses two files in `_storageDir/`:

| File | Content |
|------|---------|
| `catalog_cache.json` | Raw catalog JSON response body |
| `catalog_cache_meta.json` | `{"cachedAt": "ISO8601", "etag": "...", "lastModified": "..."}` |

### CatalogCache Helper

```dart
class CatalogCache {
  CatalogCache(this._storageDir);
  final Directory _storageDir;

  static const _cacheFileName = 'catalog_cache.json';
  static const _metaFileName = 'catalog_cache_meta.json';
  static const freshnessDuration = Duration(hours: 24);

  File get _cacheFile => File('${_storageDir.path}/$_cacheFileName');
  File get _metaFile => File('${_storageDir.path}/$_metaFileName');

  bool get exists => _cacheFile.existsSync();

  bool get isFresh {
    if (!_metaFile.existsSync()) return false;
    final meta = jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
    final cachedAt = DateTime.parse(meta['cachedAt'] as String);
    return DateTime.now().difference(cachedAt) < freshnessDuration;
  }

  String? get etag {
    if (!_metaFile.existsSync()) return null;
    final meta = jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
    return meta['etag'] as String?;
  }

  String? get lastModified {
    if (!_metaFile.existsSync()) return null;
    final meta = jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
    return meta['lastModified'] as String?;
  }

  List<SherpaModelCatalogEntry> read() {
    if (!_cacheFile.existsSync()) return [];
    final json = jsonDecode(_cacheFile.readAsStringSync());
    return SherpaModelCatalogResponse.fromJson(json as Map<String, dynamic>).models;
  }

  Future<void> write(
    List<SherpaModelCatalogEntry> entries, {
    String? etag,
    String? lastModified,
  }) async {
    await _cacheFile.writeAsString(
      jsonEncode(SherpaModelCatalogResponse(models: entries).toJson()),
    );
    await _metaFile.writeAsString(jsonEncode({
      'cachedAt': DateTime.now().toIso8601String(),
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'lastModified': lastModified,
    }));
  }
}
```

### SherpaModelManager.catalogModels() Flow

```
catalogModels()
    |
    ├── cache is fresh? → return cache.read()
    |
    └── cache is stale or absent
            |
            ├── return cache.read() immediately (stale data)
            |
            └── trigger background revalidation:
                    |
                    ├── send GET with If-None-Match / If-Modified-Since
                    |
                    ├── 304 Not Modified → update cachedAt only
                    ├── 200 OK → cache.write(new data); notify listeners
                    └── error → log warning; stale cache remains
```

### dio Configuration (PERF-U2.3)

```dart
final dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
));
```

---

## 6. Archive Integrity Verification Pattern (REL-U2.4)

### SHA-256 Verification + Extraction

```dart
Future<void> _verifyAndExtract(
  String modelId,
  File archiveFile,
  String expectedSha256,
) async {
  // Step 1: Compute SHA-256 of the downloaded file
  final bytes = await archiveFile.readAsBytes();
  final digest = sha256.convert(bytes);

  if (digest.toString() != expectedSha256) {
    await archiveFile.delete();
    throw ModelIntegrityException(modelId: modelId, expected: expectedSha256, actual: digest.toString());
  }

  // Step 2: Extract .tar.bz2 to _storageDir/{modelId}/
  final modelDir = Directory('${_storageDir.path}/$modelId');
  await modelDir.create(recursive: true);

  final decompressed = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(decompressed);
  for (final file in archive) {
    if (file.isFile) {
      final outFile = File('${modelDir.path}/${file.name}');
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    }
  }

  // Step 3: Delete the archive file
  await archiveFile.delete();
}
```

### ModelIntegrityException

```dart
class ModelIntegrityException implements Exception {
  const ModelIntegrityException({
    required this.modelId,
    required this.expected,
    required this.actual,
  });
  final String modelId;
  final String expected;
  final String actual;
}
```

Caught in `SherpaModelCatalogNotifier.startDownload()` → sets `lastFailedDownloadId`.

### Test Pattern

```dart
test('checksum mismatch deletes file and throws', () async {
  // Fixture: a valid .tar.bz2 with known checksum
  final fixture = File('test/fixtures/valid_model.tar.bz2');
  final wrongChecksum = 'deadbeef' * 8; // 64 hex chars, wrong

  expect(
    () => manager.verifyAndExtract('model-1', fixture, wrongChecksum),
    throwsA(isA<ModelIntegrityException>()),
  );
  expect(File('${tempDir.path}/model-1.partial').existsSync(), isFalse);
});
```

**Dependencies**: `crypto` (for SHA-256), `archive` (for tar+bz2 extraction).

---

## 7. Large Download Confirmation Pattern (USA-U2.1)

### Confirmation Threshold

```dart
/// In SherpaModelManager or a constants file.
static const int downloadConfirmationThresholdBytes = 100 * 1024 * 1024; // 100MB
```

### SherpaModelCatalogNotifier Flow

The confirmation gate lives in `SherpaModelCatalogNotifier`, not `SherpaModelManager`. The manager always downloads unconditionally; the notifier enforces the UX gate.

```dart
void startDownload(String modelId) {
  if (state.activeDownloads.containsKey(modelId)) return; // BR-U2-38

  final entry = state.models.firstWhere((m) => m.modelId == modelId);

  if (entry.downloadSizeBytes > downloadConfirmationThresholdBytes) {
    // Emit pending confirmation state — UI shows dialog
    state = state.copyWith(
      pendingConfirmationModelId: modelId,
    );
    return;
  }

  _beginDownload(modelId);
}

void confirmDownload(String modelId) {
  state = state.copyWith(pendingConfirmationModelId: null);
  _beginDownload(modelId);
}

void cancelPendingConfirmation() {
  state = state.copyWith(pendingConfirmationModelId: null);
}
```

### SherpaModelCatalogState Extension

```dart
@freezed
class SherpaModelCatalogState with _$SherpaModelCatalogState {
  const factory SherpaModelCatalogState({
    @Default([]) List<SherpaModelInfo> models,
    @Default({}) Map<String, SherpaModelDownloadProgress> activeDownloads,
    String? lastFailedDownloadId,
    String? pendingConfirmationModelId, // NEW: model awaiting user confirmation
  }) = _SherpaModelCatalogState;
}
```

The UI reads `pendingConfirmationModelId` to show a confirmation dialog with the model's `downloadSizeBytes`. On confirm → `confirmDownload(modelId)`. On cancel → `cancelPendingConfirmation()`.

---

## 8. WakeLockService Interface Pattern (Q5=A)

### Abstract Interface

```dart
/// Abstract wake lock service. Production: WakelockPlusService.
/// Tests: MockWakeLockService (mocktail).
abstract class WakeLockService {
  WakeLockSettings get settings;
  Future<void> acquire();
  Future<void> release();
  Future<void> onPause();
  void updateSettings(WakeLockSettings settings);
}
```

### Production Implementation

```dart
class WakelockPlusService implements WakeLockService {
  WakelockPlusService({WakeLockSettings settings = const WakeLockSettings()})
      : _settings = settings;

  WakeLockSettings _settings;

  @override
  WakeLockSettings get settings => _settings;

  @override
  Future<void> acquire() async {
    if (_settings.enabled) {
      await WakelockPlus.enable();
    }
  }

  @override
  Future<void> release() async {
    await WakelockPlus.disable();
  }

  @override
  Future<void> onPause() async {
    if (_settings.releaseOnPause) {
      await release();
    }
  }

  @override
  void updateSettings(WakeLockSettings settings) {
    _settings = settings;
  }
}
```

### Test Mock

```dart
class MockWakeLockService extends Mock implements WakeLockService {}
```

Used in `RecordingStateNotifier` tests to verify that `acquire()` is called on `start()`/`resume()`, `onPause()` on `pause()`, and `release()` on `stop()`.

### AudioDeviceService — Already Abstract

`AudioDeviceService` is defined as an abstract interface in the FD. Tests mock it directly:

```dart
class MockAudioDeviceService extends Mock implements AudioDeviceService {}
```

No additional adapter pattern needed.

**Locations**:
- `packages/zip_core/lib/src/services/wake_lock_service.dart` (interface)
- `packages/zip_core/lib/src/services/wakelock_plus_service.dart` (implementation)
- `packages/zip_core/test/helpers/mock_wake_lock_service.dart`

---

## 9. PBT Generators and Properties (Q6=B)

### New Arbitrary Generators

Added to `packages/zip_core/test/helpers/generators.dart`:

```dart
/// Generates valid AudioDevice instances.
class ArbitraryAudioDevice extends Arbitrary<AudioDevice> {
  @override
  AudioDevice generate(Random random, int size) => AudioDevice(
    deviceId: 'device-${random.nextInt(100)}',
    name: 'Mic ${random.nextInt(50)}',
    isDefault: random.nextBool(),
  );
}

/// Generates valid SherpaModelCatalogEntry instances.
class ArbitrarySherpaModelCatalogEntry extends Arbitrary<SherpaModelCatalogEntry> {
  @override
  SherpaModelCatalogEntry generate(Random random, int size) => SherpaModelCatalogEntry(
    modelId: 'model-${random.nextInt(100)}',
    displayName: 'Model ${random.nextInt(50)}',
    primaryLocaleId: ['en-US', 'es-ES', 'fr-FR', 'de-DE'][random.nextInt(4)],
    downloadSizeBytes: random.nextInt(300 * 1024 * 1024),
    downloadUrl: 'https://cdn.example.com/models/model-${random.nextInt(100)}.tar.bz2',
    sha256Checksum: List.generate(64, (_) => random.nextInt(16).toRadixString(16)).join(),
  );
}

/// Generates valid SherpaModelInfo instances with consistent isDownloaded/localPath invariant.
class ArbitrarySherpaModelInfo extends Arbitrary<SherpaModelInfo> {
  @override
  SherpaModelInfo generate(Random random, int size) {
    final isDownloaded = random.nextBool();
    return SherpaModelInfo(
      catalogEntry: ArbitrarySherpaModelCatalogEntry().generate(random, size),
      isDownloaded: isDownloaded,
      localPath: isDownloaded ? '/models/model-${random.nextInt(100)}' : null,
    );
  }
}

/// Generates valid WakeLockSettings instances.
class ArbitraryWakeLockSettings extends Arbitrary<WakeLockSettings> {
  @override
  WakeLockSettings generate(Random random, int size) => WakeLockSettings(
    enabled: random.nextBool(),
    releaseOnPause: random.nextBool(),
  );
}

/// Generates valid SherpaModelDownloadProgress instances.
class ArbitrarySherpaModelDownloadProgress extends Arbitrary<SherpaModelDownloadProgress> {
  @override
  SherpaModelDownloadProgress generate(Random random, int size) {
    final total = random.nextInt(300 * 1024 * 1024) + 1;
    return SherpaModelDownloadProgress(
      modelId: 'model-${random.nextInt(100)}',
      downloadedBytes: random.nextInt(total),
      totalBytes: total,
    );
  }
}
```

### Extended StateTransition Enum

```dart
enum StateTransition {
  start,
  pause,
  resume,
  stop,
  clearSession,
  // Unit 2 additions:
  engineError,    // triggers reconnecting flow
  reconnectSuccess,  // recovery succeeds
  reconnectFailure,  // recovery fails
}
```

### Extended State Machine PBT

```dart
Glados(arbitraryTransitionSequence).test(
  'state machine is valid after any transition sequence including reconnect',
  (transitions) {
    final notifier = createTestNotifier();

    for (final t in transitions) {
      applyTransition(notifier, t);
      final state = notifier.state;

      // Invariant: reconnecting always preserves sessionId from recording
      if (state is ReconnectingState) {
        // Must have come from recording — sessionId is non-null
        expect(state.sessionId, isNotEmpty);
      }

      // Invariant: reconnecting only reachable from recording
      // (enforced by applyTransition — engineError is a no-op in non-recording states)

      // Invariant: after reconnectFailure, state is stopped with lastError set
      if (t == StateTransition.reconnectFailure && state is StoppedState) {
        expect(notifier.lastError, isNotNull);
      }
    }
  },
);
```

### Domain Type Property Tests

| Test File | Properties |
|-----------|-----------|
| `pbt/sherpa_model_info_properties_test.dart` | `isDownloaded == true` ↔ `localPath != null`; serialization round-trip |
| `pbt/audio_device_properties_test.dart` | Serialization round-trip; `deviceId` non-empty |
| `pbt/wake_lock_settings_roundtrip_test.dart` | Save/load round-trip via SharedPreferences |
| `pbt/download_progress_properties_test.dart` | `downloadedBytes <= totalBytes`; `totalBytes > 0` |
| `pbt/recording_state_machine_test.dart` | Extended with `engineError`, `reconnectSuccess`, `reconnectFailure` transitions |

---

## 10. Permission Handler Test Pattern

### SttSessionManager Permission Tests

`SttSessionManager` uses `permission_handler` to check microphone status. In tests, `permission_handler` is mocked via its platform interface:

```dart
setUp(() {
  // Set up mock permission handler
  final mockPermissionHandler = MockPermissionHandlerPlatform();
  PermissionHandlerPlatform.instance = mockPermissionHandler;

  when(() => mockPermissionHandler.checkPermissionStatus(Permission.microphone))
      .thenAnswer((_) async => PermissionStatus.granted);
  when(() => mockPermissionHandler.requestPermissions([Permission.microphone]))
      .thenAnswer((_) async => {Permission.microphone: PermissionStatus.granted});
});
```

### Test Scenarios

| Scenario | Mock Setup | Expected Outcome |
|----------|-----------|------------------|
| Permission granted | `checkPermissionStatus → granted` | `initialize()` proceeds to engine |
| Permission undetermined → granted | `check → undetermined`, `request → granted` | `initialize()` proceeds after request |
| Permission denied | `check → denied`, `request → denied` | `onError(permissionDenied)`, returns false |
| Permission permanently denied | `check → permanentlyDenied` | `onError(permissionPermanentlyDenied)`, returns false |
| Permission denied → permanently denied | `check → denied`, `request → permanentlyDenied` | `onError(permissionPermanentlyDenied)` |

---

## 11. Logging Pattern Extension (SEC-U2.1, MAINT-U2.2)

### New Logger Instances

All Unit 2 components follow the Unit 1 naming convention:

| Component | Logger Name |
|-----------|-------------|
| `SttSessionManager` | `zip_core.SttSessionManager` |
| `PlatformSttEngine` | `zip_core.PlatformSttEngine` |
| `SherpaOnnxSttEngine` | `zip_core.SherpaOnnxSttEngine` |
| `SherpaModelManager` | `zip_core.SherpaModelManager` |
| `SherpaModelCatalogNotifier` | `zip_core.SherpaModelCatalogNotifier` |
| `AudioDeviceService` (impls) | `zip_core.{ImplClassName}` |
| `WakelockPlusService` | `zip_core.WakelockPlusService` |

### Security Constraint (SEC-U2.1)

Extends Unit 1's SECURITY-03 constraint. **Never log**:
- `SttResult.text` or `SttResult.confidence` values
- Audio buffer contents
- `RecordingState.currentSegment`

**Permitted in logs**: engine ID, model ID, locale ID, device ID, session ID, error type, byte counts, download progress percentage, checksum values.

### HTTPS Enforcement Logging (SEC-U2.2)

```dart
if (!entry.downloadUrl.startsWith('https://')) {
  _log.warning('Rejected non-HTTPS download URL for model ${entry.modelId}');
  continue; // skip this entry
}
```
