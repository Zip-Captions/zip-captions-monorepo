# Tech Stack Decisions — Unit 2: Platform STT + Audio

## New Runtime Dependencies

### record (runtime) — Q1=A

| Attribute | Detail |
|-----------|--------|
| **Package** | `record` |
| **Purpose** | Audio device enumeration (`listInputDevices()`) and PCM audio streaming from the selected input device into `SherpaOnnxSttEngine` |
| **Version** | Latest stable (`^5.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Fulfils Q2=D requirement: a single package that both enumerates audio input devices and honours device selection. `listInputDevices()` returns platform device IDs that map directly to `AudioDevice.deviceId`. `AudioRecorder.start()` accepts a device ID parameter. No custom platform channel needed. Supports iOS, macOS, Android, Windows, Linux. |

**Usage boundary**: `record` is used solely for device enumeration and as the audio source for `SherpaOnnxSttEngine`. `PlatformSttEngine` uses `speech_to_text`'s own audio capture. The `AudioDeviceService` implementation wraps `record`'s device listing and passes the device ID to `PlatformSttEngine` via OS-level routing (AVAudioSession / WASAPI device selection).

---

### speech_to_text (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `speech_to_text` |
| **Purpose** | `PlatformSttEngine` — wraps OS speech recognition (iOS/macOS SFSpeechRecognizer, Android SpeechRecognizer, Windows WinRT SpeechRecognizer) |
| **Version** | Latest stable (`^7.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Recommended by Spike 1.1. Provides `SpeechToText` with `initialize()`, `listen()`, `stop()`, and `locales()`. Tier 1 platform coverage. |

---

### sherpa_onnx (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `sherpa_onnx` |
| **Purpose** | `SherpaOnnxSttEngine` — streaming on-device ASR using the Zipformer/LSTM ONNX model |
| **Version** | Latest stable (`^1.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Confirmed viable by Spike 1.3. `OnlineRecognizer` API maps directly to `SttEngine.startListening()` contract. Primary engine for Tier 2 platforms (Windows/Linux); available on all platforms. |

**Adapter pattern**: Because `OnlineRecognizer` is a native FFI class not mockable in unit tests, a thin `OnlineRecognizerAdapter` interface is introduced in production code. `SherpaOnnxSttEngine` depends on `OnlineRecognizerAdapter`, not `OnlineRecognizer` directly. The real implementation passes through to `OnlineRecognizer`; the test implementation is a mock.

---

### permission_handler (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `permission_handler` |
| **Purpose** | Microphone permission status check and request in `SttSessionManager.initialize()` |
| **Version** | Latest stable (`^11.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Cross-platform permission API. Provides `Permission.microphone.status`, `Permission.microphone.request()`, and `openAppSettings()` (used by `RecordingStateNotifier.openMicrophoneSettings()`). Handles `denied`, `permanentlyDenied`, `undetermined`, `granted` states across all platforms. |

---

### wakelock_plus (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `wakelock_plus` |
| **Purpose** | `WakeLockService` — keep screen on during captioning sessions |
| **Version** | Latest stable (`^1.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Lightweight wrapper around platform screen wake lock APIs. Supports iOS, macOS, Android, Windows, Linux. Called explicitly from `RecordingStateNotifier` on state transitions (established explicit side-effect pattern). |

---

### dio (runtime) — Q2=B

| Attribute | Detail |
|-----------|--------|
| **Package** | `dio` |
| **Purpose** | HTTP client for catalog JSON fetch and model archive download with progress streaming |
| **Version** | Latest stable (`^5.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Preferred over `http` for three reasons: (1) built-in download progress via `onReceiveProgress` callback maps directly to `SherpaModelDownloadProgress` stream; (2) `CancelToken` supports `cancelDownload()` cleanly; (3) `Options(headers: {'Range': ...})` for resumable downloads is ergonomic. `dio` also provides `connectTimeout`/`receiveTimeout` for catalog fetch timeout (PERF-U2.3). |

**dio instance configuration**:
```dart
Dio(BaseOptions(
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 10),
  // HTTPS enforcement: validated per-request before initiating
))
```

---

### archive (runtime) — Q3=A

| Attribute | Detail |
|-----------|--------|
| **Package** | `archive` |
| **Purpose** | Extract `.tar.bz2` model archives after download in `SherpaModelManager` |
| **Version** | Latest stable (`^3.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Pure Dart implementation — no native code, works on all platforms. Supports `TarDecoder` + `BZip2Decoder` required for the upstream Sherpa-ONNX `.tar.bz2` distribution format. Avoids re-packaging models into a different archive format on the CDN. |

**Extraction flow**:
```
download file → sha256 verify → BZip2Decoder → TarDecoder
    → write each entry to _storageDir/{modelId}/{entryName}
```

---

### path_provider (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `path_provider` |
| **Purpose** | Resolve `getApplicationSupportDirectory()` for model storage root |
| **Version** | Latest stable (`^2.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Standard Flutter package for platform-appropriate storage paths. App support directory is persistent across app updates and not eligible for OS cache eviction — correct for model storage (MAINT, AVAIL-U2.2). |

---

### crypto (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `crypto` |
| **Purpose** | SHA-256 checksum computation for model archive integrity verification (SEC-U2.4) |
| **Version** | Latest stable (`^3.x`) |
| **Target** | `zip_core` `dependencies` |
| **Rationale** | Dart team maintained. Provides `sha256.convert(bytes)` for post-download archive verification against `SherpaModelCatalogEntry.sha256Checksum`. Minimal footprint; pure Dart. |

---

## New Dev Dependencies

### http_mock_adapter (dev)

| Attribute | Detail |
|-----------|--------|
| **Package** | `http_mock_adapter` |
| **Purpose** | Mock `dio` HTTP responses in `SherpaModelManager` unit tests |
| **Version** | Latest stable compatible with dio `^5.x` |
| **Target** | `zip_core` `dev_dependencies` |
| **Rationale** | `DioAdapter` allows defining response fixtures (catalog JSON, 206 partial, 200 restart, network error) without a real HTTP server. Enables TEST-U2.5 scenarios cleanly. |

---

## Existing Dependencies — No Change

| Package | Role in Unit 2 |
|---------|---------------|
| `flutter_riverpod` / `riverpod_annotation` | All new providers (`SttSessionManagerProvider`, `SherpaModelCatalogNotifier`, etc.) |
| `freezed_annotation` / `freezed` | `SherpaModelCatalogResponse`, `SherpaModelCatalogEntry`, `SherpaModelInfo`, `SherpaModelDownloadProgress`, `WakeLockSettings`, `SherpaModelCatalogState` |
| `shared_preferences` | `WakeLockSettingsProvider`, `activeEngineIdProvider`, `activeLocaleIdProvider`, `AudioInputSettingsNotifier`, catalog cache metadata (`cachedAt`, `etag`) |
| `uuid` | Unchanged — `sessionId` generation in `RecordingStateNotifier` |
| `logging` | All new Unit 2 components use `'zip_core.{ComponentName}'` convention |
| `glados` | PBT generators for locale strings, model IDs, device IDs |
| `mocktail` | Mocks for `SpeechToText`, `OnlineRecognizerAdapter`, `AudioDeviceService`, `WakeLockService`, `SttSessionManager` |

---

## Catalog Endpoint (Q10=C)

### Phase 1: Static JSON on CDN

| Attribute | Detail |
|-----------|--------|
| **Type** | Static JSON file |
| **Hosting** | CDN (e.g., Cloudflare Pages, GitHub Releases, or similar) |
| **Update process** | Manual — file is updated when models are added/removed |
| **URL constant** | Dart compile-time constant in `lib/src/constants/catalog_constants.dart` |
| **Cache headers** | `Cache-Control: public, max-age=86400, stale-while-revalidate=3600` |
| **Format** | `SherpaModelCatalogResponse` JSON schema (schemaVersion + models array) |

**Phase 2 (deferred)**: A dynamic server-side proxy that aggregates model metadata from HuggingFace and other sources automatically. The app's `catalogModels()` implementation does not change — only the URL constant and the server behind it.

---

## Package Summary

### zip_core — New runtime dependencies

```yaml
dependencies:
  record: ^5.0.0
  speech_to_text: ^7.0.0
  sherpa_onnx: ^1.0.0
  permission_handler: ^11.0.0
  wakelock_plus: ^1.0.0
  dio: ^5.0.0
  archive: ^3.0.0
  path_provider: ^2.0.0
  crypto: ^3.0.0
```

### zip_core — New dev dependencies

```yaml
dev_dependencies:
  http_mock_adapter: ^0.6.0  # compatible with dio ^5.x
```

### zip_broadcast — No new dependencies

`zip_broadcast` adds `AudioInputSettingsNotifier` (shell) using existing `flutter_riverpod`, `shared_preferences`, and `freezed_annotation` from the workspace.
