# zip_captions — Agent Instructions

Read `../../AGENTS.md` for project-wide rules. Read `../../ARCHITECTURE.md` for the system overview.

## What This Package Is

The personal user app serving the Alex (personal user) and Sam (student/attendee) personas. Runs on iOS, Android, macOS, Windows, Linux, and web. Mobile-first UX but fully functional on desktop. Contains all free accessibility features. Distributed through app stores.

See `docs/04-technical-specification.md` Section 11 (`zip_captions`) for the full responsibility list.
See `docs/01-user-personas.md` Persona 1 (Alex) and Persona 3 (Sam) for user scenarios.

## Key ADRs

- **ADR-001** — platform target matrix (iOS and Android are Primary, desktop is Secondary, web is Fallback)
- **ADR-003** — Riverpod for state management

All ADRs are in `docs/02-architecture-decisions.md`.

## Stack

- Flutter (all platforms)
- `flutter_riverpod` / `riverpod_generator` for state management
- `freezed` for state classes
- Depends on `zip_core` (shared library)
- `very_good_analysis` for linting
- `mocktail` for test mocking

## Build and Test

```bash
# From monorepo root:
melos bootstrap
melos run test --scope zip_captions
melos run analyze --scope zip_captions
melos run generate --scope zip_captions

# Run on a specific platform:
cd packages/zip_captions
flutter run -d ios
flutter run -d android
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter run -d chrome
```

## File Organization

```
lib/
  src/
    screens/
    widgets/
    providers/          # App-specific Riverpod providers
  main.dart
test/
  src/
    screens/
    widgets/
    providers/
  helpers/
    mocks.dart
    pump_app.dart       # Widget test helper with ProviderScope
```

## Critical Patterns

- All business logic lives in `zip_core` — this package contains UI and app-specific providers only
- Widget tests use `pumpApp` helper that wraps with `ProviderScope` and required overrides
- Platform-specific code isolated via conditional imports or platform channels
- Screen wake lock during active captioning
- Microphone permission handling per platform

## Do Not

- Import from `package:zip_broadcast` — the two apps never depend on each other
- Put business logic in this package that could be shared — it belongs in `zip_core`
- Add premium features that reference payment or purchasing (app store distribution constraint — see ADR-001)
- Add dependencies not on the approved list without human approval
