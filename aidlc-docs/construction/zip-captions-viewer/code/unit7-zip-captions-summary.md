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