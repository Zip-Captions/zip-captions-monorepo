# Unit 7 — PR #16 Review Feedback: Code Generation Plan

## Context
- **Unit**: Unit 7 — Integration Milestones + Zip Broadcast UI/UX fixes (already code-generated, PR open)
- **Trigger**: PR #16 (`feature/phase1-integration-tests` → `develop`) returned `CHANGES_REQUESTED` from CodeRabbit automated review, plus 2 failing CI checks (Analyze & Test, Windows Build Verify)
- **Nature of work**: Revision pass within the existing Unit 7 Code Generation stage — no new business logic, data models, or NFRs are introduced, so Functional Design / NFR stages are not re-entered. Per the Adaptive Workflow Principle, this stays inside Code Generation as a fix-and-verify loop.
- **Source of truth for findings**: `gh pr view 16 --comments`, `gh api repos/Zip-Captions/zip-captions-monorepo/pulls/16/comments`, `gh pr checks 16`, `gh run view` logs (captured 2026-07-18)

## Steps

- [x] **Step 1 — Fix Riverpod load-fence race (Major)**
  `packages/zip_broadcast/lib/src/providers/broadcast_providers.dart`
  Add `Future<void>? _loadFuture` to `ObsSettingsNotifier`, assign in `build()`, await it at the top of `update()` and `markConnectionVerified()` before touching `state`. Matches the documented pattern in `docs/RIVERPOD_CONVENTIONS.md`.

- [x] **Step 2 — Fix OBS toggle lockout (functional bug)**
  `packages/zip_broadcast/lib/src/widgets/output_targets_panel.dart`
  Change the OBS `_TargetCard.onToggle` condition so it's `(outputSettings.obsEnabled || obsVerified) && !_obsTesting` — users must always be able to disable OBS even if verification later fails.

- [x] **Step 3 — Persist verification result before mounted-check**
  `packages/zip_broadcast/lib/src/screens/settings_screen.dart` (`_testConnection`, ~L360-369)
  Await `markConnectionVerified()` unconditionally on a connected status; move the `mounted` guard to only gate the subsequent snackbar/UI feedback.

- [x] **Step 4 — Localize nav rail labels**
  `packages/zip_broadcast/lib/src/shell/zb_nav_rail.dart`
  Replace hardcoded `'Home'`/`'Broadcast'`/`'History'` strings with `ZipBroadcastLocalizations.of(context)!.appTitleDefault/appTitleBroadcast/appTitleHistory`, matching `ZbAppShell`'s existing usage. Remove `const` from affected `NavigationRailDestination`s.

- [x] **Step 5 — Switch integration test helper imports to package imports — SKIPPED, false positive**
  `packages/zip_broadcast/test/integration/audio_config_recording_integration_test.dart`, `caption_bus_flow_test.dart`, `obs_settings_connection_integration_test.dart`
  Investigated: `package:` URIs cannot address files under `test/` (only `lib/`), and 39 other test files across the monorepo already use relative imports for test helpers — this is the established, pre-existing convention for test-only code. The "package imports only" rule in `docs/04-technical-specification.md` is scoped to `lib/` production code. No change made; flagged as a CodeRabbit false positive rather than implemented as originally planned.

- [x] **Step 6 — Override `sharedPreferencesProvider` in integration test containers**
  `packages/zip_broadcast/test/integration/audio_config_recording_integration_test.dart`, `caption_bus_flow_test.dart`
  Build mock `SharedPreferences` and add `sharedPreferencesProvider.overrideWithValue(prefs)` to each `ProviderContainer` so persistence init is deterministic and in-container.

- [x] **Step 7 — Fix `dart analyze --fatal-infos` lint failures (blocks CI)**
  `packages/zip_captions/test/integration/recording_pipeline_integration_test.dart`
  Resolve the 10 reported infos: `prefer_int_literals` (lines 160, 253, 259, 263) and `lines_longer_than_80_chars` (lines 160, 169, 177, 253, 259, 263).

- [x] **Step 8 — Root-cause and fix Windows Build Verify failure (blocks CI)**
  Root cause confirmed: `windows-latest` runner image now ships an MSVC toolset (VS 18 / VC Tools 14.51) that hard-errors on `<experimental/coroutine>` (`C2338`), which `local_auth_windows` (locked at 1.0.11) and `permission_handler_windows` (locked at 0.2.1, latest available) still depend on transitively. Not caused by this PR's diff — confirmed by Windows Build Verify last passing in April against the same code path.
  - Bump `local_auth` to pull in `local_auth_windows` 2.0.1 (removes the deprecated coroutine usage) — check `local_auth`'s dependency constraint allows this via `flutter pub upgrade local_auth` / version bump in `packages/zip_captions/pubspec.yaml`.
  - `permission_handler_windows` has no newer release (0.2.1 is latest); apply a scoped workaround — define `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` for the Windows CMake build (e.g. via `packages/zip_captions/windows/CMakeLists.txt` or a generated plugin symlink override) so the deprecated-but-functional path compiles, and leave a comment noting this is temporary pending an upstream fix.
  - Re-run `flutter build windows` locally/CI to confirm the fix; do not touch unrelated plugin versions.

- [x] **Step 9 — Verify**
  Run `melos run analyze` and `melos exec -- flutter test` (or targeted packages) locally; confirm no new failures. Push commit(s) to `feature/phase1-integration-tests` and re-check `gh pr checks 16`.

## Out of scope
- No new stories, data models, or NFRs — this is a review-feedback correction pass.
- Will not touch other flaky/unrelated plugins beyond what's needed to unblock the Windows build.
