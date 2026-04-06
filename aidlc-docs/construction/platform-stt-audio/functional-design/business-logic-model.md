# Business Logic Model — Unit 2: Platform STT + Audio

## 1. AudioDeviceService (Abstract Interface)

A platform-agnostic interface for enumerating audio input devices and directing input to a user-selected device. Lives in `zip_core`. Platform implementations are provided per-target and registered at app startup.

```
+----------------------------------------------+
| AudioDeviceService (abstract interface)       |
+----------------------------------------------+
| + listInputDevices(): Future<List<AudioDevice>>|
| + setPreferredInputDevice(String deviceId):   |
|     Future<void>                              |
| + clearPreferredInputDevice(): Future<void>   |
| + currentPreferredDeviceId: String?           |
+----------------------------------------------+
```

### Behavior

| Method | Behavior |
|--------|----------|
| `listInputDevices()` | Returns all available audio input devices on the current platform. Always includes at least the system default (with `isDefault: true`). Returns `[AudioDevice(deviceId: 'default', name: 'System Default', isDefault: true)]` if enumeration is unsupported. |
| `setPreferredInputDevice(deviceId)` | Directs the platform audio session to use the identified device before the next STT session starts. Persists the preference in SharedPreferences under `audio.preferredInputDeviceId`. |
| `clearPreferredInputDevice()` | Removes the device preference. Subsequent sessions use the system default. |
| `currentPreferredDeviceId` | Synchronous accessor to the currently stored preference. `null` = system default. |

### Platform Strategy (Q2=D)

The preferred approach is a package that both enumerates and routes audio input. Concrete implementation selection happens in NFR Requirements. The `AudioDeviceService` interface isolates zip_core from that choice. `PlatformSttEngine` calls `AudioDeviceService.setPreferredInputDevice()` before each `startListening()` call when a preference is set.

---

## 2. WakeLockService

A plain Dart class (not a Riverpod provider) wrapping `wakelock_plus`. Held as a field on `RecordingStateNotifier` and called explicitly on state transitions (Q4=A — explicit pattern consistent with codebase standard).

```
+--------------------------------------------+
| WakeLockService                            |
+--------------------------------------------+
| - _settings: WakeLockSettings              |
+--------------------------------------------+
| + acquire(): Future<void>                  |
| + release(): Future<void>                  |
| + onPause(): Future<void>                  |
| + updateSettings(WakeLockSettings): void   |
+--------------------------------------------+
```

### Behavior

| Method | Behavior |
|--------|----------|
| `acquire()` | Calls `WakelockPlus.enable()` if `_settings.enabled` is true. No-op if already acquired or disabled. |
| `release()` | Calls `WakelockPlus.disable()` unconditionally (safe to call when not acquired). |
| `onPause()` | If `_settings.releaseOnPause` is true, calls `release()`. Otherwise no-op — screen stays on. |
| `updateSettings(settings)` | Replaces `_settings`. If captioning is currently active, effect applies on the next transition. |

### Call Sites in RecordingStateNotifier

```
start()   --> _wakeLockService.acquire()
pause()   --> _wakeLockService.onPause()
resume()  --> _wakeLockService.acquire()
stop()    --> _wakeLockService.release()
```

---

## 3. SttSessionManager (Q3=B)

A plain Dart service class that owns the full STT engine lifecycle for a single captioning session. Held by a `keepAlive` Riverpod provider. `RecordingStateNotifier` delegates engine calls to it explicitly — never calling the engine directly.

```
+-----------------------------------------------+
| SttSessionManager                             |
+-----------------------------------------------+
| - _engine: SttEngine?                         |
| - _registry: SttEngineRegistry                |
| - _activeEngineId: String?                    |
+-----------------------------------------------+
| + initialize(engineId, localeId,              |
|     onResult, onError): Future<bool>          |
| + startListening(): Future<bool>              |
| + pause(): Future<bool>                       |
| + resume(): Future<bool>                      |
| + stop(): Future<void>                        |
| + dispose(): void                             |
| + activeEngine: SttEngine?                    |
+-----------------------------------------------+
```

### Lifecycle

```
RecordingStateNotifier.start(localeId)
    |
    v
SttSessionManager.initialize(engineId, localeId, onResult, onError)
    |--> resolve engine from SttEngineRegistry by engineId
    |--> check permission (permission_handler): if denied → onError(permissionDenied)
    |--> engine.initialize() → false → onError(engineInitFailed)
    |--> success: _engine = resolvedEngine
    |
    v
SttSessionManager.startListening()
    |--> engine.startListening(localeId: localeId, onResult: onResult)
    |--> false → onError(engineStartFailed)

RecordingStateNotifier.pause()
    |--> SttSessionManager.pause() → engine.pause()

RecordingStateNotifier.resume()
    |--> SttSessionManager.resume() → engine.resume()

RecordingStateNotifier.stop()
    |--> SttSessionManager.stop() → engine.stopListening()

App dispose / provider teardown
    |--> SttSessionManager.dispose() → engine.dispose()
```

### Permission Check Logic (Q6=A)

`initialize()` uses `permission_handler` to check microphone status before calling `engine.initialize()`.

`denied` and `permanentlyDenied` are distinct cases — `denied` can still be re-requested by the OS on most platforms; `permanentlyDenied` requires the user to go to system Settings manually.

```
permission_handler.Permission.microphone.status
    |
    ├── granted            → proceed to engine.initialize()
    |
    ├── undetermined       → request()
    |       ├── granted        → proceed to engine.initialize()
    |       └── denied         → onError(permissionDenied); return false
    |
    ├── denied             → request()          ← re-requestable (OS decides whether to show dialog)
    |       ├── granted        → proceed to engine.initialize()
    |       └── denied         → onError(permissionDenied); return false
    |       └── permanentlyDenied → onError(permissionPermanentlyDenied); return false
    |
    └── permanentlyDenied  → onError(permissionPermanentlyDenied); return false
                              (OS will not show dialog; user must go to system Settings)
```

**Re-trigger mechanism — `denied` path**: Because `denied` calls `request()`, the user can re-trigger the OS permission dialog simply by tapping "Start" again. No additional UI affordance is needed for this case.

**Re-trigger mechanism — `permanentlyDenied` path**: The OS will not show the dialog again. `RecordingStateNotifier` exposes `openMicrophoneSettings()` which calls `permission_handler`'s `openAppSettings()`. The UI renders an "Open Settings" button when `lastError` is a `permissionPermanentlyDenied` error.

```
+------------------------------------------+
| RecordingStateNotifier (addition)        |
+------------------------------------------+
| + openMicrophoneSettings(): Future<void> |
|     --> openAppSettings()                |
+------------------------------------------+
```

After the user returns from system Settings and grants permission, they tap "Start" again — `start()` re-runs `initialize()`, which now finds `granted` and proceeds normally.

Permission is only requested here — not on app launch or in any provider build method.

### RecordingError — Two Permission Variants

The `RecordingErrorFactories` extension gains a second permission constructor to distinguish the two paths:

```dart
// In domain-entities.md RecordingErrorFactories extension
static RecordingError permissionDenied() => RecordingError(
  message: 'Microphone access denied.',
  severity: RecordingErrorSeverity.fatal,
  timestamp: DateTime.now(),
);

static RecordingError permissionPermanentlyDenied() => RecordingError(
  message: 'Microphone access is blocked. Enable it in system Settings.',
  severity: RecordingErrorSeverity.fatal,
  timestamp: DateTime.now(),
);
```

The UI distinguishes these by message string match or, preferably, by a future `RecordingError.code` field (deferred to a later unit if needed). For Unit 2, the message content is sufficient for the UI to decide whether to show "Try Again" vs "Open Settings".

---

## 4. PlatformSttEngine

Wraps `speech_to_text` for Tier 1 platforms (iOS, macOS, Android, Windows via WinRT). Implements `SttEngine`.

```
+------------------------------------------------+
| PlatformSttEngine implements SttEngine         |
+------------------------------------------------+
| - _stt: SpeechToText                           |
| - _deviceService: AudioDeviceService           |
+------------------------------------------------+
| engineId: 'platform'                           |
| displayName: 'Platform Speech Recognition'     |
| requiresNetwork: false                         |
| requiresDownload: false                        |
+------------------------------------------------+
| + initialize(): Future<bool>                   |
| + isAvailable(): Future<bool>                  |
| + supportedLocales(): Future<List<SpeechLocale>>|
| + startListening({localeId, onResult}):        |
|     Future<bool>                               |
| + stopListening(): Future<void>                |
| + pause(): Future<bool>                        |
| + resume(): Future<bool>                       |
| + dispose(): void                              |
+------------------------------------------------+
```

### Key Behaviors

| Method | Behavior |
|--------|----------|
| `initialize()` | Calls `_stt.initialize()`. Returns false if unavailable. Does NOT check permission itself — `SttSessionManager` handles permission before calling this. |
| `isAvailable()` | Returns `_stt.isAvailable`. False on Linux (no WinRT equivalent). |
| `supportedLocales()` | Calls `_stt.locales()` and maps to `SpeechLocale` list. |
| `startListening()` | Calls `_deviceService.setPreferredInputDevice()` if a preference is set, then `_stt.listen(localeId: localeId, onResult: ...)`. Maps `SpeechRecognitionResult` to `SttResult` in the callback. |
| `pause()` | Calls `_stt.stop()` (speech_to_text has no native pause). Records paused state internally. |
| `resume()` | Re-calls `_stt.listen()` with the same localeId and onResult callback (transparent restart). |
| `stopListening()` | Calls `_stt.stop()` and `_stt.cancel()`. |
| `dispose()` | Calls `_stt.cancel()`. |

**Security (SECURITY-03)**: The `onResult` callback receives `SttResult` containing transcript text. `PlatformSttEngine` never logs `result.text`.

---

## 5. SherpaOnnxSttEngine (Q1=A)

Wraps the `sherpa_onnx` package for Tier 2 platforms (Windows/Linux primary, available elsewhere). Implements `SttEngine`. Requires a downloaded model.

```
+------------------------------------------------------+
| SherpaOnnxSttEngine implements SttEngine             |
+------------------------------------------------------+
| - _recognizer: OnlineRecognizer?                     |
| - _modelManager: SherpaModelManager                  |
| - _deviceService: AudioDeviceService                 |
| - _activeModelId: String?                            |
+------------------------------------------------------+
| engineId: 'sherpa-onnx'                              |
| displayName: 'Offline Speech Recognition'            |
| requiresNetwork: false                               |
| requiresDownload: true                               |
+------------------------------------------------------+
```

### Key Behaviors

| Method | Behavior |
|--------|----------|
| `isAvailable()` | True iff at least one model is downloaded (`_modelManager.downloadedModels.isNotEmpty`). |
| `initialize()` | Selects the best available model for the active locale (via `_modelManager.bestModelForLocale(localeId)`). Loads `OnlineRecognizer` from model path. Calls `_deviceService.setPreferredInputDevice()` if preference set. Returns false if no model available or load fails. |
| `supportedLocales()` | Derived from downloaded models: maps each `SherpaModelInfo.primaryLocaleId` to `SpeechLocale`. Includes one entry per unique locale across all downloaded models. |
| `startListening()` | Begins the Sherpa-ONNX feed/decode loop: audio input → PCM chunks → `OnlineRecognizer.acceptWaveform()` → `OnlineRecognizer.getResult()` → emit `SttResult`. |
| `pause()` | Stops feeding audio to the recognizer (native pause — no teardown). |
| `resume()` | Resumes feeding audio. |
| `stopListening()` | Stops audio feed, flushes final result, resets recognizer. |
| `dispose()` | Frees `OnlineRecognizer` native resources. |

**Security (SECURITY-03)**: Transcript text from `OnlineRecognizer.getResult()` flows only into `onResult(SttResult)`. Never logged.

---

## 6. SherpaModelManager (Q1=A)

A plain Dart service managing the full lifecycle of Sherpa-ONNX models: catalog, download, storage, and locale mapping.

```
+-----------------------------------------------------------+
| SherpaModelManager                                        |
+-----------------------------------------------------------+
| - _catalog: List<SherpaModelInfo>                         |
| - _storageDir: Directory                                  |
+-----------------------------------------------------------+
| + catalogModels(): Future<List<SherpaModelInfo>>          |
| + downloadedModels: List<SherpaModelInfo>                 |
| + downloadModel(modelId):                                 |
|     Stream<SherpaModelDownloadProgress>                   |
| + deleteModel(modelId): Future<void>                      |
| + bestModelForLocale(localeId): SherpaModelInfo?          |
| + modelLocalPath(modelId): String?                        |
+-----------------------------------------------------------+
```

### Behavior

| Method | Behavior |
|--------|----------|
| `catalogModels()` | Returns the cached catalog immediately if fresh (< 24 h). If stale, returns the cache immediately and triggers a background revalidation via the app-operated catalog endpoint; updates the cache on success (stale-while-revalidate). Sends `If-None-Match`/`If-Modified-Since` conditional headers when ETag/Last-Modified is known. Returns `[]` only when no cache exists and the network is unavailable. |
| `downloadedModels` | Synchronous — returns catalog entries where `isDownloaded == true`. |
| `downloadModel(modelId)` | Downloads the model archive from the configured CDN URL. Yields `SherpaModelDownloadProgress` events. On completion, extracts to `_storageDir/{modelId}/` and updates `isDownloaded`. |
| `deleteModel(modelId)` | Deletes `_storageDir/{modelId}/`. Updates `isDownloaded` on the catalog entry. |
| `bestModelForLocale(localeId)` | Selects the best downloaded model for a BCP-47 locale: exact locale match → language-only match (e.g., `en` matches `en-US`) → `null` if none. |
| `modelLocalPath(modelId)` | Returns `_storageDir/{modelId}` if directory exists, else `null`. |

### Storage Location

| Platform | Storage Root |
|----------|-------------|
| Desktop (Win/Linux/macOS) | `getApplicationSupportDirectory()/sherpa_models/` |
| Mobile (iOS/Android) | `getApplicationDocumentsDirectory()/sherpa_models/` |

---

## 7. SherpaModelCatalogNotifier

A `keepAlive` Riverpod notifier that owns the user-facing model catalog and download lifecycle. This is the single provider the UI interacts with for model management — it wraps `SherpaModelManager` and adds reactive download-state tracking.

```
+------------------------------------------------------------------+
| SherpaModelCatalogNotifier                                       |
| state: SherpaModelCatalogState                                   |
+------------------------------------------------------------------+
| - _manager: SherpaModelManager                                   |
| - _activeDownloads: Map<String, StreamSubscription>              |
+------------------------------------------------------------------+
| + startDownload(modelId): void                                   |
| + cancelDownload(modelId): void                                  |
| + deleteModel(modelId): Future<void>                             |
| + refresh(): Future<void>                                        |
+------------------------------------------------------------------+
```

### SherpaModelCatalogState

```dart
@freezed
class SherpaModelCatalogState with _$SherpaModelCatalogState {
  const factory SherpaModelCatalogState({
    /// Full catalog (downloaded + available to download).
    @Default([]) List<SherpaModelInfo> models,

    /// In-progress downloads keyed by modelId.
    @Default({}) Map<String, SherpaModelDownloadProgress> activeDownloads,

    /// modelId of the last download that failed, if any.
    String? lastFailedDownloadId,
  }) = _SherpaModelCatalogState;
}
```

### Behavior

| Method | Behavior |
|--------|----------|
| `build()` | Calls `_manager.catalogModels()` and sets initial state. `activeDownloads` starts empty. If the cache is stale, `catalogModels()` returns the stale list immediately and triggers a background revalidation; when the fresh response arrives, `SherpaModelCatalogNotifier` rebuilds with the updated catalog. |
| `startDownload(modelId)` | No-op if `activeDownloads` already contains `modelId` (BR-U2-38). Subscribes to `_manager.downloadModel(modelId)`. On each progress event, updates `activeDownloads[modelId]`. On completion: removes from `activeDownloads`, calls `refresh()`, triggers engine registration if first model (BR-U2-36). On error: sets `lastFailedDownloadId`. |
| `cancelDownload(modelId)` | Cancels the subscription in `_activeDownloads[modelId]`, calls `_manager.cancelDownload(modelId)`, removes from `activeDownloads` (BR-U2-37). |
| `deleteModel(modelId)` | Calls `_manager.deleteModel(modelId)`, then `refresh()`. If `downloadedModels` becomes empty after deletion, unregisters `SherpaOnnxSttEngine` from `SttEngineRegistry`. |
| `refresh()` | Re-fetches catalog from `_manager.catalogModels()` and updates `state.models`. Preserves `activeDownloads`. |

### Engine Registration on First Download (BR-U2-36)

```
startDownload completes successfully
    |
    v
_manager.downloadedModels.length == 1  (first model)
    |
    v
ref.read(sttEngineRegistryProvider).register(SherpaOnnxSttEngine)
    |
    v
SherpaOnnxSttEngine.isAvailable() now returns true
    |
    v
UI: engine becomes selectable; "Start" no longer triggers engineRequiresModelDownload
```

### User Path: Engine Selected, No Models Downloaded

```
User selects 'sherpa-onnx' engine
    |
    v
activeEngineIdProvider = 'sherpa-onnx'
    |
    v
UI observes SherpaModelCatalogNotifier
    ├── models not empty, some isDownloaded == true → engine usable, show locale picker
    └── all isDownloaded == false → show model required prompt
              |
              v
         User opens model catalog screen
              |
              v
         SherpaModelCatalogNotifier.state.models displayed
         (name, size, download button per entry)
              |
              v
         User taps Download on a model
              |
              v
         startDownload(modelId)
              |
              v
         Progress bar updates via activeDownloads[modelId]
              |
              v
         Download complete → refresh() → model.isDownloaded = true
              |
              v
         Engine registered in SttEngineRegistry
              |
              v
         User returns to main screen → Start now succeeds
```

If the user taps "Start" before downloading any model, `SttSessionManager.initialize()` raises `RecordingErrorFactories.engineRequiresModelDownload()` as a safety net (BR-U2-29). The UI can read `lastError` and navigate to the model catalog screen.

---

## 8. RecordingStateNotifier — Unit 2 Updates

`RecordingStateNotifier` gains explicit calls to `SttSessionManager` and `WakeLockService` on state transitions. The notifier does not call the STT engine directly.

### Updated `build()`

```dart
@override
RecordingState build() {
  _captionBus = ref.read(captionBusProvider);
  _sessionManager = ref.read(sttSessionManagerProvider);
  _wakeLockService = ref.read(wakeLockServiceProvider);
  return const RecordingState.idle();
}
```

### Updated `start()`

```dart
Future<void> start({String? localeId}) async {
  if (state is! IdleState) return;
  _lastError = null;

  final resolvedLocale = ref.read(resolvedLocaleIdProvider);
  final activeEngineId = ref.read(activeEngineIdProvider);

  final ok = await _sessionManager.initialize(
    engineId: activeEngineId ?? 'platform',
    localeId: resolvedLocale,
    onResult: handleSttResult,
    onError: (error) {
      _lastError = error;
      // State remains idle — engine did not start
    },
  );
  if (!ok) return;

  final started = await _sessionManager.startListening();
  if (!started) return;

  final sessionId = const Uuid().v4();
  state = RecordingState.recording(sessionId: sessionId);
  _captionBus.publish(SessionStateEvent(state));
  await _wakeLockService.acquire();
}
```

### Updated Transition Methods

| Method | STT call | Wake lock call |
|--------|----------|----------------|
| `pause()` | `_sessionManager.pause()` | `_wakeLockService.onPause()` |
| `resume()` | `_sessionManager.resume()` | `_wakeLockService.acquire()` |
| `stop()` | `_sessionManager.stop()` | `_wakeLockService.release()` |

### `handleSttResult` (public, unchanged contract)

The method signature is unchanged from Unit 1. It is passed as `onResult` to `SttSessionManager.initialize()`.

---

## 9. Provider Layer — New and Updated Providers

### New Providers in zip_core

| Provider | Type | keepAlive | Purpose |
|----------|------|-----------|---------|
| `sttSessionManagerProvider` | `Provider<SttSessionManager>` | Yes | Singleton session manager |
| `audioDeviceServiceProvider` | `Provider<AudioDeviceService>` | Yes | Platform audio device service |
| `wakeLockServiceProvider` | `Provider<WakeLockService>` | Yes | Wake lock service |
| `wakeLockSettingsProvider` | `Notifier<WakeLockSettings>` | Yes | SharedPreferences-backed wake lock settings |
| `sherpaModelManagerProvider` | `Provider<SherpaModelManager>` | Yes | Model catalog, download, storage |
| `sherpaModelCatalogProvider` | `Notifier<SherpaModelCatalogState>` | Yes | User-facing catalog + download lifecycle; drives model picker UI |
| `activeEngineIdProvider` | `Notifier<String?>` | Yes | User-selected engine ID (persisted) |
| `activeLocaleIdProvider` | `Notifier<String?>` | Yes | User-selected locale ID (persisted) |
| `resolvedLocaleIdProvider` | `Provider<String>` | Yes | Locale fallback resolution (see §9) |
| `localeInfoProvider` | Updated `Provider<List<SpeechLocale>>` | Yes | Reads from active engine's `supportedLocales()` |

### Updated Providers

| Provider | Unit 1 State | Unit 2 Change |
|----------|-------------|---------------|
| `sttEngineProvider` | Throws `UnimplementedError` | Returns engine from registry by `activeEngineIdProvider`. Falls back to `registry.defaultEngine`. |
| `localeInfoProvider` | Returns `[]` stub | Reads `sttEngineProvider` and calls `engine.supportedLocales()`. Returns `[]` if no engine available. |

### New Provider in zip_broadcast (Q5=B)

| Provider | Type | keepAlive | Purpose |
|----------|------|-----------|---------|
| `audioInputSettingsProvider` | `Notifier<List<AudioInputConfig>>` | Yes | CRUD for multi-input config list. Defaults to single system-default mic. |

---

## 10. Locale Resolution — activeEngineIdProvider + resolvedLocaleIdProvider (Q7=B)

### Provider Chain

```
activeEngineIdProvider (Notifier<String?>) — user selection, persisted
    |
    v
sttEngineProvider (Provider<SttEngine?>) — resolved engine from registry
    |
    v
localeInfoProvider (Provider<List<SpeechLocale>>) — supportedLocales() for active engine
    |
    v
activeLocaleIdProvider (Notifier<String?>) — user locale selection, persisted
    |
    v
resolvedLocaleIdProvider (Provider<String>) — fallback logic → final locale ID
```

### Fallback Logic in `resolvedLocaleIdProvider`

```
activeLocaleId = ref.watch(activeLocaleIdProvider)  // may be null
supportedLocales = ref.watch(localeInfoProvider)

if activeLocaleId == null:
    → return supportedLocales.first?.localeId ?? 'en-US'

if supportedLocales contains exact match for activeLocaleId:
    → return activeLocaleId

if supportedLocales contains language match (e.g., 'en' prefix):
    → return first language match

if supportedLocales is empty:
    → return activeLocaleId  // engine may handle it internally

throw RecordingError.localeNotSupported(activeLocaleId)
    (via _lastError on RecordingStateNotifier — not here in the provider)
```

**Note**: The provider returns a `String`. The `localeNotSupported` error is not thrown from the provider — it is raised inside `SttSessionManager.initialize()` when `startListening` fails due to locale. The provider provides the best-effort locale to try.

### Engine Change Handling

When `activeEngineIdProvider` changes:
1. `sttEngineProvider` rebuilds → new engine reference
2. `localeInfoProvider` rebuilds → new locale list from new engine
3. `resolvedLocaleIdProvider` rebuilds → applies fallback against new list
4. UI re-renders with updated locale options

If a session is active when the engine changes, the change takes effect on the next `start()` — the running session is not interrupted.

---

## 11. AudioInputSettingsProvider (zip_broadcast — Q5=B shell)

Manages a persisted list of `AudioInputConfig` entries for Zip Broadcast's multi-input audio configuration. Unit 2 delivers the provider shell with single-input defaults; multi-engine wiring is deferred to Unit 6.

```dart
@Riverpod(keepAlive: true)
class AudioInputSettingsNotifier extends _$AudioInputSettingsNotifier {
  static const _key = 'audio_input.configs';

  @override
  List<AudioInputConfig> build() {
    // Load from SharedPreferences. Default: single config with system default mic.
    return _loadFromPrefs() ?? [AudioInputConfig.defaultMic()];
  }

  Future<void> addConfig(AudioInputConfig config) async { ... }
  Future<void> removeConfig(String configId) async { ... }
  Future<void> updateConfig(AudioInputConfig config) async { ... }
  Future<void> reorderConfigs(List<String> orderedIds) async { ... }
}
```

**Scope boundary**: This provider stores and retrieves configs. It does not instantiate `SttEngine` instances. The mapping from `AudioInputConfig` to live engine instances is Unit 6 work.

---

## 12. Provider Dependency Map

```
SharedPreferencesProvider (existing)
    |
    +---> WakeLockSettingsProvider
    +---> ActiveEngineIdProvider
    +---> ActiveLocaleIdProvider
    +---> AudioInputSettingsNotifier (zip_broadcast)

SttEngineRegistryProvider (Unit 1)
    |
    +---> SttEngineProvider  [updated: reads activeEngineId from registry]
              |
              v
         LocaleInfoProvider  [updated: calls engine.supportedLocales()]
              |
              v
         ResolvedLocaleIdProvider  [new: fallback resolution]

SherpaModelManagerProvider  [new]
    |
    +---> SherpaOnnxSttEngine (injected at construction)
    |
    +---> SherpaModelCatalogProvider  [new]
              (wraps manager; owns download subscriptions;
               writes back to SttEngineRegistryProvider on first download)

AudioDeviceServiceProvider  [new]
    |
    +---> PlatformSttEngine (injected)
    +---> SherpaOnnxSttEngine (injected)

WakeLockServiceProvider  [new]
    |
    +---> RecordingStateNotifier (ref.read in build)

SttSessionManagerProvider  [new]
    |
    +---> RecordingStateNotifier (ref.read in build)

RecordingStateNotifier  [updated]
    reads: CaptionBusProvider, SttSessionManagerProvider,
           WakeLockServiceProvider, ResolvedLocaleIdProvider,
           ActiveEngineIdProvider
```
