# Frontend Components — Zip Captions Viewer (Unit 7)

## JoinBroadcastScreen (new, zip_captions — inside the app shell)

**Route**: `/join` (added to the existing `ShellRoute`; `_screenTitle` maps
it to "Join").
**Entry points**: a "Join a broadcast" `TextButton` (or equivalent) on the
home screen beside the existing "Start captioning"/"History" actions, and a
nav-drawer item (mobile). The desktop nav rail is unchanged — the
home-screen affordance is the desktop entry point (Q6).

**Structure** (Proto-14):

- One `TextField` ("Broadcast ID or URL"), accepts a bare 6-char ID, a
  bare `host/b/{id}`, or a full URL (all parse identically — Rule 2).
- "Join" button (Proto-14 primary button).
- **Inline validation (screen-local)**: on submit,
  `BroadcastLink.parseInput(text)` — invalid → show Proto-14's field error
  ("That doesn't look like a valid broadcast ID or URL — check it and try
  again", ARB), button re-enables, **no navigation, no `join()` call, no
  network** (S-19 AC2). Valid → `context.go('/b/${id.value}')`.
- The screen holds **no session state** (the Proto-14 "Connecting"
  switcher state is the transient pre-navigation frame only; all real state
  renders on the viewer screen — one surface for form flow and deep links,
  Q6).
- No sign-in, no auth reads anywhere (FR-7.6).

## BroadcastViewerScreen (new, zip_captions — outside the app shell)

**Route**: `/b/:broadcastId` (top-level, outside the `ShellRoute` — no
bottom nav / nav rail / drawer chrome; immersive, Q6).
**Init**: `input = state.pathParameters['broadcastId']`; parse via
`BroadcastLink.parseInput` (a malformed path parameter → the notifier's
`join()` sets `InvalidInputState` — the screen renders it like any other
state). If the notifier is `Idle` or holds a *different* broadcast, call
`ref.read(viewerSessionProvider.notifier).join(input)` once (post-frame
callback, the `RecordingScreen` pattern); same non-terminal broadcast →
no-op (Rule 1).

**Layout**: a full-screen `Scaffold` with an `AppBar` (session name or
"Zip Captions" when the name is unknown, leading back button, trailing
"Leave" text/action) and a body that switches on `ViewerSessionState`:

| State | Rendering (Proto-15 approved pattern) |
|---|---|
| `Idle` | Not expected while mounted (init joins); if observed, render the connecting view for one frame |
| `Resolving` | Full-screen: spinner + "Connecting…" (no name yet — resolution in flight) |
| `Connecting` | Full-screen: spinner + "Connecting…" + "Joining {sessionName}" once `notifier.sessionName` is known (the approved "Joining…" copy — the static Backlog decision; no retry-count variation) |
| `LiveView(active, t)` | Caption view: `CaptionDisplayWidget(entries: session target, settings: displaySettingsProvider)` + the live status indicator (session name, Proto-15's status bar) |
| `LiveView(paused\|inactive, t)` | Caption view + **inline notice** "Captions paused by the broadcaster" (Proto-15 copy, verbatim, ARB) — the notice clears in place when activity returns to `active` |
| `Reconnecting` | Caption view (last captions remain visible — the session buffer is not cleared) + inline notice with spinner "Reconnecting…" (Proto-15) |
| `NotBroadcasting` | Full-screen state (Proto-15, verbatim): "Not currently broadcasting" + "{sessionName} hasn't started this broadcast yet. This page will connect automatically once it goes live." — with a **nameless fallback** copy when `sessionName` is null (an `offline` resolution carries no name): "This broadcast hasn't started yet. This page will connect automatically once it goes live." |
| `Ended` | Full-screen state (Proto-15, verbatim): "Broadcast ended" + "{sessionName} has ended. Thanks for watching." + nameless fallback |
| `Full` | Full-screen state (Proto-15, verbatim): "Broadcast full" + "This broadcast has reached its viewer limit. Try again later — someone may disconnect." + a "Try again" button (F-7.9; Rule 6: manual only) |
| `CannotConnect(r)` | Full-screen state, icon ⚠ + "Can't connect" title + the Rule 5 copy for `r` + a "Try again" button for every reason **except `NotFound`** (Rule 5) |
| `InvalidInput` | Full-screen state: "Can't connect" style icon + "That broadcast link is invalid. Check the URL and try again." (new, ARB) + no retry (the input is the problem; affordances are leave/back) |

**Caption view detail**: `entries` come from the session-scoped
`OnScreenCaptionTarget` (`notifier.viewerCaptionTarget`'s
`visibleCaptions` snapshot + `onVisibleCaptionsChanged` stream — the screen
subscribes while mounted); `settings` from `displaySettingsProvider`
(Rule 10). `CaptionDisplayWidget` is reused unmodified (Phase 1, zip_core).

**Leave / back (Rule 9)**:

- **Leave control** (AppBar): in active states (`Resolving`/`Connecting`/
  `LiveView`/`Reconnecting`) → `showDialog` confirm ("Leave the
  broadcast?" / "You'll stop receiving captions." / **Leave**–**Stay**,
  ARB); confirmed → `notifier.leave()` then `context.go('/')`. In
  non-active states → `notifier.leave()` + navigate immediately.
- **Back button / gesture** (a `BackButtonListener` on the screen, since
  the shell's listener is not in play outside the shell): identical logic —
  active state → confirm dialog (a "back" cancel stays on the screen);
  otherwise leave + `context.go('/')`.
- After `leave()`, re-entering via `/join` or a fresh deep link starts a
  new session (F-7.2).

**Screen-reader (Rule 13)**: the status text of the current state renders
inside a `Semantics` container (always readable) and every state *change*
fires a live announcement of the new status text (the mechanism —
`SemanticsService.announce` vs a `LiveRegion` wrapper — is a Code
Generation detail). Full-screen states pair a distinct icon with a
distinct text (never color alone — Proto-15's approved pattern, including
its `data-testid` naming, which the widget tests reuse as finders).

## Router and shell changes (zip_captions)

- `zc_router.dart`:
  - `/join` — new `GoRoute` **inside** the existing `ShellRoute`.
  - `/b/:broadcastId` — new top-level `GoRoute` **outside** the shell
    (`BroadcastViewerScreen(input: state.pathParameters['broadcastId']!)`).
  - Plain paths only (Rule 12 — no web URL strategy now).
- `ZcAppShell._screenTitle`: `'/join'` → "Join".
- `ZcNavDrawer`: new "Join a broadcast" item (route `/join`).
- `HomeScreen`: new "Join a broadcast" affordance (button row beside the
  existing actions).
- Nothing in `zc_app_shell.dart`'s back handling is touched (the viewer
  route is outside the shell and owns its own back logic).

## Localization

Every string above — state titles, state copy, inline notices, the confirm
dialog, "Try again"/"Leave"/"Stay", the join field label/error — is
externalized to the existing ARB setup (`packages/zip_captions/l10n/arb/`,
English source `app_en.arb`), per the project's English-only /
externalized-strings constraint. Proto-14/15 copy is transcribed verbatim
where the prototype approved it; the "new, ARB" copies are Unit 7's own
wording per Rule 5.

## Widget test surface (NFR Requirements input)

One widget test per approved state (Proto-14: default, invalid-input;
Proto-15: all 8 states + the two cannot-connect copy variants), driving the
real `BroadcastViewerScreen` against a fake `ViewerSessionNotifier`
(override `viewerSessionProvider`) and fake transport/status/receiver —
the Unit 6 testability pattern (every state individually testable, no real
Supabase/`flutter_webrtc`). Plus: confirm-dialog shown in active states and
not in terminal states; back-button both paths; join-screen valid→navigate /
invalid→error-no-navigate.
