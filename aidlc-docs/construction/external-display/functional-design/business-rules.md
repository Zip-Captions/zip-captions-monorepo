# Business Rules — Unit 8: External Display (S-20)

Rules are numbered `BR-U8-NN` and use **must**. They are testable statements;
the flow that enforces each is named in `business-logic-model.md` (sections)
and `frontend-components.md`. `pip-ux-parity.md`'s `BR-PIP-NN` rules belong to
the **pop-out unit** (D-1); this unit references that unit by name but defines
no pop-out behaviour and renumbers nothing.

**Revised 2026-10-20** per the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>).
Superseded and removed rules: BR-U8-06 (fallback move), BR-U8-10 (pop-out
close), BR-U8-16 (pop-out auto-open) — removed; BR-U8-17 (stop closes the
window) — **overturned by D-5** and replaced by the new BR-U8-17. Kept rules
keep their numbers.

---

## Window lifecycle

**BR-U8-01 — One window, serialised lifecycle.**
The app must never hold more than one secondary window. Every open, close and
re-frame must pass through the controller's single open guard, which
serialises them and refuses a second open while one is in progress. A toggle
on issued mid-open is a no-op.
*Flow: business-logic-model.md §2, §9.*

**BR-U8-02 — Closing releases every resource.**
After any close (switch off, `WindowClosed`, failed open, display disconnect),
the window id must be null, `CaptionOverlayTarget.isVisible` must be false, the
target must not be on `CaptionOutputTargetRegistry`, and the controller must
hold no open subscription for that window. Asserted as one invariant
(BR-U8-15).
*Flow: business-logic-model.md §5, §6.*

**BR-U8-03 — A failed open changes nothing observable except the notice.**
If `createWindow` throws (`reason = create_failed`) or no `overlayReady`
arrives within `overlayReadyTimeout` (`reason = ready_timeout`), the target
must not be registered, `isVisible` must stay false, the window id must stay
null (a half-open window from the timeout path is closed idempotently), and the
UI must end in `Failed(reason)` with `overlayEnabled` back to `false`. The
broadcaster must see a notice with fixed copy; nothing may be logged that
contains caption text or the raw launch argument.
*Flow: business-logic-model.md §2 steps 3/5.*

**BR-U8-04 — Close detection is the handshake plus the `'-1'` code, and must never throw into the UI.**
After the ready handshake (BR-U8-23), the **only** signal that the window is
gone is a `PlatformException` with code `'-1'` received from any
`invokeMethod`, `setFrame` or `closeWindow` call on that window id (D-9). The
controller must convert it to `WindowClosed`; it must not propagate out of the
controller's stream handlers or the shell's `unawaited` calls. No
ping/keep-alive probe exists (B-5: the superseded `D10` probe is removed); a
window that dies silently between pushes is discovered on the next push or
reframe, which is the accepted best-effort bound.
*Flow: business-logic-model.md §6.*

---

## Display enumeration and selection

**BR-U8-05 — The display list reflects the platform, not a cache.**
`DisplayEnumerator.displays()` and `changes` must report the platform's current
displays. No synthetic polling, no persistence of the list, no invented ids. A
same-id list with changed `bounds` or `isPrimary` is a change and must be
emitted (`domain-entities.md` event contract).
*Flow: business-logic-model.md §1.*

**BR-U8-07 — Resolution of a selection at open time; the saved id is never silently overwritten.**
The display used at open is: the id in `externalDisplayId` if it is present in
the current list; otherwise the primary display if one exists; otherwise the
first display in platform order. A value no longer present in the list must be
**kept** — it is what `WaitingForDisplay` waits for (D-4) — and is cleared or
replaced only by an explicit user selection. Selection by merely rendering the
list must not write settings; only an explicit user action does.
*Flow: business-logic-model.md §1, §5.*

**BR-U8-08 — A display with no label is still selectable.**
An empty `DisplayInfo.label` must render a generated label ("Display N", using
list position) and must not disable the row or use the label as a key. The
selection key is `id`, always.
*Flow: business-logic-model.md §1.*

---

## Window behaviour

**BR-U8-09 — The window is the selected display's work area, applied in fixed order and re-applied on rearrangement.**
On open, the window's frame must equal the selected display's `bounds`
(`visiblePosition` + `visibleSize`, logical top-left), applied in the order
`createWindow` → `setFrame` → `show` (B-6, D-3), so the first visible frame is
already on the target display. On every `changes` emission where `bounds` for
the selected id changed (resolution change, re-arrangement), the controller
must re-apply `setFrame` on the existing window id — no close/recreate, no
re-handshake.
*Flow: business-logic-model.md §2 step 6, §7.*

**BR-U8-11 — Web is excluded by capability, not by a platform check.**
Each entry point must decide by `DesktopWindowService.isSupported`, never by
`kIsWeb`, so there is exactly one capability rule and the web stub and any
future unsupported platform behave identically without a second branch.
*Flow: business-logic-model.md §1 (capability probe).*

**BR-U8-22 — Disconnect closes the window, keeps the output on, waits, and reopens (D-4).**
When `changes` shows the selected display disappeared while the window is
open, the controller must close the window and release it (BR-U8-02), emit
`DisplayLost`, and enter `WaitingForDisplay(savedId)` with
**`overlayEnabled` still `true`**. When `changes` shows a display with the
saved id returns, the controller must re-open the window on it (full §2 open
sequence). The waiting state must offer **Cancel**, which switches the output
off (`overlayEnabled = false`, state `Off`) while **keeping**
`externalDisplayId` (BR-U8-07).
*Flow: business-logic-model.md §5.*

---

## Content

**BR-U8-12 — Live content, not a snapshot at open.**
The window's captions must come from `OnScreenCaptionTarget.visibleCaptions`
(final portion) plus the current interim at each update, and its display
settings from `displaySettingsProvider` at each update. No copy of the buffer
may be cached as the authoritative state in the secondary engine for longer than
the last snapshot. A theme, font-size, scroll-direction, max-lines or
caption-position change in the main window must reach the window without a
reopen.
*Flow: business-logic-model.md §3.*

**BR-U8-13 — The window shows the broadcaster's settings, without per-input colour (D-7).**
The window must apply the broadcaster's `DisplaySettings` (font, size, scroll
direction, theme mode, `maxVisibleLines`) and the persisted caption position.
It must **not** apply `sourceColorValues` or any per-input
`AudioInputVisualStyle`: the window mirrors the main window's
`CaptionDisplayWidget` without per-input colour. Per-input colour on the
external display is Backlog (D-7).
*Flow: business-logic-model.md §3.*

**BR-U8-14 — Signed-out is the only mode.**
External display output must not read any auth provider, must not require a
session, and must behave identically signed in and signed out (S-20, M-REG-01).
No new auth call path may be introduced anywhere in this unit.
*Flow: business-logic-model.md §2.*

**BR-U8-15 — The closed invariant.**
At every point where `overlayEnabled` is `false`, all of: controller window id
is null, `CaptionOverlayTarget.isVisible` is false, target not on the registry
— must hold together. Checked in the shell's `dispose`, in the controller
after any close, and in the widget test that drives every close path.
*Flow: business-logic-model.md §6.*

**BR-U8-17 — Recognition events change only `activity`, never the window (D-5).**
Start, pause, resume and stop of recognition must change **only** the
snapshot's `OverlayActivity` value (idle/stopped → `standby`, active →
`live`, paused → `paused`, reconnecting → `live`). They must never open or
close the window, never write `overlayEnabled`, and never affect any other
target. Stopping yields `standby` with captions cleared by the **existing**
stop→idle buffer clear (`recording_screen.dart:81-108` →
`on_screen_caption_target.dart:163-170`); this unit adds no clearing logic of
its own. There is no "start paused"; `BroadcastRecordingNotifier` is not
modified.
*Flow: business-logic-model.md §4.*

**BR-U8-26 — Opaque surface; caption position persisted and applied (B-8).**
In external display mode the window surface must be **opaque**:
`OverlayConfig.opacity` (shipped default `0.9`) must **not** be applied. The
caption position (Proto-13 Caption Position selector, top/bottom) must be
persisted as `externalDisplayCaptionPosition`, carried in the launch config as
`OverlayConfig.position`, and applied to where the caption block sits inside
the surface.
*Flow: business-logic-model.md §2, §3.*

---

## Privacy and error handling

**BR-U8-18 — No caption text outside the window.**
Caption text, the snapshot, and the launch argument must never appear in logs,
exception messages, `OpenFailed.reason`, `WindowClosed` payloads, widget keys,
semantics labels, or test failure messages. Logs for this unit are fixed
strings plus an error type, matching `BR-U3-36` and SECURITY-03. The only
permitted `debugPrint` is `desktop_multi_window`'s own (it prints methods and
window ids, not arguments' contents — verified in `WindowChannel.swift`: it
prints `method handler not set.` only).
*Flow: every path.*

**BR-U8-19 — Malformed window input is dropped, never rendered.**
A `captionUpdate` or launch argument that fails to decode must be ignored (or,
for the launch argument, replaced by the fixed "Window unavailable" frame). It
must not throw out of a method handler, because an unhandled exception in a
secondary engine's method handler can tear down that engine. A launch that
fails to decode does not send `overlayReady`, so the main engine's ready
timeout converts it to `OpenFailed` (BR-U8-03).
*Flow: business-logic-model.md §2 step 4.*

**BR-U8-20 — Caption-surface contrast comes from the theme, not a literal.**
`OverlayWindowApp` must take its surface and text colours from `AppTheme`'s
`surface`/`onSurface` (dark: 0xFFDAE3F0 on 0xFF0B141D; light: 0xFF0B141D on
0xFFFAFCFF) and must not hard-code a colour literal for either. The AAA ratio
(>= 7:1) of those two pairs is already asserted in
`zip_core/test/pbt/theme_contrast_test.dart`; this unit **must not repeat that
assertion**, because a second copy of the same two constants cannot fail
independently and would drift from the theme without anyone noticing — the
review recorded exactly that. This unit's test instead asserts the *wiring*: a
widget test builds `OverlayWindowApp` with the dark attachment, swaps to the
light `DisplaySettings.themeModeSetting` in a new snapshot, and observes the
rendered `Scaffold`/`Material` surface colour change with it. That test fails if
the overlay introduces a literal, and stays green when the theme's own ratio is
what changes. (S-20 AC; NFR-5.1.)
*Flow: business-logic-model.md §3.*

---

## Launch and handshake

**BR-U8-21 — The switch starts off at launch; only the id and caption position persist (D-6).**
At launch the settings loader must force `overlayEnabled` to `false`
regardless of the stored value, and must honour only `externalDisplayId` and
`externalDisplayCaptionPosition` from stored values. No window may open at
launch; the first open in a process is either an explicit switch on or a saved
display reappearing while `WaitingForDisplay` (BR-U8-22).
*Flow: business-logic-model.md §8.*

**BR-U8-23 — One method handler, ready handshake, fixed timeout (D-9, B-5).**
The main engine must install **exactly one** `DesktopMultiWindow.setMethodHandler`,
installed by the controller **before** the first `createWindow`. The open is
treated as successful only on receiving `overlayReady` from the sub-engine; a
sub-engine that dies before installing its handler is caught by the same
timeout, not by a separate mechanism. `overlayReadyTimeout` is a named constant
(~10 s); expiry is `OpenFailed(ready_timeout)` (BR-U8-03). After the handshake,
close detection is BR-U8-04 only.
*Flow: business-logic-model.md §2.*

**BR-U8-24 — The codec is hand-written, versioned, and total-on-error (D-8, B-7).**
The snapshot and launch codecs must be hand-written in `zip_broadcast`
(no `zip_core` change), versioned (`v`), encode enums by name, and decode to
`null` — never throw — on malformed input, an unknown version, or an unknown
enum value. They must reject payloads whose UTF-8 byte length exceeds the named
`maxEncodedBytes` constant. `sessionId` and `sourceId` must never cross the
window boundary: the overlay side rebuilds `CaptionDisplayEntry` with the
decoded `key` as `entryId` and fixed placeholder `sessionId`/`sourceId`/
`timestamp`. `OverlayWindowLaunch` must have exactly one `mode` source
(`config.mode`). `key` is `CaptionDisplayEntry.entryId` (the Phase 8 segment id);
`v` is the field Phase 8 bumps for bilingual mode.
*Flow: domain-entities.md "Snapshot and launch codecs".*

**BR-U8-25 — The window mirrors the main window (D-7).**
The overlay window must render the shipped `CaptionDisplayWidget`
(`recording_screen.dart:131`) fed by the decoded snapshot entries, with the
pause marker row travelling as a buffer entry. No new caption widget, no
`sourceColorValues`, no per-input style (BR-U8-13).
*Flow: business-logic-model.md §3.*

---

## Testable Properties (PBT-01)

Properties identified at design, carried into Code Generation as PBT test
requirements (PBT-02/PBT-03/PBT-05 as applicable). Generated inputs, not only
the named example cases.

| ID | Property | Category | Subject |
|---|---|---|---|
| FP-1 | **Codec round-trip**: for every generated valid `CaptionOverlaySnapshot` and `OverlayWindowLaunch` (any `activity`, 0..max entries, any `settings` value, multibyte caption text), `decode(encode(x)) == x`. | Round-trip (PBT-02) | `domain-entities.md` snapshot/launch codecs |
| FP-2 | **Codec total-on-error**: for every generated malformed input (truncated JSON, wrong field type, unknown `v`, unknown enum value for `activity`/`settings`/`position`/`mode`, over-size payload), `decode` returns `null` and never throws. | Invariant (PBT-03) | same codecs |
| FP-3 | **Frame conversion**: `toPlatformFrame` is identity on Linux; on Windows every edge equals `bounds × that display's own scaleFactor` (including 0/missing → 1); on macOS `y_out = primaryFullHeight − top − height` with `x_out = left`, for arbitrary top-left logical frames including a non-primary target and negative-result cases. | Oracle/invariant (PBT-05/PBT-03) | `domain-entities.md` frame conversion |
| FP-4 | **Open resolution**: for any generated display list (0..n displays, any primary flag placement) and any persisted id (present, absent, empty), the resolved open target follows BR-U8-07 exactly, and an absent id is kept, never cleared. | Business-rule invariant (PBT-03) | `business-logic-model.md` §1/§5 |
| FP-5 | **State machine closure**: over every generated event sequence over the T1–T17 transition table (including duplicate/`changes`-coalesced no-ops and events in any order), the machine reaches only declared variants, never holds two states, the closed invariant (BR-U8-15) holds at every step where `overlayEnabled` is false, and a second concurrent open is refused (BR-U8-01). | Business-rule invariant (PBT-03) | `business-logic-model.md` state machine |

Components with no identifiable properties: `ScreenRetrieverDisplayEnumerator`
(thin plugin wrapper — behaviour pinned by BR-U8-05 example tests, no pure
transformation) and `ExternalDisplayControls`/`OverlayWindowApp` (rendering —
wiring asserted by BR-U8-20's widget test, no transformation to property-test).

---

## Explicitly out of scope

These are not rules, they are the fence.

| Item | Reason |
|---|---|
| **The pop-out entirely** (mode, toggle, content setting, size fields, `BR-PIP-NN` mappings) | D-1: split into its own Phase 2 unit **after** Unit 8, reusing this unit's window machinery, **blocking the v2.0 RC**. Unit definition pending. Its UX contract stays binding in `pip-ux-parity.md` §8, which this unit does not implement, edit or move. |
| **Native full-screen** of the external display | D-3: Backlog. The work-area frame is the full-screen stand-in for this unit. |
| **Per-input caption colour** on the external display | D-7: Backlog. BR-U8-13 forbids it in this unit. |
| Translation (bilingual) fields in the snapshot | Phase 8; the codec's `v` is the version field it bumps (BR-U8-24). YAGNI. |
| Always-on-top beyond the plugin's shipped behaviour | Settled in Infrastructure Design against the existing runners; a *new dependency* is the FR-9.5 gate. |
| Caption attribution in the window | Unit 6 Rule 8's deferral applies unchanged (no label on the wire or in `CaptionDisplayEntry`). |
