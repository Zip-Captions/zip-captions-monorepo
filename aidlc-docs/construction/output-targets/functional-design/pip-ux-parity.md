# Section 8 — Picture-in-Picture UX Parity

**Status**: Draft, input to Unit 8 Functional Design.
**Purpose**: Defines the Picture-in-Picture user experience that v2.0 must reproduce for parity with Zip Captions v1 (v0.5.0-rc.5).
**Source of truth for V1 behaviour**: `aidlc-docs/v1-parity/picture-in-picture-v1-analysis.md`.
**Scope**: User-visible behaviour only. Implementation mechanism is Unit 8's to choose, within the platform constraints in §8.6.

---

## 8.1 What parity means here

V1 implements PiP with the browser Document Picture-in-Picture API, which moves a live caption element into a browser-provided floating window. That is an implementation detail of a web application. It is **not** the feature.

The feature is: **the user can pop the captions out into a small window that stays on top of other windows, and can bring them back.**

V2 is a Flutter application with its own windowing. It does not need, and must not attempt to reproduce, the V1 mechanism. There is no HTML overlay, no browser Document PiP call, and no DOM-surgery analogue. `desktop_multi_window` already provides the actual capability: a secondary window with always-on-top behaviour, created by the application on every desktop platform it ships on.

Parity is judged on the user-visible contract in this section: which controls exist, what they do, when they appear, and how the window behaves. How the window is created and how captions are rendered into it is an implementation decision made in the rest of the Functional Design.

---

## 8.2 Terminology

| Term | Meaning |
|---|---|
| **Main window** | The primary Zip Broadcast window. |
| **Pop-out window** | The small secondary window that displays captions and stays on top. This is the user-facing name for what V1 called the PiP window. |
| **Popped out** | The pop-out window is open. |
| **Caption surface** | The widget subtree that renders captions and the controls that belong to them. |

---

## 8.3 Control inventory

Each row names the V1 user-facing behaviour, the V2 requirement, and the identifier used throughout this section and in Unit 8's acceptance criteria.

| ID | Control | V1 user-facing behaviour | V2 requirement |
|---|---|---|---|
| UX-PIP-01 | Primary toggle in app chrome | Header button labelled `Picture in Picture` / `Exit Picture in Picture` | A toggle in the main window's app chrome, same two labels, an icon that reflects state. |
| UX-PIP-02 | Secondary toggle in the caption surface | Button inside the caption container, so the user does not have to find the header | A toggle inside the caption surface. It must remain usable from the pop-out window itself, so a user whose main window is behind other windows can still bring the captions back. |
| UX-PIP-03 | When the toggle appears | Visible when the platform supports pop-out, a caption surface exists, and a session is active or already popped out | Same three conditions, expressed in V2 terms: platform can create the window, a caption surface exists, and a session is active or already popped out. |
| UX-PIP-04 | Unsupported platform | Control is not shown at all | Control is not shown. Do not show a disabled control merely because the platform cannot pop out. |
| UX-PIP-05 | Hint and return | `Captions are displaying in Picture-in-Picture` with a `Return to Window` action, shown in the main window while popped out | Same hint and return action while popped out. Wording may say pop-out instead of Picture-in-Picture, but the two affordances are required. |
| UX-PIP-06 | Contents of the popped-out window | Original only / Translated only / Original and translated, as a stored setting | Same three-way setting and same three labels, independent of the in-window layout mode. |
| UX-PIP-07 | Controls available while popped out | Orientation toggle, pane swap, translation target select, download button and progress all travel into the floating window | All of these must be operable from the pop-out window. The main window's sidebar is not reachable from it. |
| UX-PIP-08 | Drawer behaviour | Opening PiP closes the settings drawer | Opening the pop-out closes the drawer. |
| UX-PIP-09 | Theme | Theme applied on open and kept live | Applied on open and kept live while open. |
| UX-PIP-10 | Window defaults | 640x320, user-resizable | Same default size, resizable, with a sensible minimum size. |
| UX-PIP-11 | Always on top | Inherent to the browser PiP window | The pop-out window stays above other application windows until closed. This is the defining property of the feature. |

---

## 8.4 Behavioural rules

**BR-PIP-01 — One pop-out window.**
At most one exists. Requesting a second does nothing; the toggle is the only way to open and close it.

**BR-PIP-02 — Toggle is idempotent.**
A second activation while an open is in progress must not create a second window. The implementation needs an in-progress guard equivalent to V1's `isOpening` flag.

**BR-PIP-03 — Closing by any means leaves a coherent state.**
Whether closed by the toggle, by the OS close button, or programmatically, the main window must reflect that the session is no longer popped out: the hint clears and the toggle resets.

**BR-PIP-04 — Recognition continues uninterrupted.**
Popping out must not stop, restart, or interrupt the active session.

**BR-PIP-05 — Content is live, not copied.**
The pop-out window renders the live caption stream. It must not snapshot captions at open time and must not run a second recognition or translation pipeline.

**BR-PIP-06 — The content setting applies only while translation is on.**
With translation off the pop-out shows original captions regardless of the stored content setting.

**BR-PIP-07 — The content setting is independent of the in-window layout mode.**
A user in split mode in the main window may have the pop-out show translated only, and the reverse.

**BR-PIP-08 — Split in the pop-out uses the main window's orientation and pane order.**
No separate arrangement setting for the pop-out. A user who wants a different arrangement resizes the window or changes the shared settings.

**BR-PIP-09 — Live update on setting change.**
Changing the content setting while popped out updates the window immediately, with no reopen.

**BR-PIP-10 — No persistence across launches.**
The pop-out must not reopen automatically on next launch. Remembering size and position is permitted as a preference; auto-opening is not.

**BR-PIP-11 — No caption content in logs or telemetry.**
Opening, closing, and rendering the pop-out must not log caption text. Failures log fixed strings plus the error, never content.

---

## 8.5 Availability in the Flutter application

V1 coupled PiP availability to Web Speech availability: a browser with Document PiP but no speech recognition hid the control, because PiP with nothing to display is pointless. That coupling was a workaround for a web application whose recognition and windowing capabilities came from the same browser.

**BR-PIP-12 — Window capability and recognition capability are separate gates.**

Where the control appears is decided by whether the platform can create the pop-out window. Whether the control is enabled is decided by whether there is anything to show.

This is a better result than V1 had, and the different architecture is what makes it possible:

| State | Control |
|---|---|
| Platform cannot create the pop-out window | Not shown (UX-PIP-04). |
| Platform can, no active session | Shown but disabled, with the reason stated. Popping out an empty caption surface is not useful, but the user should be able to see the feature exists. |
| Platform can, session active | Shown and enabled. |
| Platform can, session active, recognition engine unavailable | Shown and disabled, with the reason stated. |

**BR-PIP-13 — Recognition unavailability is a disabled state, not a hidden one.**
If no usable STT engine is present on the device, the toggle is disabled and explains why, rather than disappearing. The user can then act on the cause. V1 could only hide; V2 can inform.

**BR-PIP-14 — No feature exists for users who cannot perform speech-to-text.**
There is no user story for a session without a speech-to-text source, and none is introduced here. The disabled state in BR-PIP-13 is defensive handling of an unsupported configuration, not a planned feature. If such a story is ever added, for example a manual text-entry source or an interpreter typing mode, the pop-out control already has the right shape: it gates on whether there is caption content, not on how that content was produced.

---

## 8.6 Platform behaviour

| Platform | Pop-out window | Notes |
|---|---|---|
| macOS | Yes | Always-on-top secondary window. |
| Windows | Yes | Always-on-top secondary window. |
| Linux | Yes | Always-on-top behaviour is enforced by the window manager; verify during Infrastructure Design. |
| Web / PWA | Yes | The browser Document Picture-in-Picture API, as V1 uses it. The PWA is a release target, not a degraded fallback, and it is the same execution environment V1 ships in, so the mechanism is directly available. |

### Web / PWA: rendering approach

The web build is the one platform where the browser provides the floating surface for us, and where V1's approach carries over intact.

**The V1 approach is the reference.** V1 is an Angular application, so `DocumentPipService` moves a live caption DOM element into the browser-provided window and copies stylesheets into it. A Flutter web build cannot do that: Flutter renders to a canvas, so there is no DOM element to move.

**What V2 does instead.** The web build uses `documentPictureInPicture.requestWindow()` as the host surface, and renders the caption widget subtree into it using Flutter's own HTML renderer path, or an equivalent Flutter-side rendering into that document. The pop-out content is therefore produced by Flutter, not by hand-written HTML, and no DOM surgery is performed.

**Why this is acceptable on web and not elsewhere.** HTML is the platform's native rendering substrate, so using an HTML document as the pop-out surface is the natural mechanism, exactly as it is in V1. On macOS, Windows, and Linux there is no browser and no HTML document to host the surface; those platforms use a native always-on-top secondary window through `desktop_multi_window`. HTML overlay driven from Dart is not permitted on any non-web platform.

**If the browser lacks Document PiP.** The control follows UX-PIP-04: it is not shown. Today that means browsers other than Chromium-based ones. This is the same limitation V1 has and is not treated as a parity gap for the PWA target.

---

## 8.7 Relationship to the display target work

The pop-out window and the external display target share window machinery:

- Both are secondary windows created through the same service.
- `OverlayConfig.targetDisplayId` is relevant to both.
- They differ in intent: a pop-out is a small always-on-top window the user positions; an external display target is positioned on a selected display, typically full screen.

The Functional Design must decide whether these are two modes of one window component or two components sharing a service. They must not be implemented twice.

---

## 8.8 Acceptance criteria

Unit 8 is complete on this section when all of the following are demonstrably true:

1. The app-chrome toggle exists, uses both labels, and reflects state.
2. The in-surface toggle exists and is usable from the pop-out window itself.
3. The visibility rule (UX-PIP-03) holds in all combinations of platform capability and session state.
4. On a platform that cannot create the window the control is absent, not disabled.
5. With no active session on a capable platform the control is disabled and states why.
6. With no usable recognition engine the control is disabled and states why.
7. The hint and return action appear in the main window while popped out and clear on close.
8. The content setting offers all three options and applies only while translation is on.
9. The content setting updates the live pop-out without reopening.
10. Orientation toggle, pane swap, translation target select, and download progress all function inside the pop-out window.
11. Opening the pop-out closes the drawer.
12. Theme matches on open and updates live.
13. The window opens at 640x320 and is resizable.
14. Only one pop-out can exist; a double toggle does not create a second.
15. The window stays above other application windows until closed.
16. Closing by the OS close button leaves the main window in a coherent state.
17. Recognition continues without interruption across pop-out and return.
18. No caption text appears in logs on any of these paths.

**Automated versus manual**: items 1-3, 5-11, 14, and 18 are unit- or widget-testable. Items 4, 12, 13, 15, 16, and 17 require platform-level verification and belong in the Integration Milestones (Unit 9) rather than unit tests. Item 15 (always-on-top) is verified on desktop; on web it is the browser's PiP window and is not separately testable by the application.

---

## 8.9 Out of scope for this section

- Window chrome styling beyond what the theme provides.
- Remembering pop-out size and position across launches (permitted, not required).
- A draggable divider between panes (v1 US-C4, backlog).
- Per-language windows (v1 FR-W2, backlog).
- A manual text-entry caption source. No user story exists for it, and this section does not create one.
- Hand-written HTML for the pop-out surface on any non-web platform.

---

## 8.10 Evidence

- `aidlc-docs/v1-parity/picture-in-picture-v1-analysis.md` — V1 implementation and behaviour.
- V1 source: `packages/client/src/app/services/document-pip/document-pip.service.ts`, `header.component.ts:104-105,125`, `document-pip.component.html`, `recognition-render.component.ts:202-207`.
- V1 strings: `packages/client/src/assets/i18n/en.json` `LABELS.documentPip`, `LABELS.documentPipExit`, `HINTS.pipActive`, `HINTS.pipReturn`.
- V1 PiP content setting design: `aidlc-docs/construction/u3-split-orientation-pip/functional-design.md` §8.
- V2 roadmap Definition of Done: `docs/03-roadmap.md` Phase 6.
- V2 unit scope: `aidlc-docs/inception/application-design/phase2-unit-of-work.md` Unit 8.