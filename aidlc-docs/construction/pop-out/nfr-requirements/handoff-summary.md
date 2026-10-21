# Handoff: NFR Requirements -> NFR Design
**Unit**: 8.1 Pop-out Live Captions (S-21)
**Date**: 2026-10-21

## Decisions Made
- Dependency placement: `window_manager` in `zip_core` **only**; `desktop_multi_window` in `zip_core` + both apps; `screen_retriever` in `zip_core` and **removed** from `zip_broadcast`. Apps never declare `window_manager` (no Dart call site; native plugin arrives through the package graph).
- Registration: macOS uses the generated all-or-nothing registrant inside the shipped window-created callback (asymmetry recorded as intentional); Windows/Linux register only `window_manager` per plugin inside the shipped callbacks. `zip_captions` gains all three callbacks new.
- Lockfile fence: four named movements (workspace lock adds `window_manager`; Broadcast Podfile.lock -`screen_retriever_macos` +`window_manager_macos`; Captions Podfile.lock +`desktop_multi_window` +`window_manager_macos`). Anything else reported, not committed.
- Always-on-top coverage (Q4 A): assert only that the installer is awaited once, before `overlayReady`, for `PopOutMode`, never for `ExternalDisplayMode`, and that a throwing installer still lets ready be sent. Floating behaviour is Unit 9.
- Performance: inherit Unit 8's numbers unchanged; two new ordering targets only — toggle press reaches `Opening` in the same frame, and always-on-top completes before `show`.
- Failure policy: `OpenFailed` for handler-missing / `createWindow` / ready timeout; a failing `window_manager` call is logged and the window still opens. No retries anywhere.
- Per-app evidence: every claimed §8.8 item gets a test in **both** apps' trees; `zip_core` never carries a shell test. Summary table is 18 rows with a column per app.
- Router testing: unit tests + a two-real-controller test with one recording installer + the moved Unit 8 suite unchanged.
- Redaction: one record-level audit per app (sentinel caption, six paths).
- PBT: in-tree shim; POP-1..POP-6 and POP-8 mandatory; POP-7 an exhaustive table test; no-shrinking limit inherited and recorded.
- Refactor proof: `git diff -M --summary` shows `R100` for every moved file except the FD additive-change table's rows; every non-rename maps to a row; the three fence greps return the expected set.
- Accessibility: visible label + `Semantics(button, enabled, label, hint)` + visible reason text; 44x44 hit area; no live announcement on open.
- `zip_captions` main routing: extract `runZipCaptions(args, {runApp, isWeb})` into `lib/src/bootstrap.dart` and test it against a recording `runApp`.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `OverlayMethodRouter` | new class in `zip_core` | reference-counted; first register installs, last unregister uninstalls; dispatch order = registration order |
| `AlwaysOnTopInstaller` | seam + `_io`/`_stub` | only `window_manager` import; no window id; never throws to the caller |
| `popOutAvailability` | pure function | the single source of the UX-PIP-03 matrix; both apps call it |
| `pop_out_geometry.dart` | pure functions | `computePopOutFrame` takes the main-window centre as a nullable parameter |
| `runZipCaptions` | new bootstrap function in `zip_captions` | overlay path must not reach Google Fonts, logging, `SharedPreferences` or `Supabase.initialize` |
| `PopOutWindowBody` | widget in `zip_core` | injected copy, injected toggle callback, no ARB |
| `OverlayWindowUnavailableApp` | changed | `message` parameter is mandatory |

## Constraints
- No new dev dependency; `fake_async`, `mocktail` and the in-tree PBT shim cover everything.
- No `// ignore` comments; no native source files added (runner callbacks only).
- Windows and Linux runner code is compile-checked by CI only; macOS by `flutter build macos --debug`. Never claim the former verified.
- The lockfile fence is four entries; any other pubspec/lock movement stops the step and is reported.

## Open Questions for Next Stage
- How the router is wired into the provider graph so both controllers receive the *same* instance without `zip_core` owning an app provider: a `@Riverpod(keepAlive: true)` provider in `zip_core` holding the router and one enumerator, or an app-side construction passed into both controller constructors? (source: FD left the provider shape to NFR Design)
- Whether `computePopOutFrame`'s main-window-centre parameter is fed from a real window geometry source this unit, or stays `null` (primary display) with the parameter reserved. (source: FD §3.4's recorded limitation)
- Precise shape of the two-controller router test's recording installer so it proves window-id routing and not merely call count. (source: Q3 A's "reaching only the controller that created window 7")