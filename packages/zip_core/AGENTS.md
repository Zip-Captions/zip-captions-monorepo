# zip_core — Agent Instructions

Read `../../AGENTS.md` for project-wide rules. Read `../../ARCHITECTURE.md` for the system overview.

## What This Package Is

The shared Dart library used by both Zip Captions and Zip Broadcast. Contains all business logic, platform abstractions, and data models. **No Flutter UI code** — no `Widget`, no `BuildContext` except in optional widget utilities.

See `docs/04-technical-specification.md` Section 11 (`zip_core`) for the full responsibility list.

## Key ADRs

Read these before working in this package:

- **ADR-003** (Riverpod) — all state via `riverpod_generator`, no hand-written providers
- **ADR-005** (STT Engine) — `SttEngine` abstract class, `SttResult` model, `SttEngineRegistry`
- **ADR-006** (Encryption) — zero-knowledge, AES-256-GCM, client-only keys
- **ADR-007** (BLE) — discovery protocol, service UUID, characteristic format
- **ADR-008** (Caption Bus) — pub-sub stream, output target subscriptions, middleware
- **ADR-013** (Translation) — `TranslationEngine` interface, bus middleware pattern

All ADRs are in `docs/02-architecture-decisions.md`.

## Stack

- Dart (pure library, no Flutter dependency in core logic)
- `flutter_riverpod` / `riverpod_generator` for state management
- `freezed` / `freezed_annotation` for immutable state classes
- `json_serializable` for serialization
- `mocktail` for test mocking
- `very_good_analysis` for linting

## Build and Test

```bash
# From monorepo root:
melos bootstrap                              # Install dependencies
melos run test --scope zip_core              # Run tests
melos run analyze --scope zip_core           # Static analysis
melos run generate --scope zip_core          # Code generation (freezed, riverpod, json)
melos run coverage --scope zip_core          # Test with coverage report
```

## File Organization

```
lib/
  src/
    feature_x/
      feature_x.dart              # Barrel export
      feature_x_provider.dart
      feature_x_model.dart
  zip_core.dart                   # Package barrel — re-exports public API from src/
test/
  src/
    feature_x/
      feature_x_provider_test.dart
      feature_x_model_test.dart
  helpers/
    mocks.dart
```

## Critical Patterns

- All providers use `riverpod_generator` — no hand-written `Provider`, `StateNotifierProvider`, etc.
- State classes use `freezed` with sealed variants (idle, listening, paused, error)
- All public APIs have dartdoc comments (`///`)
- Inline comments required for non-obvious logic — explain WHY, not WHAT
- Package imports only: `package:zip_core/...`, never relative `../`
- One public class per file, filename matches primary export

## Do Not

- Add Flutter UI code (`Widget`, `BuildContext`, `MaterialApp`) to this package
- Import from `package:zip_captions` or `package:zip_broadcast` — dependencies flow one way
- Use `print()` — use `dart:developer` `log()`
- Use `dart:mirrors` or `dart:html`
- Catch generic `Exception` — catch specific types (except top-level error boundaries)
- Use `setState()` or `ChangeNotifier`
- Add dependencies not on the approved list without human approval
- Modify the `SttEngine`, `TranslationEngine`, or caption bus interfaces without discussion
