# Code Summary — Unit 7: Zip Captions Viewer (`zip_captions`)

## Story Implemented

- **S-19**: The join form and the viewer screen — typed code or pasted link,
  live captions with a status line, and an explicit, confirmed way to leave.

## Verification Results

| Check | Result |
|-------|---------|
| `dart analyze --fatal-infos` | 0 errors, 0 warnings, 0 infos |
| `flutter test` | 124 passed |
| `dart run build_runner build` | `ZcStrings` and `viewerAnnouncer` outputs committed |

## Files Created

| File | Purpose |
|------|---------|
| `lib/src/l10n/zc_strings.dart` (+ `.g.dart`) | The only reader of `l10n/arb/app_en.arb`; one getter per key, `{sessionName}` formatting, no `gen-l10n`/`intl` |
| `lib/src/providers/viewer_announcer_provider.dart` (+ `.g.dart`) | `ViewerAnnouncer` callback seam; default sends a polite `SemanticsService.sendAnnouncement` for the calling view |
| `lib/src/widgets/viewer_status_region.dart` | The single live region: one status line plus optional body, announced once per copy change |
| `lib/src/widgets/viewer_status_presenter.dart` | Exhaustive state-to-copy mapping, including which reasons offer retry |
| `lib/src/widgets/viewer_route_args.dart` | Typed route argument carrying the already-parsed `BroadcastId` |
| `lib/src/screens/join_broadcast_screen.dart` | Parses input with `BroadcastLink`, inline invalid-input error, navigates with the parsed ID |
| `lib/src/screens/viewer_screen.dart` | Joins on entry, renders status and remote captions, confirms leaving an active session |

## Files Modified

| File | Change |
|------|--------|
| `l10n/arb/app_en.arb` | Every viewer string, with descriptions and the one `sessionName` placeholder |
| `pubspec.yaml` | `l10n/arb/app_en.arb` declared as an asset |
| `lib/src/routing/zc_router.dart` | `/join` inside the shell; `/b/:broadcastId` outside it, so the viewer owns its own chrome |
| `lib/src/shell/zc_app_shell.dart` | `/join` renders the "Join" title; the rail is unchanged |
| `lib/src/shell/zc_nav_drawer.dart` | "Join Broadcast" destination |
| `lib/src/screens/home_screen.dart` | "Join a broadcast" action |

## Tests Added

| File | Coverage |
|------|----------|
| `test/l10n/zc_strings_test.dart` | Lookup, placeholder formatting, missing-key fallback, the real ARB parses |
| `test/widgets/join_broadcast_screen_test.dart` | Bare code, URL, whitespace, invalid and empty input, error clearing, keyboard submit, route args |
| `test/widgets/viewer_screen_test.dart` | Join on entry, connecting copy, live/paused, remote captions, reconnecting keeps captions, leave confirm/cancel, retry per reason, offline, invalid link, ended, one announcement per transition |
| `test/widgets/viewer_screen_leave_test.dart` | Rule 9: dialog for active states, none for terminal states, the same two paths via system back |
| `test/widgets/viewer_screen_l10n_test.dart` | Sentinel map proves ARB wiring; real ARB values; the paused notice clears in place |
| `test/widgets/viewer_status_region_test.dart` | One live region, one announcement per change, none on an unrelated rebuild |
| `test/widgets/viewer_status_presenter_test.dart` | Every variant and reason maps to distinct, non-empty copy; retry only where it can help |
| `test/widgets/viewer_routes_shell_test.dart` | `/b/:id` renders no shell chrome at both widths; `/join` is in-shell with its title |
| `test/helpers/viewer_test_harness.dart` | Sentinel strings, fake resolver/status channel/transport/signaling/ICE provider, transport factory |

## Decisions Worth Knowing

- **Retry uses the route ID, not `currentBroadcastId`.** A failed resolution
  deliberately never sets `currentBroadcastId` (it records only broadcasters
  that were found), so a retry from `CannotConnect` re-enters from the ID the
  route was opened with.
- **`ViewerStatusRegion` is the only announcement trigger.** The notifier
  never announces; the region compares its own last announced copy, so
  caption arrivals and unrelated rebuilds stay silent.
- **The viewer route sits outside the shell.** It has its own app bar, back
  handling and leave confirmation; the app's drawer/rail would be a second,
  conflicting exit.
- **`ZcStrings` is synchronous after one asset load.** The `keepAlive`
  provider loads the ARB once; `ZcStrings.fromMap` exists for tests, so there
  is one asynchronous path and one synchronous one, never a second reader.
## Review round 1

1. **Fixed** (a222d52) — `ViewerScreen` tracks the subscribed `CaptionBus` and
   cancels/re-subscribes when identity changes. Test added: retry after
   `Ended` shows the new session's captions and the ended session's bus no
   longer drives the pane. The finding's auto-join premise is rebutted:
   `_onStatusChannelEvent` reuses the existing resources (same `bus`, new
   `sessionId`), so auto-join never allocates a second bus; that test was
   vacuous here and was removed rather than left passing.
2. **Fixed** (4664898) — `BackButtonListener` now returns the outcome of
   `_confirmLeave`, so a dismissed dialog leaves the back event unhandled.
   Tests added: back from `/join` reaches home in one step, and the
   dialog-dismiss path returns false. Push-vs-go is rebutted against
   `frontend-components.md` ("Back … otherwise leave + `context.go('/')`"),
   and `/join`'s back already reaches home via the shell handler.
3. **Fixed** (453d247, 34806dc) — announcements are gated on
   `MediaQuery.supportsAnnounceOf` with the live region retained as fallback;
   the viewer has its own `viewerTitle` ARB key. Tests added for the opt-out
   branch and the app-bar title.
4. **Fixed** (b58f6f7) — `ZcStrings.load` filters `@`-prefixed keys and
   non-`String` values instead of a lazy `Map.cast`; trailing newline
   restored. Test added: loading a map with metadata does not throw, and
   every loaded value is a `String`.
5. **Fixed** (b629a35) — `ViewerIdleState` maps to an empty title; the
   exhaustive switch is unchanged. Test added.
6. **Fixed** (7df7ec0) — home and drawer join labels read `ZcStrings`
   (`joinBroadcastTitle`, new `navJoinBroadcast`). Tests added.
7. **Fixed** (a222d52) — the unused `viewerCaptionTarget` lookup is gone from
   `_watchViewerBus`.

## CodeRabbit review 1

1. **Fixed** (221ade5) — `_announceIfChanged` returns early for an empty
   title, before touching `_announced` or the announcer; the duplicate-text
   check and the `supportsAnnounceOf` gate remain, and `_announced` now
   advances only when an announcement actually happens, so a status shown
   while opted out is announced once the setting returns. Tests added: empty
   title announces nothing, an empty first frame does not swallow the first
   real announcement, and the mid-session opt-out toggle.
2. **Fixed** (2d27ac0) — duplication verified before deletion: all five leave
   tests are byte-identical to rows in `viewer_screen_back_test.dart` (diff
   empty), the back file additionally covers system back from a direct route
   and an unhandled back event, and `_Logged.announcements` was written but
   never read. The duplicate file is deleted; the back file keeps coverage.
