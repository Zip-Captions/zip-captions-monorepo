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
| `WindowConfigurator` | seam + `_io`/`_stub` | `configure(windowId, config)` over a first-party `MethodChannel`; no plugin import; never throws to the caller |
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
None. The three questions this document originally carried were resolved during the review
(2026-10-21) and are recorded as section 10 of `nfr-requirements.md`:

- Router and enumerator ownership -> **A1**: a keepAlive `zip_core` provider owns the router and the
  single enumerator and exposes `createController(...)`; no app constructs them.
- Main-window-centre parameter -> **C**: stays `null` in production; multi-monitor placement is a
  Unit 9 platform check.
- Two-controller router proof -> **C**: unit-level routing tests plus a two-real-controller test with
  negative delivery assertions (a message for a closed window is dropped, not delivered to the other
  controller).
- Found during the review and added as constraints: the `PopOutMode` bootstrap must not depend on the
  display list, and a pop-out must not close on an empty `displaysChanged` event.

---

## Revision 2026-10-21 (post pre-build review)

Answers applied: RQ-1 A, RQ-2 A, RQ-3 A as amended. Read FD `handoff-summary.md`'s "Revision
2026-10-21" section first; it lists the constraints and the verify-not-assume claims.

### What changed in this document's source NFR-R
- §1.2: the always-on-top installer assertions became `WindowConfigurator` assertions (floating +
  decorated for `PopOutMode`), plus two new close-notification assertions.
- §3.1: `window_manager` failure row replaced by native `configure`; unknown-id `subWindowClosed` row added.
- §4.1: no new third-party dependency, so SECURITY-10's supply-chain question is gone; the macOS
  plugin-set limitation is **withdrawn** and a runner-code-coverage limitation added.
- §5.2: the overlay barrel is a separate library (R-M7).
- §10.2: the "null display id is inert" reasoning is withdrawn; six guards are mandatory (R-M2).
- §10.3: the frame is computed by the shell and passed in (R-M5).
- §10.5: new — the owner's three answers and their effects.

### Unchanged
Dependency placement for `desktop_multi_window` and `screen_retriever`, the per-app test matrix, the
lockfile fence's remaining expectation (`screen_retriever` positions only), the PBT plan, and every
performance number.

### Next stage inputs
NFR Design inherits §10.1-10.5 plus the FD revision section. It must also settle the three items
NFR-R §10.5 leaves to it: the router's provider wiring shape, the exact `configure` channel name per
platform, and the per-platform chrome-allowance constants.

## Revision 2 — 2026-10-21 (owner request changes)

- §1.2 item 2: `ExternalDisplayMode` → `configure(floating: false, decorated: false)` is **pinned**
  (was "either is acceptable"), with Unit 8's borderless surface recorded as dependent on it.
- §1.2's close-notification paragraph: the transport is a first-party channel on the **main** engine
  (`subWindowClosed {windowId}`), not `desktop_multi_window`'s internal window channel; the Dart seam
  is `SubWindowClosedChannel` → `controller.onNativeWindowClosed(int)`; it does not pass through the
  router. Tested in `zip_core` with a fake, including the app-initiated-close drop.
- §3.1: the unknown-id row is now `subWindowClosed`.
- Unchanged: every dependency decision, the lockfile fence, the PBT plan, all performance numbers.

## APPROVED — 2026-10-21

NFR Requirements (this document's source artifacts, revision 2) was **approved by James Petersen on
2026-10-21** together with the Functional Design, after the pre-build review.

**Next stage: NFR Design — NOT STARTED.**

### Open item carried into NFR Design

- **`SubWindowClosedChannel` registration order**: where the main-engine seam's channel handler is
  registered relative to `WidgetsFlutterBinding.ensureInitialized()` and the app's startup work, its
  lifetime owner, its `dispose()` with the container, and — critically — that it is listening before
  any sub-window can be created, so a window cannot close unheard.

### Constraint carried forward

§10.1-10.5 of `nfr-requirements.md` are binding. NFR Design must carry R-M2's six guards, R-M3's
router shape and R-M5's frame ownership into its own sections rather than re-deriving them.
