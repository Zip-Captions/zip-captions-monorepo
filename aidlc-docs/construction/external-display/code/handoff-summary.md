# Handoff Summary — Unit 8 External Display: Code Generation -> Build and Test / PR

**Stage:** Code Generation (Part 2 complete) — **2026-10-20**
**Branch:** `feature/external-display` — **PR:** #37 (open, not pushed by this run)
**Plan:** `aidlc-docs/construction/plans/external-display-code-generation-plan.md` (26 steps, all ticked)
**Code summary:** `aidlc-docs/construction/external-display/code/unit8-summary.md`

## What was built

The whole of S-20, end to end:

- Display enumeration behind a one-file `screen_retriever` fence, with
  normalised ids, derived primary, and a re-read-and-diff change stream.
- A versioned, size-capped, never-throwing snapshot and launch codec.
- `OverlayWindowController`: one window at a time, a 10 s ready handshake,
  16 ms update coalescing, serialised open/close/fail, and the T1-T17 state
  machine including wait-for-saved-display-and-reopen.
- The sub-engine: launch predicate, entry that installs its handler before
  signalling ready, and the window itself (opaque, themed, positioned).
- The output targets section: per-display rows, one toggle, position
  selector, waiting and failure banners.
- Shell wiring: register/open and remove/close, and switch the output off
  when the window closes itself or fails to open.
- Borderless window styling on all three desktop runners.

## Final gate evidence

| Gate | Result |
|------|--------|
| `zip_broadcast` analyze / test | clean / 259 passed |
| `zip_core` analyze / test | clean / 603 passed, 4 skipped |
| `zip_captions` analyze / test | clean / 139 passed |
| `flutter build macos --debug` | succeeded |
| `screen_retriever` fence | exactly one file |
| Removed-API grep | no match in this unit's files |
| Lockfiles | no drift beyond the `screen_retriever` addition |

## Review comments addressed

PR #37 review comment 6281471308 (the functional-design revision, D-1..D-13)
is reflected throughout: no pop-out surface, no `window_manager`, no ping
probe, one main-engine method handler, `'-1'`-only window-closed detection,
work-area framing, wait-for-saved-display, and the caption position selector.

## What is left for a human

- **Windows and Linux compile.** Both runner callbacks follow the plugin's
  published signatures but neither toolchain is available on this machine and
  the plugin's C headers are not vendored here. CI's `build-verify.yml` is
  the first real check.
- **The Unit 9 manual checks** listed in `unit8-summary.md`: hot-plug with the
  output on, borderless on each platform, the shipped font on a real external
  display, an opaque surface, a theme change reaching the window, and
  recognition pause leaving the window on screen.
- **A real second display.** Every test here drives a fake display source;
  nothing in the automated suite proves the platform reports what the
  adapter expects.

## Open questions

- None blocking. The three deviations recorded in `unit8-summary.md`
  (`selectDisplay`'s method shape, the split production/test constructor, and
  the window owning its own `MaterialApp`) are all behavioural no-ops and are
  noted for the PR description rather than resolved differently.