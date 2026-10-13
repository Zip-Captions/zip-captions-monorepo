# Code Generation Summary — Unit 6 (Zip Broadcast Broadcast UI), `zip_broadcast` half

**Plan**: `aidlc-docs/construction/plans/broadcast-ui-code-generation-plan.md` (Steps 24-36 of 36)

## What Shipped

**l10n**
- `l10n/arb/app_en.arb` — ~40 new entries (session-name field/errors, auto-start toggle,
  URL row/copy, Go Live button/progress/failure card, dashboard stat cards, F-6.4 banner
  matrix, broadcast-full banner, caption preview, captioning controls, End Broadcast,
  Rule 9 sign-out-refused snackbar). Generated Dart localization files are build
  artifacts of `flutter gen-l10n` — never edited directly.

**Shell / routing**
- `lib/src/shell/zb_app_shell.dart` (modified) — new `ZbSignOutScope` (`InheritedWidget`
  carrying a bound `Future<void> Function()`, not the private shell-state type directly)
  and `_requestSignOut()` implementing Rule 9's guard + NFR Design Q2's no-await-between
  discipline; `_screenTitle`/`_railIndex`/`_railDestination` extended for `/broadcast`.
- `lib/src/shell/zb_nav_rail.dart`, `zb_nav_drawer.dart` (modified) — a 4th destination
  for `/broadcast`, distinct from the existing (pre-existing, confusingly-named)
  "Broadcast" entry that points to Phase 1's local `/recording` screen.
- `lib/src/routing/zb_router.dart` (modified) — `/broadcast` route.
- `lib/src/screens/account_section.dart` (modified) — sign-out button now calls
  `ZbSignOutScope.of(context)`.
- `lib/main.dart` (modified) — `captioningStarterProvider` override.

**New files**
- `lib/src/providers/broadcast_captioning_starter.dart` — `BroadcastCaptioningStarter`
  (`CaptioningStarter` backed by `BroadcastRecordingNotifier`)
- `lib/src/screens/broadcast_screen.dart` — `BroadcastScreen`: one route switching on
  `BroadcasterSessionState` (Functional Design Q8) between the setup form (output
  targets panel reuse, session-name validation, signed-out overlay, URL row + clipboard
  copy, Go Live button/progress/failure-card) and the live dashboard (viewer-count/
  duration stat cards, F-6.4 banner matrix, broadcast-full banner, caption preview,
  captioning controls, per-input audio rows, viewer list, End Broadcast).

**Tests**: `test/helpers/zb_test_harness.dart` (modified, `/broadcast` route added),
`test/widgets/account_section_test.dart` (modified — the sign-out test now asserts the
call reaches `ZbSignOutScope`, not `authNotifierProvider` directly; 1 new test, 8 total),
`test/shell/zb_app_shell_test.dart` (new — the Rule 9 guard itself: 5 tests covering
`OfflineState`/`BroadcastFailedState` sign-out success and `StartingState`/`LiveState`/
`EndingState` refusal-with-feedback), `test/screens/broadcast_screen_test.dart` (new —
13 tests, one per approved Proto-11/Proto-12 state, mapped to S-17's acceptance
criteria; no golden-image tests, per NFR Requirements Q2).

**Final gates**: `dart analyze --fatal-infos` clean; full `zip_broadcast` suite
121 passing, 0 regressions.

## A Real Bug Found by Writing the Widget Tests, Not Just Analyzing

`broadcast_screen_test.dart`'s "paused shows the not-running banner copy" test failed
on first run: the `_CaptionActivityBanner` widget's "never started" vs. "not running"
distinction (F-6.4) was implemented to apply to `paused` as well as `inactive`, but
`paused` never set the internal `_everActive` flag on its own — a broadcast that went
straight to `paused` without ever having been `active` would incorrectly show "hasn't
started yet" instead of the correct "not running" copy the design specifies
unconditionally for `paused`. Fixed: `paused` now always renders the "not running" copy,
independent of history; only `inactive` still distinguishes "never active" from
"stopped after having been active." A second, unrelated bug in the same widget (a
`SizedBox(16×16)` wrapping a `Row` containing a spinner *and* text, causing a
`RenderFlex` overflow and a `pumpAndSettle` timeout since the progress indicator
animates indefinitely) was fixed by removing the pointless outer constraint.

## Deviations From the Approved Plan

1. **Navigation wiring was not explicitly fixed by any prior stage** (Functional
   Design Q8 only fixed "one route, content switches on state" — not where that route
   is reached from). Added a 4th nav-rail/drawer destination using the existing
   convention (icon choice matching `AccountSection`'s own `Icons.podcasts`), rather
   than treating this as an open design question — it is wiring, not a design decision.
2. **A real naming collision between `zip_core` and `zip_broadcast`'s own
   `AudioInputConfig`/`AudioInputVisualStyle`** (Phase 1 single-engine vs. this
   project's multi-engine versions) resolved with `hide`, matching
   `broadcast_recording_notifier.dart`'s own existing precedent for the identical
   collision — not a new pattern.

No other deviation from the approved Functional Design / NFR Requirements / NFR Design
artifacts.
