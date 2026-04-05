# Business Rules — Unit 2: Platform STT + Audio

## STT Engine Rules

### BR-U2-01: Engine Selection Precedence

The active engine is resolved in this order:
1. `activeEngineIdProvider` value if the engine is registered in `SttEngineRegistry`
2. `SttEngineRegistry.defaultEngine` (first registered engine, insertion order)
3. `null` — `start()` returns without transitioning state

`RecordingStateNotifier.start()` does not attempt to start if no engine is available.

### BR-U2-02: Engine Properties are Static

`PlatformSttEngine.engineId = 'platform'`, `SherpaOnnxSttEngine.engineId = 'sherpa-onnx'`. These values are constants. An engine may not change its `engineId` after construction.

### BR-U2-03: SherpaOnnxSttEngine Availability Requires a Downloaded Model

`SherpaOnnxSttEngine.isAvailable()` returns `false` if `SherpaModelManager.downloadedModels` is empty. The engine must not be passed to `SttSessionManager.initialize()` when unavailable.

### BR-U2-04: Engine Registration Order on App Startup

Engines are registered into `SttEngineRegistry` at app startup before any provider reads the registry:
- `PlatformSttEngine` is always registered (Tier 1 platforms: iOS, macOS, Android, Windows)
- `SherpaOnnxSttEngine` is registered when at least one model is downloaded (all platforms)
- If `PlatformSttEngine.isAvailable()` is false (Linux), it is not registered

---

## Permission Rules (Q6=A)

### BR-U2-05: Permission Is Checked Exactly Once Per Start Attempt

Microphone permission is checked inside `SttSessionManager.initialize()`, not at app launch, not in any provider `build()`, and not at UI construction time.

### BR-U2-06: `denied` Is Re-Requestable; `permanentlyDenied` Is Not

`denied` and `permanentlyDenied` are treated differently:

- **`denied`**: `request()` is called again. The OS may show the dialog. If the user grants, initialization proceeds. If denied again (including escalation to `permanentlyDenied`), `RecordingErrorFactories.permissionDenied()` or `permissionPermanentlyDenied()` is raised.
- **`permanentlyDenied`**: `request()` is not called. `RecordingErrorFactories.permissionPermanentlyDenied()` is raised immediately. The UI must show an "Open Settings" affordance.

**Re-trigger for `denied`**: The user taps "Start" again — `initialize()` re-checks and re-requests. No separate retry mechanism is needed.

**Re-trigger for `permanentlyDenied`**: `RecordingStateNotifier.openMicrophoneSettings()` calls `permission_handler`'s `openAppSettings()`. After the user grants permission in system Settings and returns, tapping "Start" again proceeds normally.

### BR-U2-07: Permission Errors Surface via `_lastError`

`RecordingStateNotifier._lastError` is set when permission is denied or permanently denied. `RecordingState` does not gain an error variant — state remains `idle`. The UI reads `RecordingStateNotifier.lastError` to decide whether to show "Try Again" (for `permissionDenied`) or "Open Settings" (for `permissionPermanentlyDenied`).

---

## Locale Rules (Q7=B)

### BR-U2-08: Locale Must Be Non-Empty Before Start

`resolvedLocaleIdProvider` always returns a non-empty string. If all fallbacks fail and the engine's locale list is empty, it returns `'en-US'` as the last-resort default. `SttSessionManager.initialize()` is never called with an empty locale.

### BR-U2-09: Locale Fallback Priority

When `activeLocaleId` is set but not supported by the active engine:
1. Exact BCP-47 match (e.g., `en-US` == `en-US`)
2. Language-only match (e.g., `en-US` → first `en-*` locale in `supportedLocales`)
3. Engine default (first locale in `supportedLocales`)
4. `localeNotSupported` error raised by `SttSessionManager.initialize()` (only if step 3 also unavailable)

### BR-U2-10: Locale Change Does Not Interrupt Active Session

Changing `activeLocaleIdProvider` while a session is recording does not stop the current session. The resolved locale is captured at `start()` time and used for the full session duration.

### BR-U2-11: Engine Change Does Not Interrupt Active Session

Changing `activeEngineIdProvider` while a session is active does not stop the session. The new engine takes effect on the next `start()` call.

---

## Wake Lock Rules (Q4=A)

### BR-U2-12: Wake Lock Acquired on Start, Released on Stop

`WakeLockService.acquire()` is called after `SttSessionManager.startListening()` succeeds. `WakeLockService.release()` is called in `stop()` regardless of whether the session started successfully.

### BR-U2-13: Pause Wake Lock Behaviour Is User-Configurable

When `WakeLockSettings.releaseOnPause` is `true` (default), the wake lock is released on `pause()`. When `false`, the screen stays on during pause. This setting is read at pause time from the current `WakeLockSettings` value.

### BR-U2-14: Wake Lock Is a No-Op When Disabled

When `WakeLockSettings.enabled` is `false`, `WakeLockService.acquire()` and `onPause()` are both no-ops. `release()` is always safe to call (no-op if not acquired).

### BR-U2-15: Wake Lock Settings Are Shared Across Apps

`WakeLockSettingsProvider` uses the fixed SharedPreferences key prefix `wake_lock` (not app-prefixed). `DisplaySettings` uses an app-specific prefix; wake lock settings do not.

---

## Audio Device Rules (Q2=D)

### BR-U2-16: Device Preference Applied Before STT Session

`AudioDeviceService.setPreferredInputDevice()` is called inside the engine's `startListening()` (or `initialize()`) before the audio session begins. The preference is not applied retroactively to an active session.

### BR-U2-17: System Default Is Always Available

`AudioDeviceService.listInputDevices()` always returns at least one entry with `isDefault: true`. If platform enumeration fails, a synthetic default entry is returned rather than an empty list.

### BR-U2-18: Device Preference Persisted Across Sessions

The preferred device ID is persisted to SharedPreferences under `audio.preferredInputDeviceId`. A null/absent value means "use system default."

---

## Catalog API Rules

### BR-U2-19: Model Catalog Is Fetched from an App-Operated Endpoint

`SherpaModelManager.catalogModels()` fetches from an app-operated catalog endpoint — not directly from an external source such as HuggingFace. The app endpoint acts as a stable, versioned proxy that aggregates and normalises model metadata from upstream sources. This shields the app from upstream API changes and allows the operator to control which models are surfaced.

**Security (SR-U2-03)**: The catalog endpoint URL is a compile-time app constant, not user-supplied.

### BR-U2-39: Catalog Endpoint Response Format

The endpoint returns `application/json` with the following shape (matching `SherpaModelCatalogResponse`):

```json
{
  "schemaVersion": "1",
  "models": [
    {
      "modelId": "sherpa-onnx-streaming-zipformer-en-20M-2023-02-17",
      "displayName": "English (20M, streaming)",
      "primaryLocaleId": "en-US",
      "downloadSizeBytes": 45000000,
      "downloadUrl": "https://cdn.example.com/models/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2",
      "sha256Checksum": "a3f1..."
    }
  ]
}
```

All six fields are required per entry. A response missing any required field for an entry causes that entry to be silently skipped (partial catalog displayed). A response with an unrecognised `schemaVersion` causes the client to fall back to the local cache and log a warning (no crash).

### BR-U2-40: Server-Side Aggressive Caching

The catalog endpoint must be served behind a CDN or HTTP cache layer with an aggressive cache policy, because model listings change infrequently (weeks to months) and direct upstream calls (e.g., to HuggingFace) on every client request would create unnecessary load and introduce upstream availability risk.

Required server-side behaviour:
- The upstream source (e.g., HuggingFace API) is queried by the server at most once per **24 hours**; the result is cached server-side.
- The endpoint emits `Cache-Control: public, max-age=86400, stale-while-revalidate=3600` (24 h max-age, 1 h stale-while-revalidate).
- The endpoint emits an `ETag` or `Last-Modified` header to support conditional requests.

### BR-U2-41: Client-Side Aggressive Cache — Stale-While-Revalidate

The app applies an additional client-side caching layer on top of HTTP caching:

| Scenario | Behaviour |
|----------|-----------|
| Cache fresh (< 24 h old) | Return cached catalog immediately; no network request. |
| Cache stale (≥ 24 h old), network available | Return cached catalog immediately (no UI delay), then fetch in background; update state when response arrives. |
| Cache stale, network unavailable | Return cached catalog with a staleness indicator; no error state. |
| No cache, network available | Fetch; display loading indicator until response arrives. |
| No cache, network unavailable | Return empty list; UI shows "Unable to load model catalog. Check your connection." |

The client cache is stored in the app support directory as a JSON file alongside the cached `schemaVersion` and a `cachedAt` timestamp. Cache is never evicted automatically — it is only replaced on a successful fetch.

### BR-U2-42: Client Uses HTTP Conditional Requests

When a cached response exists and its `ETag` or `Last-Modified` value is known, the client sends `If-None-Match` / `If-Modified-Since` on the background revalidation request. A `304 Not Modified` response updates the `cachedAt` timestamp without replacing the cached body, extending the freshness window without re-parsing the full response.

### BR-U2-43: Catalog Endpoint Requires HTTPS

All requests to the catalog endpoint must use HTTPS. HTTP URLs are rejected at the network layer. This applies to both the catalog fetch and all `downloadUrl` values returned by the catalog.

---

## SherpaModelManager Rules (Q1=A)

### BR-U2-20: Model Download Is an Exclusive Operation per Model

Only one concurrent download is permitted per `modelId`. A second `downloadModel(modelId)` call while a download is in progress returns the existing progress stream (or throws `StateError` — resolved at NFR Design).

### BR-U2-21: Model Storage Is Per-Platform App Support Directory

Models are stored in the app support directory (not documents, not cache). They survive app updates and are not eligible for OS cache eviction.

### BR-U2-22: bestModelForLocale Returns Null, Not an Error

If no downloaded model supports the requested locale (but at least one model is downloaded), `bestModelForLocale()` returns `null`. The caller (`SherpaOnnxSttEngine.initialize()`) handles null by returning `false`, causing `SttSessionManager` to raise `RecordingErrorFactories.engineInitFailed()`.

---

## Sherpa-ONNX Model Download Flow Rules

### BR-U2-29: No Downloaded Models → engineRequiresModelDownload, Not engineInitFailed

When `SherpaOnnxSttEngine` is the active engine and `isAvailable()` returns `false` (no models downloaded), `SttSessionManager.initialize()` raises `RecordingErrorFactories.engineRequiresModelDownload()` rather than `engineInitFailed`. This distinction allows the UI to navigate to the model download screen rather than showing a generic error.

`engineInitFailed` is reserved for cases where models are present but initialization still fails (corrupt model, native library error, etc.).

### BR-U2-30: Engine Availability Is Checked Before Initialization

`SttSessionManager.initialize()` calls `engine.isAvailable()` before `engine.initialize()`. If `isAvailable()` returns `false`, initialization aborts with `engineRequiresModelDownload`. `engine.initialize()` is never called when the engine is unavailable.

### BR-U2-31: Model Catalog Is Always Accessible Regardless of Engine Selection

`SherpaModelCatalogNotifier` is available even when `activeEngineIdProvider` is not `'sherpa-onnx'`. The catalog and download flow can be initiated from a settings screen at any time — not only when a start attempt has failed.

### BR-U2-32: Catalog Shows Both Downloaded and Available Models

`SherpaModelCatalogNotifier` exposes the full catalog list from `SherpaModelManager.catalogModels()`. Each entry carries `isDownloaded: true/false` so the UI can show:
- Downloaded models: selectable immediately, with a delete action
- Not-downloaded models: show download size, with a download action

### BR-U2-33: Download Is Initiated by the User, Not Automatically

No model is downloaded automatically. The user must explicitly select a model from the catalog and confirm the download. `SherpaModelCatalogNotifier.startDownload(modelId)` initiates the download and exposes progress via `activeDownloads`.

### BR-U2-34: Download Progress Is Tracked Per Model

`SherpaModelCatalogNotifier` maintains a map of `modelId → SherpaModelDownloadProgress` for all in-progress downloads. The UI observes this provider to render progress indicators. A model not in `activeDownloads` is either not downloading or already complete.

### BR-U2-35: Catalog Refreshes After Download Completes

When `SherpaModelManager.downloadModel()` stream closes (download complete), `SherpaModelCatalogNotifier` re-fetches the catalog from `SherpaModelManager.catalogModels()`. The catalog entry for the downloaded model will now have `isDownloaded: true`. The provider state updates automatically — no manual refresh required by the caller.

### BR-U2-36: Engine Registered After First Model Downloaded

When a download completes and `SherpaModelManager.downloadedModels` transitions from empty to non-empty, `SherpaOnnxSttEngine` is registered into `SttEngineRegistry` if not already present. This makes the engine selectable in the engine picker and causes `SherpaOnnxSttEngine.isAvailable()` to return `true` on the next `start()` attempt.

### BR-U2-37: Download Can Be Cancelled

An in-progress download may be cancelled by the user. `SherpaModelCatalogNotifier.cancelDownload(modelId)` aborts the HTTP download, deletes any partially written files, and removes the entry from `activeDownloads`. The catalog entry remains `isDownloaded: false`.

### BR-U2-38: Only One Download Per Model at a Time (Concurrent Downloads Permitted Across Models)

A second `startDownload(modelId)` call for a model already downloading is a no-op — it returns without starting a second stream. Downloads of different models may proceed concurrently.

---

## RecordingStateNotifier Rules — Unit 2 Additions

### BR-U2-23: start() Is Atomic — No Partial State on Failure

If `SttSessionManager.initialize()` or `startListening()` fails, `RecordingState` remains `idle`. `_lastError` is set. No intermediate state (e.g., `initializing`) is emitted.

### BR-U2-24: Error Does Not Block Subsequent start() Calls

After a failed `start()` (state stays `idle`, `_lastError` set), a subsequent `start()` clears `_lastError` and retries the full initialization sequence. No manual reset is required.

### BR-U2-25: stop() Is Always Safe

`RecordingStateNotifier.stop()` may be called from `recording` or `paused` states. In both cases, `_sessionManager.stop()` and `_wakeLockService.release()` are called. An extra `stop()` from `idle` or `stopped` is a no-op (guarded by state check inherited from Unit 1).

---

## AudioInputSettingsProvider Rules (Q5=B)

### BR-U2-26: Default Is Single System-Default Mic

On first run (no persisted state), `AudioInputSettingsNotifier` returns `[AudioInputConfig.defaultMic()]`. This single config represents the system-default microphone with no device ID override.

### BR-U2-27: Config List Must Have At Least One Entry

`removeConfig()` refuses to remove the last remaining config. The list must always have at least one entry.

### BR-U2-28: Config Persistence Is Synchronous on Read, Async on Write

`build()` reads persisted configs synchronously from SharedPreferences. Mutations (`addConfig`, `removeConfig`, `updateConfig`) persist asynchronously after updating the in-memory state.

---

## Security Rules

### SR-U2-01: No Transcript Text in Logs (SECURITY-03 — continued from Unit 1)

All Unit 2 components that handle `SttResult.text` or `SherpaOnnxSttEngine` recognizer output must never log, emit to analytics, or serialize transcript text to any log sink. This extends SR-01 from Unit 1.

**Permitted in logs**: engine ID, model ID, locale ID, device ID, session ID, error type, error message (which must not contain transcript text — see SR-U2-02).

### SR-U2-02: RecordingError.message Must Not Contain Transcript Text (SR-02 — continued)

All `RecordingErrorFactories` named constructors produce messages from static strings only. The `localeNotSupported(localeId)` constructor accepts a `localeId` parameter but does not include it in `message` (only the generic string is used).

### SR-U2-03: Model Download URL Is Not User-Supplied

The CDN URL used in `SherpaModelManager.downloadModel()` is derived from the bundled catalog, not from user input. No URL constructed from user-supplied data is used in network requests.

---

## Extension Compliance Summary

### Security Baseline

| Rule | Status | Notes |
|------|--------|-------|
| SECURITY-01 | N/A | No transcript database in Unit 2 |
| SECURITY-02 | N/A | No network intermediaries for captions |
| SECURITY-03 | **Compliant** | SR-U2-01 extends Unit 1 rule to all new components |
| SECURITY-04 | N/A | No HTTP endpoints in Unit 2 |
| SECURITY-05+ | N/A | Not applicable to Unit 2 scope |

### Property-Based Testing

| Rule | Status | Notes |
|------|--------|-------|
| PBT-01 | **Compliant** | Testable properties identified per component (see below) |
| PBT-02 | **Compliant** | Round-trip: `WakeLockSettings`, `SherpaModelInfo`, `AudioDevice` |
| PBT-03 | **Compliant** | Invariants identified for all major components |
| PBT-04 | **Compliant** | Idempotence: double `pause()`, double `stop()`, double `acquire()` |
| PBT-05 | N/A | No commutativity properties applicable |
| PBT-06 | **Compliant** | State machine properties extended for Unit 2 transitions |
| PBT-07+ | Deferred to NFR Design | Generator design for audio chunk streams, locale generators |

### Testable Properties (PBT)

#### SttSessionManager

| Property | Category | Description |
|----------|----------|-------------|
| Invariant | PBT-03 | After `stop()`, `activeEngine` is null |
| Idempotence | PBT-04 | Calling `stop()` twice does not raise; second call is no-op |
| Invariant | PBT-03 | `initialize()` returning false leaves `activeEngine` null |

#### WakeLockService

| Property | Category | Description |
|----------|----------|-------------|
| Idempotence | PBT-04 | `acquire()` called N times ≡ `acquire()` called once |
| Idempotence | PBT-04 | `release()` called N times does not error |
| Invariant | PBT-03 | With `enabled=false`, `acquire()` never enables wake lock |

#### SherpaModelManager

| Property | Category | Description |
|----------|----------|-------------|
| Invariant | PBT-03 | `downloadedModels` ⊆ `catalogModels()` |
| Invariant | PBT-03 | After `deleteModel(id)`, `bestModelForLocale()` never returns that model |
| Invariant | PBT-03 | `progressFraction` ∈ [0.0, 1.0] for all `SherpaModelDownloadProgress` instances |

#### Locale Resolution

| Property | Category | Description |
|----------|----------|-------------|
| Invariant | PBT-03 | `resolvedLocaleIdProvider` is never empty |
| Invariant | PBT-03 | Resolved locale is always a member of `supportedLocales` or the last-resort default |
| Invariant | PBT-03 | For any non-empty `supportedLocales`, exact match is preferred over language match |

#### RecordingStateNotifier (Unit 2 additions)

| Property | Category | Description |
|----------|----------|-------------|
| Invariant | PBT-03 | After a failed `start()`, state is `idle` and `_lastError` is non-null |
| Invariant | PBT-03 | After a successful `start()`, `_lastError` is null |
| Idempotence | PBT-04 | Calling `stop()` from `stopped` state is a no-op |
