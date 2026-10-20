# Business Rules — Unit 8: External Display (S-20)

Rules are numbered `BR-U8-NN` and use **must**. They are testable statements;
the flow that enforces each is named. `pip-ux-parity.md`'s rules keep their
`BR-PIP-NN` identifiers and are referenced, never renumbered or restated (see
`business-logic-model.md` F-8.8 for the mapping).

---

## Window lifecycle

**BR-U8-01 — One window, two modes, mutually exclusive.**
The app must never hold more than one secondary window. Enabling a mode while
the other is open must close the other in the same serialised section before
creating the new window. Every open, close, re-frame and toggle must pass
through one guard that serialises them and refuses a second open while one is
in progress (the `BR-PIP-02` in-progress guard, applied to both modes).
*Flow: F-8.1, F-8.3.*

**BR-U8-02 — Closing releases every resource.**
After any close (disable, stop, OS close, mode switch), the window id must be
null, `CaptionOverlayTarget.isVisible` must be false, the target must not be on
`CaptionOutputTargetRegistry`, and the controller's settings listener must not
still be open. Asserted as one invariant (`BR-U8-15`).
*Flow: F-8.6.*

**BR-U8-03 — A failed open changes nothing observable except the notice.**
If `createWindow` throws, the target must not be registered, `isVisible` must
stay false, the window id must stay null, and the UI must end in
`ExternalDisplayFailed` with `overlayEnabled` back to `false`. The broadcaster
must see a notice; nothing must be logged that contains caption text.
*Flow: F-8.3 step 1, event table.*

**BR-U8-04 — Close detection is best-effort and must never throw into the UI.**
A failed `invokeMethod` on a dead window id must be converted to
`WindowClosed`; it must not propagate out of the controller's stream handlers
or the shell's `unawaited` calls.
*Flow: F-8.6 path C.*

---

## Display enumeration and selection

**BR-U8-05 — The display list reflects the platform, not a cache.**
`DisplayEnumerator.displays()` and `changes` must report the platform's current
displays. No synthetic polling, no persistence of the list, no invented ids. A
same-id list with changed `bounds` or `isPrimary` is a change and must be
emitted (`domain-entities.md` event contract).
*Flow: F-8.2.*

**BR-U8-06 — Fallback on disconnect is a move, not a recreate.**
When the selected display disappears and any display remains, the window must
be re-framed onto the primary display (or, with no primary, the first remaining
display) using `setFrame` on the existing window id. It must not be closed and
re-created. The broadcaster must be notified in the same step. The persisted
`externalDisplayId` must be updated to the fallback id so a later settings read
does not point at a display that is gone.
*Flow: F-8.5 step 2.*

**BR-U8-07 — Resolution of a selection at open time.**
The display used at open is: the id in `externalDisplayId` if it is present;
otherwise the primary display if one exists; otherwise the first display in
`platform order`. If `externalDisplayId` is absent from the current list, the
persisted value must be kept until the user selects a different display or
F-8.5 changes it — it must not be silently cleared. Selection by merely
rendering the list must not write settings; only an explicit user action does.
*Flow: F-8.2 steps 4-5.*

**BR-U8-08 — A display with no label is still selectable.**
An empty `DisplayInfo.label` must render a generated label ("Display N", using
list position) and must not disable the row or use the label as a key. The
selection key is `id`, always.
*Flow: F-8.2.*

---

## Window behaviour

**BR-U8-09 — External display placement is the whole display.**
In external display mode the window's first frame must equal the selected
display's `bounds` exactly, and must be re-applied on every `changes` emission
where `bounds` for the selected id changed (resolution change, display
re-arrangement). No inset, no margin, no "fits within" adjustment. The window
must stay user-resizable so a presenter on a mirrored projector can shrink it
beforehand if wanted.
*Flow: F-8.3, F-8.5.*

**BR-U8-10 — Closing the pop-out clears popped-out, and only that.**
`WindowClosed` in pop-out mode must set `popOutEnabled` to `false`, clear the
hint, and reset the toggle; it must not touch `overlayEnabled`,
`externalDisplayId` or captioning state. Conversely, BR-U8-17's stop path writes
`overlayEnabled = false` and must **not** clear `popOutEnabled`: stopping
captioning closes the external display, but a pop-out the user deliberately
opened stays open showing the last buffer until they close it. The two flags are
independent once both can be set.
*Flow: F-8.6. (`BR-PIP-03`).*

**BR-U8-11 — Web is excluded by capability, not by a platform check.**
Each entry point must decide by `DesktopWindowService.isSupported`, never by
`kIsWeb`, so there is exactly one capability rule and the web stub, the mobile
stub and any future platform all behave identically without a second branch.
*Flow: F-8.2 step 1, F-8.9.*

---

## Content

**BR-U8-12 — Live content, not a snapshot at open.**
The window's captions must come from `OnScreenCaptionTarget.visibleCaptions` at
each update, and its display settings from `displaySettingsProvider` at each
update. No copy of the buffer may be cached as the authoritative state in the
secondary engine for longer than the last snapshot. A theme, font-size or
scroll-direction change in the main window must reach the window without a
reopen.
*Flow: F-8.4. (`BR-PIP-05`, `BR-PIP-09`).*

**BR-U8-13 — The window shows the broadcaster's settings.**
The window must apply the broadcaster's `DisplaySettings` (font, size, scroll
direction, theme) and the per-input `AudioInputVisualStyle` for each
`sourceId`. It must not apply its own defaults because the secondary engine
cannot read the broadcaster's settings providers.
*Flow: F-8.4, F-8.7 step 4.*

**BR-U8-14 — Signed-out is the only mode.**
External display output must not read any auth provider, must not require a
session, and must behave identically signed in and signed out (S-20, M-REG-01).
No new auth call path may be introduced anywhere in this unit.
*Flow: F-8.3.*

**BR-U8-15 — The closed invariant.**
At every point where either mode flag is `false`, all of: controller window id
is null, `CaptionOverlayTarget.isVisible` is false, target not on the
registry — must hold together. Checked in the shell's `dispose`, in the
controller after any close, and in the widget test that drives every close
path.
*Flow: F-8.6.*

**BR-U8-16 — The pop-out never auto-opens.**
`popOutEnabled` may be persisted, but the app must not open a pop-out window
from stored state on launch. The first open in a process must be a user action.
*Flow: F-8.8 (`BR-PIP-10`).*

**BR-U8-17 — External display output stops when captioning stops.**
Reaching `BroadcastStoppedState`, or idle after a session, must write
`overlayEnabled = false` and close the external display window. It must not open
it, pause captioning, clear `popOutEnabled` (BR-U8-10), or change any other
target. The shell owns this listener; the recording screen's existing stop
handling (`recording_screen.dart:81-84`) runs `clearSession()` and navigates
inside the same callback, so the rule is stated over "stopped **or** idle after
a session" to be independent of that ordering.
*Flow: F-8.6 path B.*

---

## Privacy and error handling

**BR-U8-18 — No caption text outside the window.**
Caption text, the snapshot, and the launch argument must never appear in logs,
exception messages, `OpenFailed.reason`, `WindowClosed` payloads, widget keys,
semantics labels, or test failure messages. Logs for this unit are fixed strings
plus an error type, matching `BR-U3-36` and SECURITY-03. The only permitted
`debugPrint` is `desktop_multi_window`'s own (it prints methods and window ids,
not arguments' contents — verified in `WindowChannel.swift`: it prints
`method handler not set.` only).
*Flow: every path.*

**BR-U8-19 — Malformed window input is dropped, never rendered.**
A `captionUpdate` or launch argument that fails to decode must be ignored (or,
for the launch argument, replaced by the fixed failure frame). It must not
throw out of a method handler, because an unhandled exception in a secondary
engine's method handler can tear down that engine.
*Flow: F-8.7 steps 2-3.*

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
*Flow: F-8.7 step 4.*

---

## Explicitly out of scope

These are not rules, they are the fence. Each is either a recorded open
question or a deferral with a reason.

| Item | Reason |
|---|---|
| Always-on-top on Linux, if it needs a new plugin (OQ-1) | §8.8 item 15 is a manual/Unit 9 check, but a *new dependency* is the FR-9.5 gate. Platform-specific native window hints are settled in Infrastructure Design ID-5 against the existing runners. |
| UX-PIP-07 controls that do not exist (OQ-2) | Orientation/pane swap/translation/download are not Phase 2 features; §8.8 item 10 cannot be satisfied for controls the product does not have. |
| Web Document PiP (OQ-3) | S-20 excludes web from external display; §8.8 is not web-specific; a second rendering pipeline is phase-sized. |
| Persisted window size/position for the pop-out | Permitted, not required (`§8.9`). |
| Per-language windows, draggable split divider | Recorded out of scope by `§8.9`. |
| The pop-out content setting actually changing content | Applicable only with translation, which is not in Phase 2 (`BR-PIP-06`; F-8.8 table). |
| Hand-written HTML overlay on any non-web platform | Binding prohibition (`pip-ux-parity.md` §8.6, §8.9). |
| Caption attribution in the window | Unit 6 Rule 8's deferral applies unchanged (no label on the wire or in `CaptionDisplayEntry`). |