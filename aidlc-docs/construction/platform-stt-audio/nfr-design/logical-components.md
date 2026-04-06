# Logical Components — Unit 2: Platform STT + Audio

## Overview

Unit 2 extends `zip_core` with STT engine implementations, audio device management, model lifecycle, and wake lock services. It introduces external dependencies (platform plugins, HTTP, archive extraction) that require test seams. A shell provider is added to `zip_broadcast`.

## Runtime Component Map

```
+-----------------------------------------------------------------------+
|                           zip_core                                     |
|                                                                        |
|  +---------------------------+    +------------------------------+     |
|  | SttSessionManager         |    | SherpaModelManager           |     |
|  | (plain class, keepAlive   |    | (plain class, keepAlive      |     |
|  |  provider)                |    |  provider)                   |     |
|  | - permission check        |    | - catalog fetch (dio)        |     |
|  | - engine lifecycle        |    | - download + resume          |     |
|  | - crash recovery (1x)    |    | - integrity verify (SHA-256) |     |
|  +---------------------------+    | - archive extraction         |     |
|                                   | - CatalogCache (file-based)  |     |
|  +---------------------------+    +------------------------------+     |
|  | PlatformSttEngine         |                                         |
|  | (SttEngine impl)          |    +------------------------------+     |
|  | - wraps SpeechToText      |    | SherpaModelCatalogNotifier   |     |
|  | - wraps AudioDeviceService|    | (Riverpod, keepAlive)        |     |
|  +---------------------------+    | - download lifecycle         |     |
|                                   | - confirmation gate (>100MB) |     |
|  +---------------------------+    | - engine registration        |     |
|  | SherpaOnnxSttEngine       |    +------------------------------+     |
|  | (SttEngine impl)          |                                         |
|  | - wraps OnlineRecognizer  |    +------------------------------+     |
|  |   AdapterAdapter          |    | WakeLockService (interface)  |     |
|  | - wraps AudioDeviceService|    | WakelockPlusService (impl)   |     |
|  | - wraps SherpaModelManager|    | - static WakelockPlus calls  |     |
|  +---------------------------+    +------------------------------+     |
|                                                                        |
|  +---------------------------+    +------------------------------+     |
|  | AudioDeviceService        |    | CatalogCache                 |     |
|  | (abstract interface)      |    | (plain class)                |     |
|  | - listInputDevices()      |    | - file-based JSON cache      |     |
|  | - setPreferredInputDevice |    | - meta: cachedAt, etag,      |     |
|  +---------------------------+    |   lastModified               |     |
|                                   +------------------------------+     |
|                                                                        |
|  New Providers (Riverpod, keepAlive):                                  |
|  - sttSessionManagerProvider                                           |
|  - audioDeviceServiceProvider                                          |
|  - wakeLockServiceProvider                                             |
|  - wakeLockSettingsProvider                                            |
|  - sherpaModelManagerProvider                                          |
|  - sherpaModelCatalogProvider                                          |
|  - activeEngineIdProvider                                              |
|  - activeLocaleIdProvider                                              |
|  - resolvedLocaleIdProvider                                            |
|  - localeInfoProvider (updated)                                        |
|  - sttEngineProvider (updated)                                         |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
|                         zip_broadcast                                   |
|                                                                        |
|  +---------------------------+                                         |
|  | AudioInputSettingsNotifier|                                         |
|  | (Riverpod, keepAlive)     |                                         |
|  | - CRUD for AudioInputConfig                                         |
|  | - single-input default    |                                         |
|  +---------------------------+                                         |
+-----------------------------------------------------------------------+
```

## Test Infrastructure Components

### 1. OnlineRecognizerAdapter + Mock (Q1=A)

**Interface**: `packages/zip_core/lib/src/stt/adapters/online_recognizer_adapter.dart`
**Production**: `packages/zip_core/lib/src/stt/adapters/sherpa_online_recognizer_adapter.dart`
**Mock**: `packages/zip_core/test/helpers/mock_online_recognizer_adapter.dart`

| Method | Purpose |
|--------|---------|
| `createStream()` | Creates a recognition stream |
| `acceptWaveform()` | Feeds PCM16 audio samples |
| `isReady()` | Checks if decode step can run |
| `decode()` | Runs one decode step |
| `getResult()` | Returns partial/final text |
| `reset()` | Resets stream for next utterance |
| `dispose()` | Frees native resources |

Coverage excluded (pure pass-through).

### 2. MockSpeechToText

**Location**: `packages/zip_core/test/helpers/mock_speech_to_text.dart`

```dart
class MockSpeechToText extends Mock implements SpeechToText {}
```

Used by `PlatformSttEngine` unit tests. Configured per test to return specific locales, simulate success/failure, and trigger `onResult` callbacks.

### 3. MockWakeLockService (Q5=A)

**Location**: `packages/zip_core/test/helpers/mock_wake_lock_service.dart`

```dart
class MockWakeLockService extends Mock implements WakeLockService {}
```

Used by `RecordingStateNotifier` tests to verify wake lock calls on state transitions.

### 4. MockAudioDeviceService

**Location**: `packages/zip_core/test/helpers/mock_audio_device_service.dart`

```dart
class MockAudioDeviceService extends Mock implements AudioDeviceService {}
```

Used by both engine tests and `SttSessionManager` tests.

### 5. DioAdapter (http_mock_adapter, Q4=A)

**Dev dependency**: `http_mock_adapter`

Used by `SherpaModelManager` tests to simulate:
- Catalog fetch (200, 304, timeout, error)
- Model download (200, 206 resume, error)
- HTTPS enforcement (reject non-HTTPS URLs)

### 6. PCM16 Audio Fixtures (TEST-U2.3)

**Location**: `packages/zip_core/test/fixtures/audio/`

| File | Content | Duration | Source | Purpose |
|------|---------|----------|--------|---------|
| `silence_16k.pcm` | Zero-filled PCM16 at 16kHz | 2s | Generated by `generate_fixtures.dart` | Engine handles silence without crash |
| `tone_440hz_16k.pcm` | 440Hz sine wave, PCM16 at 16kHz | 2s | Generated by `generate_fixtures.dart` | Engine processes non-speech audio |
| `speech_en_16k.pcm` | Pre-recorded English speech, PCM16 at 16kHz | 3–5s | Human-recorded, converted with ffmpeg | Integration: at least one result emitted |

#### Fixture Generation Script

`packages/zip_core/test/fixtures/audio/generate_fixtures.dart` — a standalone Dart script run once during setup (not in CI). Generates `silence_16k.pcm` and `tone_440hz_16k.pcm` and commits the output to the repo.

```dart
// silence: 2s × 16000 samples/s × 2 bytes/sample = 64,000 bytes of zeros
final silence = Uint8List(64000);
File('silence_16k.pcm').writeAsBytesSync(silence);

// tone: 440Hz sine wave, PCM16 signed little-endian
final tone = ByteData(64000);
for (var i = 0; i < 32000; i++) {
  final sample = (sin(2 * pi * 440 * i / 16000) * 32767).toInt();
  tone.setInt16(i * 2, sample, Endian.little);
}
File('tone_440hz_16k.pcm').writeAsBytesSync(tone.buffer.asUint8List());
```

#### Speech Fixture — Human-Recorded

The `speech_en_16k.pcm` file is recorded by a project member and converted to raw PCM16:

1. **Record** a 3–5 second clip of clear English speech (e.g., "The quick brown fox jumps over the lazy dog. One two three four five.")
2. **Save** as any common format (`.m4a`, `.wav`, `.mp3`)
3. **Convert** to 16kHz mono PCM16 signed little-endian using ffmpeg:
   ```bash
   ffmpeg -i recording.m4a -ar 16000 -ac 1 -f s16le -acodec pcm_s16le speech_en_16k.pcm
   ```
4. **Verify** file size is reasonable: 3s ≈ 96,000 bytes, 5s ≈ 160,000 bytes
5. **Commit** to `packages/zip_core/test/fixtures/audio/`

This file is used only in integration-level fixture tests (not in CI unit tests) to assert that a real Sherpa-ONNX engine emits at least one `SttResult` for non-silent audio.

### 7. Model Archive Fixture (TEST-U2.5)

**Location**: `packages/zip_core/test/fixtures/valid_model.tar.bz2`

A minimal `.tar.bz2` containing a single dummy file. Generated once and committed:

```bash
# Create a dummy model directory with a single file
mkdir -p /tmp/dummy-model && echo "dummy" > /tmp/dummy-model/model.bin
# Create the tar.bz2 archive
tar -cjf packages/zip_core/test/fixtures/valid_model.tar.bz2 -C /tmp dummy-model
# Compute the expected SHA-256 for use in tests
shasum -a 256 packages/zip_core/test/fixtures/valid_model.tar.bz2
```

The SHA-256 output is stored as a constant in the test file (e.g., `const expectedSha256 = '...'`).

Used to test:
- Successful extraction after checksum verification (with correct hash)
- Checksum mismatch rejection (tested with a deliberately wrong hash)

### 8. PBT Generators (Q6=B)

**Location**: `packages/zip_core/test/helpers/generators.dart` (extended)

| Generator | Produces | Used By |
|-----------|----------|---------|
| `ArbitraryAudioDevice` | Random valid `AudioDevice` | audio_device_properties_test |
| `ArbitrarySherpaModelCatalogEntry` | Random valid catalog entries | sherpa_model_info_properties_test |
| `ArbitrarySherpaModelInfo` | Random model info with consistent invariants | sherpa_model_info_properties_test |
| `ArbitraryWakeLockSettings` | Random wake lock settings | wake_lock_settings_roundtrip_test |
| `ArbitrarySherpaModelDownloadProgress` | Random download progress | download_progress_properties_test |
| `ArbitraryTransitionSequence` | **Extended** with `engineError`, `reconnectSuccess`, `reconnectFailure` | recording_state_machine_test |

### 9. MockPermissionHandlerPlatform

**Location**: `packages/zip_core/test/helpers/mock_permission_handler.dart`

Mocks `permission_handler`'s platform interface to test all permission paths in `SttSessionManager` without requiring a real device.

### 10. Existing Test Helpers (Inherited from Unit 1)

| Helper | Location | Status |
|--------|----------|--------|
| `MockSttEngine` | `test/helpers/mock_stt_engine.dart` | Unchanged — used in `SttSessionManager` tests |
| `CollectingTarget` | `test/helpers/test_targets.dart` | Unchanged |
| `ThrowingTarget` | `test/helpers/test_targets.dart` | Unchanged |
| PBT generators (Unit 1) | `test/helpers/generators.dart` | Extended with Unit 2 generators |

---

## Dependency Summary

### New Runtime Dependencies

| Package | Version | Purpose | Module |
|---------|---------|---------|--------|
| `record` | latest stable | Audio device enumeration + streaming capture | zip_core |
| `speech_to_text` | latest stable | Platform STT (PlatformSttEngine) | zip_core |
| `sherpa_onnx` | latest stable | Offline STT (SherpaOnnxSttEngine) | zip_core |
| `permission_handler` | latest stable | Microphone permission check | zip_core |
| `wakelock_plus` | latest stable | Screen wake lock (static API) | zip_core |
| `dio` | latest stable | HTTP client (catalog + download) | zip_core |
| `archive` | latest stable | tar+bz2 extraction | zip_core |
| `path_provider` | latest stable | Platform storage directories | zip_core |
| `crypto` | latest stable | SHA-256 checksum verification | zip_core |

### New Dev Dependencies

| Package | Version | Purpose | Module |
|---------|---------|---------|--------|
| `http_mock_adapter` | latest stable | dio test adapter | zip_core |

### Unchanged Dependencies

freezed, freezed_annotation, riverpod, riverpod_annotation, shared_preferences, build_runner, riverpod_generator, uuid, logging, glados, mocktail

---

## Extension Compliance Summary

### Security Baseline

| Rule | Status | Notes |
|------|--------|-------|
| SECURITY-01 | N/A | No data stores in Unit 2 (catalog cache is not user data) |
| SECURITY-02 | N/A | No network intermediaries |
| SECURITY-03 | **Compliant** | SEC-U2.1: all new components exclude transcript text from logs |
| SECURITY-04 | **Compliant** | SEC-U2.2: HTTPS enforced on all dio requests; non-HTTPS URLs rejected |
| SECURITY-05 | **Compliant** | SEC-U2.5: no background captioning; no audio background mode configured |

### Property-Based Testing

| Rule | Status | Notes |
|------|--------|-------|
| PBT-01 | **Compliant** | Properties identified for all new domain types |
| PBT-02 | **Compliant** | Serialization round-trip tests for AudioDevice, SherpaModelCatalogEntry, WakeLockSettings |
| PBT-03 | **Compliant** | Invariant tests: `isDownloaded` ↔ `localPath`, `downloadedBytes <= totalBytes` |
| PBT-04 | **Compliant** | Idempotence: wake lock acquire/release cycle |
| PBT-05 | N/A | No commutativity properties |
| PBT-06 | **Compliant** | State machine PBT extended with `engineError`, `reconnectSuccess`, `reconnectFailure` |
| PBT-07 | **Compliant** | 5 new Arbitrary generators in shared generators.dart |
| PBT-08 | **Compliant** | glados provides automatic shrinking |
| PBT-09 | **Compliant** | PBT tests in pbt/ subdirectory, generators in helpers/ |
| PBT-10 | N/A | No performance properties requiring PBT |
