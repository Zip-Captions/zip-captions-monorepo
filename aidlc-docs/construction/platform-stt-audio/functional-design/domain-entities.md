# Domain Entities — Unit 2: Platform STT + Audio

## New Models

### AudioDevice (freezed)

Represents a single enumerable audio input device available on the current platform.

```dart
@freezed
class AudioDevice with _$AudioDevice {
  const factory AudioDevice({
    /// Platform-specific device identifier.
    /// On iOS/macOS: AVAudioSession port UID.
    /// On Android: AudioDeviceInfo id (int as string).
    /// On Windows: WASAPI device ID string.
    /// On Linux: PulseAudio source name.
    required String deviceId,

    /// Human-readable name for display in the audio source selector.
    required String name,

    /// Whether this is the current system default input device.
    @Default(false) bool isDefault,
  }) = _AudioDevice;
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `deviceId` | `String` | Platform-opaque identifier passed to `AudioDeviceService.setPreferredInputDevice()` |
| `name` | `String` | Shown in the audio source picker UI |
| `isDefault` | `bool` | Flags the system default so it can be marked in the UI |

**Scope**: Microphone devices only in Unit 2. System audio (loopback) devices are added in Unit 6.

---

### SherpaModelCatalogResponse (freezed)

The deserialized response envelope from the model catalog endpoint. Parsed by `SherpaModelManager.catalogModels()` before merging with local filesystem state.

```dart
@freezed
class SherpaModelCatalogResponse with _$SherpaModelCatalogResponse {
  const factory SherpaModelCatalogResponse({
    /// Catalog schema version. Used to detect incompatible future formats.
    /// Current value: '1'.
    required String schemaVersion,

    /// List of models available for download.
    required List<SherpaModelCatalogEntry> models,
  }) = _SherpaModelCatalogResponse;

  factory SherpaModelCatalogResponse.fromJson(Map<String, dynamic> json) =>
      _$SherpaModelCatalogResponseFromJson(json);
}
```

---

### SherpaModelCatalogEntry (freezed)

A single model entry as returned by the catalog endpoint. Contains server-authoritative fields only — local state (`isDownloaded`, `localPath`) is not part of the API response; it is merged in by `SherpaModelManager`.

```dart
@freezed
class SherpaModelCatalogEntry with _$SherpaModelCatalogEntry {
  const factory SherpaModelCatalogEntry({
    /// Unique model identifier. Matches the sherpa-onnx model directory name.
    /// Example: 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17'
    required String modelId,

    /// Human-readable display name shown in the model picker.
    required String displayName,

    /// Primary BCP-47 locale this model was trained for.
    required String primaryLocaleId,

    /// Compressed archive size in bytes. Displayed before download starts.
    required int downloadSizeBytes,

    /// HTTPS URL of the model archive. Provided by the catalog; never
    /// constructed by the app from user input.
    required String downloadUrl,

    /// SHA-256 hex digest of the archive at downloadUrl.
    /// Verified after download completes before extraction.
    required String sha256Checksum,
  }) = _SherpaModelCatalogEntry;

  factory SherpaModelCatalogEntry.fromJson(Map<String, dynamic> json) =>
      _$SherpaModelCatalogEntryFromJson(json);
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `modelId` | `String` | Primary key; used as local storage directory name |
| `displayName` | `String` | Shown in model picker UI |
| `primaryLocaleId` | `String` | BCP-47 locale; used to map model to `SpeechLocale` |
| `downloadSizeBytes` | `int` | Pre-download size display |
| `downloadUrl` | `String` | Source URL for `SherpaModelManager.downloadModel()` |
| `sha256Checksum` | `String` | Archive integrity check post-download |

---

### SherpaModelInfo (freezed)

Merged view of a model: server catalog data + local filesystem state. Constructed by `SherpaModelManager` from `SherpaModelCatalogEntry` + filesystem check. This is what `SherpaModelCatalogNotifier` exposes to the UI.

```dart
@freezed
class SherpaModelInfo with _$SherpaModelInfo {
  const factory SherpaModelInfo({
    /// Unique model identifier matching the sherpa-onnx model directory name.
    /// Example: 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17'
    required String modelId,

    /// Human-readable display name.
    required String displayName,

    /// Primary BCP-47 locale this model was trained for.
    /// Used to map model to SpeechLocale.
    required String primaryLocaleId,

    /// Download size in bytes. Used to show download size before initiating.
    required int downloadSizeBytes,

    /// HTTPS URL of the model archive (from catalog).
    required String downloadUrl,

    /// SHA-256 hex digest of the archive (from catalog). Verified post-download.
    required String sha256Checksum,

    /// Whether this model has been downloaded and is available for use.
    @Default(false) bool isDownloaded,

    /// Local path to the model directory, if downloaded.
    String? localPath,
  }) = _SherpaModelInfo;
}
```

**Relationship**: `SherpaModelInfo = SherpaModelCatalogEntry fields + isDownloaded + localPath`. The catalog entry is the source of truth for server fields; local state is derived from filesystem.

---

### WakeLockSettings (freezed)

User preferences for screen wake lock behavior during captioning.

```dart
@freezed
class WakeLockSettings with _$WakeLockSettings {
  const factory WakeLockSettings({
    /// Whether the wake lock feature is enabled at all.
    @Default(true) bool enabled,

    /// Whether the wake lock is released when captioning is paused.
    /// When false, the screen stays on even when paused.
    @Default(true) bool releaseOnPause,
  }) = _WakeLockSettings;
}
```

Persisted via SharedPreferences under prefix `wake_lock` (e.g., `wake_lock.enabled`, `wake_lock.releaseOnPause`). Shared across both apps using the same key prefix — each app's `BaseSettingsNotifier` subclass uses its own app-level prefix for `DisplaySettings`, but `WakeLockSettingsProvider` is a shared zip_core provider with a fixed key prefix.

---

### SherpaModelDownloadProgress (freezed)

Represents the in-progress state of a model download. Emitted by `SherpaModelManager` as a stream during `downloadModel()`.

```dart
@freezed
class SherpaModelDownloadProgress with _$SherpaModelDownloadProgress {
  const factory SherpaModelDownloadProgress({
    /// The model being downloaded.
    required String modelId,

    /// Bytes received so far.
    required int bytesDownloaded,

    /// Total bytes to download (from Content-Length header).
    /// Zero if the server did not provide Content-Length.
    required int totalBytes,
  }) = _SherpaModelDownloadProgress;

  const SherpaModelDownloadProgress._();

  /// Progress fraction in [0.0, 1.0]. Returns 0.0 if totalBytes is zero.
  double get progressFraction =>
      totalBytes > 0 ? (bytesDownloaded / totalBytes).clamp(0.0, 1.0) : 0.0;
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `modelId` | `String` | Identifies which model is being downloaded |
| `bytesDownloaded` | `int` | Used to compute progress bar fill and ETA |
| `totalBytes` | `int` | `0` when server does not provide `Content-Length` |
| `progressFraction` | `double` | Derived — convenience for UI progress indicators |

**Scope**: Emitted by `SherpaModelManager.downloadModel()` as a `Stream<SherpaModelDownloadProgress>`. Not persisted. Not used on platforms where Sherpa-ONNX is unavailable.

---

## Modified Models

### RecordingError — Named Factory Constructors

`RecordingError` gains named factory constructors for the specific error types that can arise from Unit 2's engine start flow. The underlying freezed structure is unchanged (message, severity, timestamp).

```dart
// New named constructors added to RecordingError
extension RecordingErrorFactories on RecordingError {
  /// Microphone permission was denied at the OS prompt (re-requestable).
  /// The user can retry by attempting to start captioning again.
  static RecordingError permissionDenied() => RecordingError(
    message: 'Microphone access denied. Enable it in system Settings.',
    severity: RecordingErrorSeverity.fatal,
    timestamp: DateTime.now(),
  );

  /// Microphone permission is permanently blocked (user ticked "Don't ask again"
  /// or denied twice on iOS). OS will not show the dialog again — user must
  /// go to system Settings. UI should show an "Open Settings" affordance.
  static RecordingError permissionPermanentlyDenied() => RecordingError(
    message: 'Microphone access is blocked. Enable it in system Settings.',
    severity: RecordingErrorSeverity.fatal,
    timestamp: DateTime.now(),
  );

  /// The selected engine (Sherpa-ONNX) has no downloaded models.
  /// The user must download at least one model before captioning can start.
  /// UI should navigate to the model catalog screen.
  static RecordingError engineRequiresModelDownload() => RecordingError(
    message: 'No speech model downloaded. Please download a model to continue.',
    severity: RecordingErrorSeverity.fatal,
    timestamp: DateTime.now(),
  );

  /// The STT engine failed to initialize for a non-permission reason
  /// (e.g., engine binary missing, model corrupt, platform error).
  static RecordingError engineInitFailed() => RecordingError(
    message: 'Speech recognition engine failed to initialize.',
    severity: RecordingErrorSeverity.fatal,
    timestamp: DateTime.now(),
  );

  /// The STT engine initialized but failed to start listening
  /// (e.g., audio hardware unavailable, session conflict).
  static RecordingError engineStartFailed() => RecordingError(
    message: 'Failed to start speech recognition.',
    severity: RecordingErrorSeverity.fatal,
    timestamp: DateTime.now(),
  );

  /// The selected locale is not supported by the active engine,
  /// and no language-level fallback was available.
  static RecordingError localeNotSupported(String localeId) => RecordingError(
    message: 'Language not supported by the selected engine.',
    severity: RecordingErrorSeverity.fatal,
    timestamp: DateTime.now(),
  );
}
```

**Security (SR-02)**: The `localeId` parameter is not included in the message — only the generic description.

---

## Existing Models — No Change in Unit 2

| Model | Status |
|-------|--------|
| `SttResult` | Unchanged |
| `CaptionEvent` / `SttResultEvent` / `SessionStateEvent` | Unchanged |
| `AudioInputConfig` | Unchanged — `sourceDeviceId` field already maps to `AudioDevice.deviceId` |
| `AudioInputVisualStyle` | Unchanged |
| `RecordingState` (sealed) | Unchanged — no error variant added; errors surface via `RecordingStateNotifier._lastError` |
| `SpeechLocale` | Unchanged |
| `DisplaySettings` | Unchanged |
| `RecordingErrorSeverity` | Unchanged |
