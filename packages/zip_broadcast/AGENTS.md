# zip_broadcast — Agent Instructions

Read `../../AGENTS.md` for project-wide rules. Read `../../ARCHITECTURE.md` for the system overview.

## What This Package Is

The broadcaster/professional app serving the Jordan (broadcaster) persona. Desktop-only: macOS, Windows, Linux, and web. Contains broadcaster-specific features (OBS integration, multi-output, configuration profiles) and premium functionality. Distributed outside app stores with its own payment integration.

See `docs/04-technical-specification.md` Section 11 (`zip_broadcast`) for the full responsibility list.
See `docs/01-user-personas.md` Persona 2 (Jordan) for user scenarios.

## Key ADRs

- **ADR-001** — platform target matrix (macOS, Windows, Linux are Primary, web is Fallback, no mobile)
- **ADR-003** — Riverpod for state management
- **ADR-008** — caption bus output targets (OBS, browser source, Realtime broadcast, external display)
- **ADR-011** — transport layer (WebRTC, Supabase Realtime relay toggle, stable broadcast URLs)

All ADRs are in `docs/02-architecture-decisions.md`.

## Stack

- Flutter (desktop + web only)
- `flutter_riverpod` / `riverpod_generator` for state management
- `freezed` for state classes
- Depends on `zip_core` (shared library)
- `very_good_analysis` for linting
- `mocktail` for test mocking

## Build and Test

```bash
# From monorepo root:
melos bootstrap
melos run test --scope zip_broadcast
melos run analyze --scope zip_broadcast
melos run generate --scope zip_broadcast

# Run on a specific platform:
cd packages/zip_broadcast
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
    obs/                # OBS WebSocket integration
    output/             # Multi-output management
  main.dart
test/
  src/
    screens/
    widgets/
    providers/
    obs/
    output/
  helpers/
    mocks.dart
    pump_app.dart
```

## Critical Patterns

- All business logic lives in `zip_core` — this package contains UI, OBS integration, and app-specific providers
- No iOS or Android build targets — this app is desktop and web only
- Premium features live here (not in `zip_captions`) to avoid app store conflicts
- Broadcast session management, relay toggle, and viewer dashboard are app-specific UI

## Do Not

- Import from `package:zip_captions` — the two apps never depend on each other
- Add iOS or Android platform directories or build targets
- Put business logic in this package that could be shared — it belongs in `zip_core`
- Add dependencies not on the approved list without human approval
