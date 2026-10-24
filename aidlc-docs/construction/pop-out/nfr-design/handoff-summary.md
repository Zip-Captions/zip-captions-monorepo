# Handoff: NFR Design -> Infrastructure Design
**Unit**: 8.1 Pop-out Live Captions (S-21)
**Date**: 2026-10-21
**Status**: APPROVED 2026-10-21 by James Petersen

## Decisions made (all from `plans/pop-out-nfr-design-questions.md`)

| Q | Decision |
|---|---|
| D1 | **B, corrected.** `overlayWindowHost` owns `SubWindowClosedChannel`, installs on build, releases with `ref.onDispose`. No gap exists: only a controller creates a window, and each subscribes in `_bootstrap` before `open()`. Nothing in `main`, nothing in the sub-engine, no `ProviderContainer` in the handler. |
| R1 | **A.** One process-level `Stream<int> get closed`; each controller subscribes its own `onNativeWindowClosed` in `_bootstrap` and cancels in `dispose`. Unknown ids die by construction (no matching subscriber). |
| P1 | **A.** `open(config, {Rect? frame})`; `frame == null` keeps the external-display path; `PopOutMode` + null frame skips `setFrame`, keeps the plugin's frame, logs one fixed string at **`FINE`**. No moved test opens a pop-out controller (earlier justification withdrawn). |
| P2 | **A.** Gates read synchronously; an unresolved gate renders the disabled control with its reason; the press handler has no `await` before `open()`. |
| P3 | **A.** `chromeAllowance(TargetPlatform)` + five named constants; content-size semantics; table test. Values are **estimates, unverified until Unit 9** — not "verified in ID"; Linux varies by desktop/theme. |
| L1 | **A.** `windowId` tags the close event only; native styling targets the window the callback owns; no mismatch check. |
| L2 | **A** (+ D1). `OverlayWindowHost` owns router, enumerator, close channel; exposes `createController({mode, logPrefix})` and `Stream<List<DisplayInfo>> get displays`. |
| L3 | **A.** `keepAlive Notifier<bool>` in `zip_captions`; shell field in `zip_broadcast`; no persistence on any path. |
| L4 | **B.** Each `PopOutCaptionTarget` copies `caption_overlay_target.dart:94-102`. Rejected A (registry has no membership signal; would rewrite shipped code against BR-U8.1-01). |
| L5 | **Other.** `zip_core/overlay_window_configure` and `zip_core/overlay_sub_window_events`; Option A's validation rules unchanged. |

## Constraints for Infrastructure Design (do not re-derive)

- Framework: **Flutter only.** No new third-party dependency; no new action; no new dev dependency.
- The controller gains **no eighth deviation**, and **`dispose()` is byte-for-byte unchanged**: the
  moved `dispose` tests pass verbatim (`overlay_window_controller_test.dart:721-749` asserts
  `harness.enumerator.isDisposed` at `:736` and `:749`). Two handles make that true without editing
  the controller: `:702` disposes a reference-counted **`DisplayEnumeratorLease`** (delegates
  `displays`/`changes`/`primarySize`, releases one share, last release or `host.dispose()` disposes
  the real enumerator, idempotent), and `:708`'s `call(null)` already maps to `unregister(token)` in
  `router.installerFor`.
- Lease unit tests are part of the test obligations: last release disposes; an earlier release does
  not; double release is a no-op; `host.dispose()` disposes regardless (and a later last release is
  then a no-op).
- Both channels are `zip_core`-owned contracts implemented by every runner; IDs must verify the six
  runners against the plugin sources, and that `zip_captions`' runners (which have no callback today)
  gain one.
- The `argv` shape is verified: `["multi_window", "<id>", args]` on macOS (`FlutterWindow.swift:73`),
  Windows (`flutter_window.cc:100`), Linux (`linux/flutter_window.cc:45-46`).
- Windows/Linux compile evidence now exists in part: **Linux zip_broadcast compiles clean** on PR #40.

## Verify-not-assume list (carried; item 4 can change a decision)

1. A Dart message from the sub-engine at close time is lost.
2. macOS: notification delivery point relative to `deinit`.
3. Windows: the window-proc delegate's ordering against `HandleTopLevelWindowProc`.
4. **Linux**: `delete-event` vs `"destroy"`, given the plugin's `TRUE`-returning handler
   (`linux/flutter_window.cc:34-40`). If no notification is connectable, Linux degrades to the
   `'-1'` fallback — record it, do not redesign.
5. Runner signatures (R-B4 fixed on PR #40) and `argv` delivery (above).
6. The Flutter SDK the ID's claims are checked against (CI 3.38.7 vs local 3.41.7, R-m6).
7. ~~The chrome-allowance values~~ — **removed from ID's list**: they are Unit 9 measurements.

## APPROVED — 2026-10-21

NFR Design was **approved by James Petersen on 2026-10-21**, after one review-round-2 correction
(`dispose()` is unchanged; the enumerator is handed over as a reference-counted
`DisplayEnumeratorLease`). The three artifacts and this handoff are APPENDED with the approval.

## Open documentation corrections (for Code Generation / Documentation Refinement)

1. **FD `domain-entities.md` §2.2** (`ZcAppShell` row) says the shell becomes stateful "to own the one
   target and the in-memory flag". The flag lives in `popOutNotifierProvider`; the shell is stateful
   because it owns the target and the events subscription. Needs correction before Code Generation.
2. **FD `handoff-summary.md`'s "Constraints"** still lists `window_manager` in the `zip_core` gains
   list (superseded by RQ-1 A). Harmless but stale; fix with 1.
3. **`tech-stack-decisions.md` §2** says the macOS/Windows/Linux runners "register only the app's own
   `configure` channel". They also register the close channel on the **main** messenger; §2 should say
   so, since that is a new registration point on the main engine.

## Known risk carried into ID

PR #40's Windows zip_broadcast job fails in `permission_handler_windows` (MSVC 14.51 / VS 18,
`experimental/coroutine` STL1011) — a dependency, not our code; our Windows TU never compiled.
Owner decision pending (measure on `develop` / define the silence macro / pin MSVC / defer to ID).