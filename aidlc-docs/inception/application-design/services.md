# Services — Zip Captions v2, Phase 0

Phase 0 has minimal service layer — the primary work is scaffolding providers and models. This document captures the two services that exist in Phase 0 and the service contracts that Phase 1 will implement.

---

## Services Present in Phase 0

### Settings Persistence Service (implicit, via SharedPreferences)

- **Location**: Internal to `BaseSettingsNotifier`; not a separate class
- **Responsibility**: Reads and writes `AppSettings` fields to `shared_preferences` using a per-app key prefix (`zip_captions.` or `zip_broadcast.`)
- **Orchestration**: Called by `BaseSettingsNotifier.build()` on initialization and by each setter method. No direct consumer access — all interaction goes through the Riverpod provider.
- **Phase 0 scope**: Full implementation (not a stub)

### Locale Persistence Service (implicit, via SharedPreferences)

- **Location**: Internal to `LocaleProvider`
- **Responsibility**: Persists the user's selected display locale across app restarts
- **Phase 0 scope**: Full implementation

---

## Service Contracts Defined in Phase 0 (Implemented in Phase 1)

### `SttEngine` (abstract)

- **Location**: `zip_core/lib/src/services/stt/stt_engine.dart`
- **ADR**: ADR-005
- **Responsibility**: Abstract interface for all speech-to-text engines. Defines the contract that all platform-specific and third-party STT implementations must fulfill.
- **Phase 0**: Interface definition and stub `sttEngineProvider` only. No concrete implementation.
- **Phase 1**: `PlatformSttEngine` (iOS/macOS: Apple Speech, Android: Google on-device, Web: Web Speech API)

Key interface methods (to be fully specified in Phase 1 Functional Design):

| Method | Signature | Purpose |
|---|---|---|
| `initialize` | `Future<bool> initialize()` | Request permissions, prepare engine |
| `isAvailable` | `Future<bool> isAvailable()` | Check if engine can run on this device/platform |
| `startListening` | `Future<bool> startListening({...})` | Begin STT session |
| `stopListening` | `Future<void> stopListening()` | End STT session |
| `pause` | `Future<bool> pause()` | Pause recognition |
| `resume` | `Future<bool> resume()` | Resume recognition |
| `dispose` | `void dispose()` | Release resources |

**Security constraint**: The `SttEngine` interface must never expose raw transcript text to any logging, telemetry, or analytics layer. All text data flows exclusively to registered callbacks and the caption bus (Phase 1).

---

## Service Orchestration Pattern (Phase 0 Establishment)

Riverpod is the sole orchestration mechanism — no service locator, no `GetIt`, no global singletons.

```
User interaction
      |
      v
App Widget (ConsumerWidget)
      |
      v
Riverpod Provider (ref.watch / ref.read)
      |
      v
Notifier (business logic)
      |
      v
Service / SharedPreferences (I/O)
```

Providers are the only entry point for services. Widgets read state via `ref.watch` and trigger mutations via `ref.read(provider.notifier).method()`. Services are not directly accessible from widgets.
