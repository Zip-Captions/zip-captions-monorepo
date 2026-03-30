# Business Logic Model — Unit 1: Core Abstractions

## 1. SttEngine Interface (Updated)

### Phase 0 to Phase 1 Delta

| Aspect | Phase 0 | Phase 1 |
|--------|---------|---------|
| `startListening` callbacks | `onInterimResult(String)`, `onFinalResult(String)`, `onError(RecordingError)` | `onResult(SttResult)` |
| `startListening` localeId | Optional (`String?`) | Required (`String`) |
| Locale query | `getAvailableLocales()` | `supportedLocales()` |
| New properties | — | `engineId`, `displayName`, `requiresNetwork`, `requiresDownload` |
| Error reporting | `onError` callback | Error handling deferred to engine internals; errors surface via RecordingError on the notifier |

### Updated Interface

```dart
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
```

### Design Decisions

- **Q7=B**: `supportedLocales()` is a method, not a getter. Consistent with other async members (`isAvailable()`, `initialize()`).
- **Q1=A**: Clean break from Phase 0 callbacks. All existing tests updated immediately.
- **Q4=C**: `SttEngineProvider` keeps throwing `UnimplementedError` until Unit 2. Unit 1 tests use mock engines directly.
- **`localeId` now required**: Engines should not guess the locale. The app explicitly passes the user's selected locale.
- **`onError` removed from startListening**: Error handling is the engine's internal concern. Engines set `RecordingError` on the notifier or handle errors internally. This simplifies the callback contract to a single `onResult`.

---

## 2. SttEngineRegistry

A plain Dart service class (not a Riverpod provider itself) that manages registered STT engine instances.

```
+-----------------------------------+
| SttEngineRegistry                 |
+-----------------------------------+
| - _engines: Map<String, SttEngine>|
+-----------------------------------+
| + register(SttEngine)             |
| + unregister(String engineId)     |
| + listAvailable(): List<SttEngine>|
| + getEngine(String): SttEngine?   |
| + defaultEngine: SttEngine?       |
+-----------------------------------+
```

### Behavior

| Method | Behavior |
|--------|----------|
| `register(engine)` | Adds engine to internal map keyed by `engine.engineId`. If an engine with the same ID is already registered, replaces it (last-write-wins) |
| `unregister(engineId)` | Removes engine from map. No-op if not found |
| `listAvailable()` | Returns all registered engines as an unmodifiable list |
| `getEngine(engineId)` | Returns the engine or `null` if not registered |
| `defaultEngine` | Returns the first registered engine, or `null` if empty. "First" is insertion-order (LinkedHashMap) |

### Registration Flow

```
App startup
    |
    v
SttEngineRegistryProvider creates SttEngineRegistry
    |
    v
Unit 2: PlatformSttEngine is registered
Unit 2+: SherpaOnnxSttEngine registered (if model downloaded)
    |
    v
SttEngineProvider (Unit 2) reads from registry
```

**Unit 1 scope**: Registry exists and is testable with mock engines. No concrete engines are registered until Unit 2.

---

## 3. CaptionBus

A standalone Dart service class using a broadcast `StreamController<CaptionEvent>`. Held by a `keepAlive` Riverpod provider.

```
+-----------------------------------+
| CaptionBus                        |
+-----------------------------------+
| - _controller:                    |
|   StreamController<CaptionEvent>  |
|   (broadcast)                     |
+-----------------------------------+
| + publish(CaptionEvent)           |
| + stream: Stream<CaptionEvent>    |
| + dispose()                       |
+-----------------------------------+
```

### Behavior

| Method | Behavior |
|--------|----------|
| `publish(event)` | Adds the event to the broadcast stream controller. No-op if controller is closed |
| `stream` | Returns the broadcast stream. Multiple listeners can subscribe independently |
| `dispose()` | Closes the stream controller. No further events can be published |

### Event Flow

```
SttEngine.onResult(SttResult)
    |
    v
RecordingStateNotifier
    |-- updates currentSegment on state
    |-- publishes SttResultEvent to CaptionBus
    |
    v
CaptionBus.publish(SttResultEvent)
    |
    v
CaptionBus.stream (broadcast)
    |
    +---> CaptionOutputTargetRegistry (listener)
              |
              +---> Target A.onCaptionEvent()
              +---> Target B.onCaptionEvent()
              +---> Target C.onCaptionEvent()
```

### Session State Events

```
RecordingStateNotifier.start()
    |--> state = RecordingState.recording(sessionId: uuid)
    |--> CaptionBus.publish(SessionStateEvent(state))

RecordingStateNotifier.pause()
    |--> state = RecordingState.paused(sessionId: same)
    |--> CaptionBus.publish(SessionStateEvent(state))

RecordingStateNotifier.resume()
    |--> state = RecordingState.recording(sessionId: same)
    |--> CaptionBus.publish(SessionStateEvent(state))

RecordingStateNotifier.stop()
    |--> state = RecordingState.stopped(sessionId: same)
    |--> CaptionBus.publish(SessionStateEvent(state))
```

---

## 4. CaptionOutputTarget Interface

Abstract interface for any consumer of caption events.

```dart
abstract interface class CaptionOutputTarget {
  /// Unique identifier for this target instance.
  String get targetId;

  /// Handle an incoming caption event.
  ///
  /// **Security (SECURITY-03)**: Implementations must not log
  /// transcript text from SttResultEvent.
  void onCaptionEvent(CaptionEvent event);

  /// Release resources.
  void dispose();
}
```

**Unit 1 scope**: Interface definition only. Concrete implementations (`OnScreenCaptionTarget`, `TranscriptWriterTarget`, etc.) are in Unit 3.

---

## 5. CaptionOutputTargetRegistry

Manages registered output targets and fans out CaptionBus events to each target with error isolation.

```
+-------------------------------------------+
| CaptionOutputTargetRegistry               |
+-------------------------------------------+
| - _targets: Set<CaptionOutputTarget>      |
| - _busSubscription: StreamSubscription?   |
| - _bus: CaptionBus                        |
+-------------------------------------------+
| + add(CaptionOutputTarget)                |
| + remove(CaptionOutputTarget)             |
| + activeTargets: Set<CaptionOutputTarget> |
| + dispose()                               |
+-------------------------------------------+
```

### Behavior

| Method | Behavior |
|--------|----------|
| `add(target)` | Adds target to the set. If this is the first target, subscribes to `_bus.stream` (Q5=B: lazy subscription). Duplicate adds are no-ops (Set semantics) |
| `remove(target)` | Removes target from the set. If the set is now empty, cancels the bus subscription. Calls `target.dispose()` |
| `activeTargets` | Returns an unmodifiable view of the current target set |
| `dispose()` | Cancels bus subscription. Calls `dispose()` on each target. Clears the set |

### Error Isolation (Q2=A)

When a CaptionEvent arrives from the bus, the registry iterates all targets and calls `onCaptionEvent` in a try-catch per target:

```dart
void _onBusEvent(CaptionEvent event) {
  for (final target in _targets) {
    try {
      target.onCaptionEvent(event);
    } catch (e, st) {
      // Log error with target ID — no transcript text
      log(
        'Target ${target.targetId} error: ${e.runtimeType}',
        level: 900,
        name: 'CaptionOutputTargetRegistry',
        error: e,
        stackTrace: st,
      );
    }
  }
}
```

A failing target does not affect other targets. The failing target remains registered and continues to receive subsequent events.

### Lazy Subscription Lifecycle (Q5=B)

```
add(first target)
    |--> _busSubscription = _bus.stream.listen(_onBusEvent)

add(second target)
    |--> no subscription change (already listening)

remove(second target)
    |--> _targets still non-empty, subscription stays

remove(first target)
    |--> _targets empty
    |--> _busSubscription?.cancel()
    |--> _busSubscription = null
```

---

## 6. RecordingStateNotifier (Updated)

### Phase 1 Changes

The notifier gains dependencies on the `CaptionBus` for event publishing. STT engine wiring remains deferred to Unit 2 (Q4=C).

**New constructor dependency**: `CaptionBus` (injected via provider ref).

### Updated State Machine

```
     [idle]
       |
       | start(localeId)
       | --> generate sessionId
       | --> publish SessionStateEvent
       v
  [recording]  <---+
    |    |         |
    |    | pause() |
    |    | --> publish SessionStateEvent
    |    v         |
    | [paused]     |
    |    |         |
    |    | resume() |
    |    | --> publish SessionStateEvent
    |    +---------+
    |
    | stop()
    | --> publish SessionStateEvent
    v
  [stopped]
    |
    | clearSession()
    v
   [idle]
```

### Updated Methods

| Method | Phase 0 | Phase 1 Delta |
|--------|---------|---------------|
| `start({String? localeId})` | Stub transition | Generates `sessionId` via `Uuid().v4()`. Creates `RecordingState.recording(sessionId: id)`. Publishes `SessionStateEvent`. **STT engine start deferred to Unit 2** |
| `pause()` | Stub transition | Preserves `sessionId` and `currentSegment` from current state. Publishes `SessionStateEvent` |
| `resume()` | Stub transition | Preserves `sessionId`. Resets `currentSegment` to `''`. Publishes `SessionStateEvent` |
| `stop()` | Stub transition | Preserves `sessionId`. Publishes `SessionStateEvent`. **STT engine stop deferred to Unit 2** |
| `clearSession()` | Resets to idle | Unchanged |
| **new** `_handleSttResult(SttResult)` | — | Updates `currentSegment` on the current state. On `isFinal`, clears `currentSegment`. Publishes `SttResultEvent` to bus. **Wired to SttEngine.onResult in Unit 2** |

### currentSegment Update Logic

```dart
void _handleSttResult(SttResult result) {
  final current = state;
  if (current is! RecordingActiveState) return;

  if (result.isFinal) {
    // Final result: clear currentSegment, publish to bus
    state = RecordingActiveState(
      sessionId: current.sessionId,
      currentSegment: '',
    );
  } else {
    // Interim result: update currentSegment
    state = RecordingActiveState(
      sessionId: current.sessionId,
      currentSegment: result.text,
    );
  }

  // Publish to CaptionBus regardless of interim/final
  _captionBus.publish(SttResultEvent(result));
}
```

**Security (SECURITY-03)**: `_handleSttResult` passes transcript text through state and bus only. No logging of `result.text`.

---

## 7. Provider Layer

### New Providers

| Provider | Type | keepAlive | Purpose |
|----------|------|-----------|---------|
| `SttEngineRegistryProvider` | `Provider<SttEngineRegistry>` | Yes | Singleton registry instance |
| `CaptionBusProvider` | `Provider<CaptionBus>` | Yes | Singleton bus instance |
| `CaptionOutputTargetRegistryProvider` | `Provider<CaptionOutputTargetRegistry>` | Yes | Singleton registry, depends on CaptionBusProvider |

All three are `keepAlive: true` — they persist for the app lifetime.

### Provider Dependencies

```
SttEngineRegistryProvider (standalone)

CaptionBusProvider (standalone)
    |
    v
CaptionOutputTargetRegistryProvider
    (reads CaptionBusProvider to get bus reference)

RecordingStateNotifier
    (reads CaptionBusProvider for publishing)
    (reads SttEngineProvider for engine — Unit 2)
```

### Updated Providers

| Provider | Phase 0 | Phase 1 Change |
|----------|---------|----------------|
| `SttEngineProvider` | Throws `UnimplementedError` | **No change in Unit 1** (Q4=C). Updated in Unit 2 to read from registry |
| `LocaleInfoProvider` | Returns `[]` | Reads `supportedLocales()` from active SttEngine. Returns `[]` if no engine available. Implementation depends on SttEngineProvider, so effective change happens in Unit 2 when SttEngineProvider is wired |
| `RecordingStateNotifier` | Stub transitions | Reads CaptionBusProvider. Generates sessionId. Publishes SessionStateEvents. Handles SttResult via `_handleSttResult` |

### BaseSettingsNotifier Rename

`BaseSettingsNotifier` changes from `Notifier<AppSettings>` to `Notifier<DisplaySettings>`. Internal logic unchanged. Key prefix updated from `app_settings` to `display_settings` (Q6=A).

App-level subclasses renamed:
- `ZipCaptionsSettingsNotifier` -> `DisplaySettingsNotifier` (in zip_captions)
- `ZipBroadcastSettingsNotifier` -> `DisplaySettingsNotifier` (in zip_broadcast)

---

## 8. TranscriptSettingsProvider

New provider for transcript capture toggle. Simple SharedPreferences-backed boolean.

```dart
@Riverpod(keepAlive: true)
class TranscriptSettingsNotifier extends _$TranscriptSettingsNotifier {
  static const _key = 'transcript.captureEnabled';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? true; // Default: capture enabled
  }

  Future<void> setCaptureEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}
```

**Note**: The full `TranscriptSettings` model (with more fields) may emerge in Unit 3 when transcript storage is implemented. Unit 1 establishes the provider pattern with the capture toggle only.
