# Code Summary — Unit 2: Platform STT + Audio

## Stories Implemented

- **S-02**: Platform-Native STT (PlatformSttEngine, SherpaOnnxSttEngine, SttSessionManager)
- **S-06**: Audio Capture (AudioDeviceService, AudioInputSettings, wake lock)

## Verification Results

| Check | Result |
|-------|--------|
| `build_runner build` | Successful (freezed + riverpod + json_serializable codegen) |
| `dart analyze` (zip_core) | 0 errors, 0 warnings, 104 infos (style only) |
| `flutter test` (zip_core) | 247 tests passed, 0 failures |

## Files Created

### Models (`packages/zip_core/lib/src/models/`)

| File | Type | Purpose |
|------|------|---------|
| `audio_device.dart` | freezed + JSON | Audio input device with platform ID and display name |
| `wake_lock_settings.dart` | freezed + JSON | User preferences for screen wake lock (enabled, releaseOnPause) |
| `recording_error_factories.dart` | extension | Named factories for common RecordingError instances |
| `speech_locale.dart` | freezed | Locale descriptor with computed `languageCode` getter |
| `sherpa_model_catalog.dart` | freezed + JSON | Catalog response and entry models for Sherpa-ONNX models |
| `sherpa_model_catalog_state.dart` | freezed | Reactive state for catalog UI (models, downloads, pending confirmation) |
| `sherpa_model_info.dart` | freezed + JSON | Merged view of catalog data + local filesystem state |
| `sherpa_model_download_progress.dart` | freezed + JSON | Download progress tracking (bytes, total, model ID) |

### STT Engines (`packages/zip_core/lib/src/stt/engines/`)

| File | Type | Purpose |
|------|------|---------|
| `platform_stt_engine.dart` | SttEngine impl | Wraps SpeechToText for Tier 1 platforms (iOS/macOS/Android/Windows) |
| `sherpa_onnx_stt_engine.dart` | SttEngine impl | Wraps Sherpa-ONNX for Tier 2 platforms (Windows/Linux primary) |

### STT Adapters (`packages/zip_core/lib/src/stt/adapters/`)

| File | Type | Purpose |
|------|------|---------|
| `online_recognizer_adapter.dart` | abstract interface | Test seam for sherpa_onnx OnlineRecognizer |
| `sherpa_online_recognizer_adapter.dart` | production impl | Pass-through to real Sherpa native class (coverage excluded) |

### Services (`packages/zip_core/lib/src/services/`)

| File | Type | Purpose |
|------|------|---------|
| `stt/stt_session_manager.dart` | plain Dart | Full STT session lifecycle: permission, init, listen, pause, resume, stop, recovery |
| `audio/audio_device_service.dart` | abstract interface | Audio input device enumeration and selection |
| `wake_lock/wake_lock_service.dart` | abstract interface | Screen wake lock acquire/release/onPause contract |
| `wake_lock/wakelock_plus_service.dart` | production impl | Delegates to WakelockPlus static API |
| `catalog/sherpa_model_manager.dart` | plain Dart | Sherpa model lifecycle: catalog fetch, download, verify, delete, locale mapping |
| `catalog/catalog_cache.dart` | plain Dart | Stale-while-revalidate caching for model catalog with etag/lastModified |
| `catalog/model_integrity_exception.dart` | exception | SHA-256 checksum verification failure |

### Providers (`packages/zip_core/lib/src/providers/`)

| File | Type | Purpose |
|------|------|---------|
| `active_engine_id_provider.dart` | keepAlive notifier | User-selected STT engine ID (SharedPreferences-backed) |
| `active_locale_id_provider.dart` | keepAlive notifier | User-selected speech locale ID (SharedPreferences-backed) |
| `resolved_locale_id_provider.dart` | keepAlive | Resolves active locale via fallback chain (exact > language > first > en-US) |
| `stt_session_manager_provider.dart` | keepAlive | Factory for SttSessionManager |
| `wake_lock_service_provider.dart` | keepAlive | Factory for WakeLockService |
| `wake_lock_settings_provider.dart` | keepAlive notifier | Wake lock settings (SharedPreferences-backed) |
| `audio_device_service_provider.dart` | keepAlive | Factory for AudioDeviceService |
| `sherpa_model_catalog_provider.dart` | keepAlive notifier | Model catalog + download lifecycle state |
| `sherpa_model_manager_provider.dart` | keepAlive | Factory for SherpaModelManager with Dio |

### Constants (`packages/zip_core/lib/src/constants/`)

| File | Purpose |
|------|---------|
| `catalog_constants.dart` | Compile-time constants for catalog URL, freshness thresholds |

### zip_broadcast (`packages/zip_broadcast/lib/src/providers/`)

| File | Type | Purpose |
|------|------|---------|
| `audio_input_settings_provider.dart` | keepAlive notifier | CRUD for AudioDevice list (SharedPreferences-backed) |

### Test Helpers (`packages/zip_core/test/helpers/`)

| File | Purpose |
|------|---------|
| `mock_audio_device_service.dart` | Mocktail mock for AudioDeviceService |
| `mock_wake_lock_service.dart` | Mocktail mock for WakeLockService |
| `mock_stt_session_manager.dart` | Mocktail mock for SttSessionManager |
| `mock_speech_to_text.dart` | Mocktail mock for SpeechToText |
| `mock_online_recognizer_adapter.dart` | Mocktail mock for OnlineRecognizerAdapter |
| `mock_permission_handler.dart` | Mocktail mock for PermissionHandlerPlatform (with MockPlatformInterfaceMixin) |

### Test Fixtures (`packages/zip_core/test/fixtures/`)

| File | Purpose |
|------|---------|
| `audio/generate_fixtures.dart` | PCM16 audio fixture generator (silence + 440Hz tone) |
| `audio/silence_16k.pcm` | 16kHz silence fixture (32000 bytes) |
| `audio/tone_440hz_16k.pcm` | 16kHz 440Hz tone fixture (32000 bytes) |
| `valid_model.tar.bz2` | Minimal tar.bz2 archive for model tests |
| `fixture_constants.dart` | SHA-256 hash constant for valid_model fixture |

### Unit Tests

| File | Type | Tests |
|------|------|-------|
| `models/audio_device_test.dart` | unit | Freezed model: creation, equality, JSON |
| `models/wake_lock_settings_test.dart` | unit | Freezed model: defaults, copyWith, JSON |
| `models/sherpa_model_info_test.dart` | unit | Freezed model: isDownloaded, localPath invariant |
| `models/sherpa_model_catalog_test.dart` | unit | JSON deserialization, round-trip, raw JSON |
| `models/recording_error_factories_test.dart` | unit | All factory methods produce valid errors |
| `services/stt_session_manager_test.dart` | unit | Full lifecycle, permission variants, engine error recovery |
| `services/platform_stt_engine_test.dart` | unit | Initialize, isAvailable, supportedLocales, startListening, dispose |
| `services/sherpa_onnx_stt_engine_test.dart` | unit | isAvailable, dispose, engine metadata |
| `services/sherpa_model_manager_test.dart` | unit | deleteModel, modelLocalPath, downloadedModels, cancelDownload |
| `services/catalog_cache_test.dart` | unit | Write/read, freshness, etag, lastModified, touch |
| `providers/active_engine_id_provider_test.dart` | unit | Persistence round-trip via SharedPreferences |
| `providers/active_locale_id_provider_test.dart` | unit | Persistence round-trip, null clearing |
| `providers/resolved_locale_id_provider_test.dart` | unit | Fallback chain: exact, language, first, en-US |
| `providers/wake_lock_settings_provider_test.dart` | unit | Persistence, defaults, update |
| `providers/sherpa_model_catalog_provider_test.dart` | unit | State model copyWith, initial state |

### Property-Based Tests

| File | Type | Tests |
|------|------|-------|
| `pbt/audio_device_properties_test.dart` | PBT | JSON round-trip, non-empty fields |
| `pbt/wake_lock_settings_roundtrip_test.dart` | PBT | copyWith identity, bool field invariants |
| `pbt/sherpa_model_info_properties_test.dart` | PBT | isDownloaded/localPath invariant, catalogEntry present |
| `pbt/download_progress_properties_test.dart` | PBT | downloadedBytes <= totalBytes |

## Files Modified

| File | Change |
|------|--------|
| `models/recording_state.dart` | Added ReconnectingState variant |
| `models/models.dart` | Added exports for new models |
| `stt/stt_engine.dart` | Added pause(), resume() to interface |
| `stt/stt.dart` | Added engines and adapters barrel exports |
| `services/services.dart` | Added audio, wake_lock, catalog barrel exports |
| `providers/providers.dart` | Added 9 new provider exports (active_engine_id, active_locale_id, audio_device_service, resolved_locale_id, sherpa_model_catalog, sherpa_model_manager, stt_session_manager, wake_lock_service, wake_lock_settings) |
| `providers/stt_engine_provider.dart` | Rewired from stub to resolve engine from registry via activeEngineIdNotifier |
| `providers/locale_info_provider.dart` | Changed from sync `[]` to async `Future<List<SpeechLocale>>` querying active engine |
| `providers/recording_state_notifier.dart` | Full rewrite: SttSessionManager + WakeLockService integration, private _handleSttResult/_handleEngineError, one-attempt reconnecting flow (REL-U2.1) |
| `test/helpers/generators.dart` | Added 5 generators: AudioDevice, WakeLockSettings, SherpaModelCatalogEntry, SherpaModelInfo, SherpaModelDownloadProgress |
| `test/helpers/recording_state_model.dart` | Added ModelState.reconnecting, Command.engineError/reconnectSuccess/reconnectFailure |
| `test/models/recording_state_test.dart` | Added ReconnectingState tests |
| `test/providers/recording_state_notifier_test.dart` | Full rewrite with mock provider overrides (SttSessionManager, WakeLockService, SttEngine, ResolvedLocaleId) |
| `test/pbt/recording_state_machine_test.dart` | Added mock provider overrides, isPureModelCommand filter, hidden `any` import from glados |

## Dependencies Added

| Package | Version | Scope | Purpose |
|---------|---------|-------|---------|
| `permission_handler` | ^11.3.1 | runtime | Microphone permission check/request |
| `sherpa_onnx` | ^1.10.31 | runtime | On-device Sherpa-ONNX speech recognition |
| `speech_to_text` | ^7.0.0 | runtime | Platform-native speech recognition |
| `wakelock_plus` | ^1.2.8 | runtime | Screen wake lock during captioning |
| `record` | ^5.1.2 | runtime | Audio recording/PCM capture |
| `dio` | ^5.7.0 | runtime | HTTP client for model downloads |
| `archive` | ^3.6.1 | runtime | tar.bz2 extraction for Sherpa models |
| `crypto` | ^3.0.6 | runtime | SHA-256 verification for model archives |
| `path_provider` | ^2.1.5 | runtime | App-specific storage directories |
| `json_annotation` | ^4.9.0 | runtime | JSON serialization annotations |
| `json_serializable` | ^6.9.4 | dev | JSON serialization codegen |
| `permission_handler_platform_interface` | ^4.2.0 | dev | Mockable permission handler in tests |
| `plugin_platform_interface` | ^2.1.8 | dev | MockPlatformInterfaceMixin for platform mocks |
| `http_mock_adapter` | ^0.6.1 | dev | Dio mock adapter for network tests |

## Architecture Notes

- **SttSessionManager owns the session lifecycle**: Permission check, engine resolution, init, listen, pause/resume, stop, and one-attempt auto-restart recovery (REL-U2.1)
- **RecordingStateNotifier delegates to SttSessionManager**: No direct engine calls from the notifier; clean separation of state machine from engine lifecycle
- **WakeLockService integration**: Acquire on start/resume, onPause on pause, release on stop — conditional based on WakeLockSettings
- **OnlineRecognizerAdapter test seam**: Thin wrapper around sherpa_onnx native class enables unit testing SherpaOnnxSttEngine without native library linkage (TEST-U2.6)
- **ResolvedLocaleIdProvider fallback chain**: Exact match > language-only match > first supported > 'en-US' (FD locale resolution)
- **Security (SECURITY-03)**: No transcript text in logs — only IDs, error types, and state transitions
- **handleSttResult/handleEngineError now private**: Wired internally via callback closures passed to SttSessionManager.initialize()
