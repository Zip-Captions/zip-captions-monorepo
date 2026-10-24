# Runtime Review Round 6 — Unit 8.1 (Pop-out Live Captions, S-21)

**Date**: 2026-10-23
**Branch under review**: `feature/popout-live-captions` at `7f27fa8`
**Requested by**: James Petersen — "record these deficiencies as work that needs to be completed".
**Scope**: Runtime verification of the merged code on macOS, iOS and Android, recorded as defects
against Unit 8.1's own acceptance criteria. **No code was changed in this round.** This document is
the handoff to the session that implements the fixes.
**PR**: #41 (blocked; see the PR comment posted 2026-10-23).
**Evidence**: `~/…/opencode/pr41/` (screenshots, launch logs, VM-service widget-tree dumps) and the
runtime tables in the PR comment. Nothing in this document is inferred from a design document where
runtime evidence exists.

Every finding below states the check, the observed result, the code path, and what "done" means. A
later session must re-verify each finding before acting on it
(`.aidlc-rule-details/common/overconfidence-prevention.md`); two of the four causes are not yet
narrowed past a candidate list and say so.

**Stage effect**: PR #41 does not merge as-is. Fixes are TDD-first additions to
`plans/pop-out-code-generation-plan.md` (new steps, Groups H onward) or, where a finding proves the
design wrong rather than the code, an amendment to the owning design document with per-change
approval. Findings R6-1 and R6-2 are correctness defects inside the unit's stated scope and block
the merge. R6-3 and R6-4 block too, because they are cheap and both are cited acceptance criteria of
the unit (BR-PIP-13, BR-U8.1-11), but a reviewer may decide to split them into their own small PR
against the same branch.

---

## 0. What was checked, and how

| Check | Platform | Method | Result |
|---|---|---|---|
| A1 session starts, captions render | macOS | human at the keyboard, VM-service inspector | PASS |
| A2 chrome toggle opens the pop-out | macOS | press, then `CGWindowListCopyWindowInfo` for 15 s | **FAIL** |
| A10 no-session availability | macOS | VM-service inspector on Home | **FAIL** |
| C1 no pop-out UI on an unsupported platform | iOS 26.0, Android 16 | VM-service inspector, live recording screen | PASS |
| C3 no control flash on session start | iOS | human observation | **FAIL** |
| A4-A9, B1-B4 | macOS | — | BLOCKED (no window ever opens; OS-close checks need Accessibility) |
| C2, web half of C3 | web | — | OUT OF SCOPE (roadmap v2.0) |

Accessibility was not granted on the review host (`AXIsProcessTrusted == false`), so every check that
needs synthetic input or System Events is BLOCKED, not passed. Screen recording worked, so the window
list and screenshots are direct evidence rather than inference.

---

## 1. R6-1 — The pop-out never opens; the exit label and banner revert silently after ~15 s

**Severity**: blocker. The unit's headline behaviour does not work on the only platform where it was
runtime-verified.
**Check**: A2, and through it A3, A4, A5, A6, A8, A9, B1-B4.
**Observed** (macOS 15.7.5, debug build of `7f27fa8`):

1. Start a session; captions flow (A1 PASS).
2. Press the Picture in Picture control in the nav rail.
3. The chrome label becomes `Exit Picture in Picture` and `PopOutBanner` appears in the main
   window. The in-surface toggle appears.
4. No pop-out window is ever created. `CGWindowListCopyWindowInfo` (all windows, all screens,
   `kCGWindowListOptionAll`) shows the main `zip_captions` window (layer 0) and, from the moment
   the plugin initialises, a `1x1` offscreen helper window — nothing else, at any point in the
   15 s.
5. After ~15 s the banner disappears and the label reverts to `Picture in Picture`. No message, no
   dialog, no snackbar.

**Code path** (verified against source at `7f27fa8`):

- The revert is `OpenFailed` -> `_onPopOutEvent` (`zc_app_shell.dart:64-72`) ->
  `_unregisterPopOut(); _setPoppedOut(false);`. `_setPoppedOut` is the only thing that clears
  `popOutBanner` and the exit label, so the observed revert identifies the event.
- The controller emits `OpenFailed` from exactly one place, `_runFail`
  (`overlay_window_controller.dart:698-703`, `_emit(OpenFailed(code))`), reached from
  `_failOpen(_readyTimeoutCode)` at `:715` (`_onReadyTimeout`) and `_failOpen(_displayLostCode)` at
  `:280`. A pop-out is never framed to a display, so the display-lost path does not apply: the
  timeout did.
- The timeout means the sub-window was created but never sent `overlayReady`. The controller's
  `_onReadyTimeout` logs `'overlay ready timeout'`, and that line **did not appear** in the launch
  log (`zc-macos.log` contains no `overlay ready timeout` and no `OpenFailed`). Cause: the
  controller's logger is never routed to stdout/`flutter:` by either app — see R6-5.

**Candidate causes** (not yet discriminated; the fixes below must start by discriminating them):

1. **The ready notification is dropped on macOS.** R-B1 of `pop-out-pre-build-review.md` fixed
   the window-created callback to register *only* the app's own `configure` channel. If the
   sub-engine's `overlayReady` arrives through a channel the callback no longer installs, it is
   silently discarded and the open ends exactly this way: window present, no ready, timeout.
2. **The sub-engine entrypoint hangs or throws before sending ready**, leaving a created-but-blank
   window. The `1x1` helper alone does not prove the pop-out's own window was created, so this is
   not excluded.

**Discrimination step (do this first, before changing code)**: capture, for one open attempt,
(a) the full `CGWindowListCopyWindowInfo` dump every 500 ms with window ids and frames, to see
whether a second window is ever created and whether it is ours; (b) the sub-engine's own
`flutter:` output, which `flutter run` interleaves with the main isolate's; (c) the controller's log
lines, once R6-5 routes them. That narrows to cause 1 or 2 without guesswork.

**Done means**: pressing the chrome toggle on macOS creates one visible pop-out window within the
10 s budget, the banner appears, and either (a) the window shows live captions and the plain-empty-
body rule applies, or (b) the failure surfaces a user-visible reason (R6-3). The A2-A9 rows then
become runnable and must be run.

**Tests to add** (TDD-first, before the fix):
- `zip_core`: a test that an `overlayReady` arriving on the sub-engine's messenger reaches the
  controller — the round-5 router tests cover the router, not the runner wiring; the gap is
  integration-shaped and belongs in a runner-level or host-level test if one can be written without
  a real window.
- `zip_captions`: a shell-level test that `OpenFailed` clears the banner *and* surfaces the reason
  string named in R6-3, so the silent revert cannot come back.

---

## 2. R6-2 — The availability rule reports different results for identical state

**Severity**: blocker. The control can be pressed when it must not be, and the reason text the UX
contract requires is absent.
**Check**: A10.
**Observed**: Home screen, session stopped and left. Two reads of the same state on the same build:

| When | `popOutToggle.enabled` | `popOutToggleReason` |
|---|---|---|
| 21:37 | `false` | present: "Start captioning to pop captions out" |
| ~22:00 | `true` (and pressable) | absent |

**Code path**: `popOutAvailability` (`zip_core/lib/src/output/overlay/pop_out_availability.dart:77-92`)
is a pure function of `(status, recording, engineAvailable)`, so identical inputs cannot produce
different outputs. Either an input differed between the two reads, or the widget has a second source
of truth. The likely input: `status`. The shell reads

```dart
final popOutStatus = ref.watch(popOutStatusProvider).valueOrNull ??
    ref.watch(popOutWindowControllerProvider).status;
```

(`zc_app_shell.dart:200-201`), and `popOutStatusProvider`
(`zip_captions/lib/src/providers/pop_out_providers.dart:46-51`) is:

```dart
yield controller.status;
yield* controller.statusChanges;
```

`statusChanges` is a broadcast stream. When `popOutStatusProvider` is disposed and rebuilt by
Riverpod (it is not `keepAlive`; the shell is the only watcher, and any rebuild-forcing dependency
change recreates it), the `async*` body re-subscribes to the broadcast stream. Whether the first
`yield` reflects the current status depends on when the body ran relative to the rebuild, and
anything emitted between disposal and resubscription is lost — a classic autoDispose+broadcast
subscription race. The first read arriving as `enabled: false` with the no-session reason is the
correct behaviour; the second read returning `enabled: true` with no reason means `visible: true,
enabled: true`, which the pure rule can only produce when `sessionActive && engineAvailable`.

**Charge for the fixing session**: do not guess. Reproduce with a widget test that drives the shell
through start -> stop -> Home and asserts the availability twice, before and after a rebuild that
recreates the provider. If the test cannot distinguish the two reads, capture `controller.status` and
`recordingStateNotifierProvider`'s value at both reads in the running app. Whichever input differs,
the fix is to remove the second source of truth: either make `popOutStatusProvider` a
`StreamProvider` that seeds from a `ValueNotifier`/`BehaviorSubject`-equivalent (replay the current
value on subscribe by construction, not by a racy first `yield`), or have `popOutAvailability`
receive `controller.status` directly and drop the stream from the decision path.

**Done means**: the same state yields the same availability on every read and after every rebuild;
with no session, `enabled` is `false` and `popOutToggleReason` shows the no-session string; a
widget test pins both statements.

---

## 3. R6-3 — An open failure has no user-visible reason

**Severity**: major. Required by BR-PIP-13 and pip-ux-parity §8.8 in spirit; the current behaviour
tells the user nothing.
**Observed**: A2. The window fails to open and the UI returns to its pre-press appearance with no
explanation; the user cannot distinguish "opening" from "broken".
**Existing surface**: `OpenFailed(code)` carries `create_failed` or `ready_timeout`
(`overlay_event.dart:33`, `overlay_window_controller.dart:888`), and the shell's handler already
receives it (`zc_app_shell.dart:64-72`) — it discards the code.
**Done means**: a fixed per-code string (ARB, English plus the existing translation set) is shown
when the open fails — a `SnackBar` or an inline line next to the chrome toggle, whichever the
design's error-surface rules already prescribe; if none prescribes it, add the rule first and get it
approved. No transcript content in the string (BR-U8-18). A widget test drives `OpenFailed` through
the shell and asserts the string appears and clears on the next successful open.

---

## 4. R6-4 — A pop-out control flashes on session start on iOS and Android

**Severity**: major. Contradicts BR-U8.1-11 / UX-PIP-04 ("nothing renders at all").
**Check**: C3, observed on iOS 26.0 (simulator, iPhone 17). Android was not observed for this
check but shares the code path.
**Observed**: on a fresh launch, tapping Start Captioning paints a pop-out control for one or more
frames on the transition, then it disappears once the status resolves.
**Code path**: `popOutAvailability` hides only when `status is Unsupported`
(`pop_out_availability.dart:77-80`). The shell falls back to `controller.status` while the stream has
no value (`zc_app_shell.dart:200-201`). On the frame the recording starts, the controller has not yet
reported `Unsupported` (the probe runs asynchronously from `_bootstrap`), so the rule sees a
non-`Unsupported` status with an active session and returns `visible: true, enabled: true`. The next
frame the stream delivers `Unsupported` and the control vanishes.
**Related pre-existing issue**: the shell's own comment at `zc_app_shell.dart:196-199` says the
stream is watched precisely so "a failed display probe leaves it `Unsupported`" reaches the chrome
(review round 3, finding 3). That round fixed the *steady-state* mount; this finding is the
*transition*. Both go away if the platform capability is a synchronous fact rather than a probed
status.
**Done means**: on iOS and Android, no pop-out control paints on any frame, cold start or session
start. Preferred fix: make capability a synchronous input to the availability rule (the controller
knows whether `DesktopWindowService` is supported before probing; `isSupported` is a constant per
platform), keeping the async `Unsupported` path only for the runtime failure case. Test: a widget test
that builds the shell with the status undefined and an active session, on an unsupported platform,
and asserts the control is absent on the first frame (i.e. never built), not merely absent after a
pump.

---

## 5. R6-5 — Neither app routes the overlay controller's log to its console

**Severity**: major (diagnostic). It is why R6-1 has to be investigated twice.
**Observed**: `OverlayWindowController._onReadyTimeout` logs `'overlay ready timeout'` and Windows/
Linux/macOS failure paths log fixed strings; none appear in `flutter run` output for either app.
`OverlayWindowHost` takes an optional `log` and defaults it to `Logger('zip_core.OverlayWindowHost')`
(`overlay_window_host.dart:37`), and `overlayWindowHostProvider`
(`zip_core/lib/src/providers/overlay_window_host_provider.dart`) constructs the host with no logger.
**Constraint**: logging must stay payload-free (BR-U8-18). Route the fixed strings to the platform
console in debug mode only; no transcript, no config, no window contents.
**Done means**: a debug build of either app shows the controller's fixed strings in `flutter run`
output, and a test asserts the logger is wired in debug and not in release. If adding console output
is judged out of scope for this unit, record that decision in writing here rather than leaving the
gap silent — but then R6-1's investigation must use the window-list capture instead.

---

## 6. Not defects, but recorded because they were seen

- **The control lives in the nav rail** (`ZcNavRail.headerAction`, `zc_nav_rail.dart:46-51`, a fixed
  `SizedBox(width: 72)`), smaller and misaligned against the rail's destinations, and its label
  overflowed before the session started. `fd frontend-components.md` §3 specifies the chrome toggle
  in the app chrome; whether the rail *is* the specified chrome is a design question, not a code
  defect. The fixing session should confirm against §3 before moving anything, and if the rail is
  correct, fix only the sizing/alignment/overflow.
- The `desktop_multi_window` `1x1` offscreen helper window exists from plugin initialisation, before
  any pop-out is requested. Expected plugin behaviour as far as the evidence shows; not a finding.

---

## 7. Handoff to the fixing session

1. Read this document, then `pop-out/code/summary.md` and `pop-out/code/handoff-summary.md`.
2. Discriminate R6-1's two candidates with the capture in §1 before writing any fix.
3. Write the failing tests named in each finding, then fix. Extend
   `plans/pop-out-code-generation-plan.md` with a Group H, or open a `pop-out-review-round-6-fix-plan.md`
   if the work is large enough to deserve its own Part 1.
4. Re-run the blocked checks on macOS with Accessibility granted; A4-A9 and B1-B4 are the ones that
   need it.
5. Re-run C3 on both iOS and Android.
6. Update the PR #41 comment with the before/after for each finding.

Windows and Linux were not run in this round and this document claims nothing about them.