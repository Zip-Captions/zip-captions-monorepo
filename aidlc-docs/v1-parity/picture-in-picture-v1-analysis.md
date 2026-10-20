# V1 Picture-in-Picture Analysis

**Date**: 2026-10-19
**V1 baseline**: `78637386a79db6ac965ad12952b8c4e4acde3b80` (`release/v0.5.0`, tag `v0.5.0-rc.5`)
**V1 version**: v0.5.0-rc.5
**Purpose**: V1 implementation description to inform V2 feature parity.

---

## Executive Summary

V1 Picture-in-Picture is the browser **Document Picture-in-Picture API** (`window.documentPictureInPicture`), used from an Angular 16 web client. It is not a native always-on-top window, not Electron, and not platform window management: a live caption element is physically moved out of the main document into a browser-provided floating window, and moved back on close. It is production quality, well tested, and has a clean service boundary (`DocumentPipService`). The single most important fact for a V2 planner: **the entire mechanism is a web-platform API with no desktop equivalent**. V1 on macOS/Windows/Linux runs this code inside a browser tab; a V2 Flutter desktop app has no `documentPictureInPicture`, so parity means building a separate always-on-top window, which the Unit 8 overlay work already approaches from a different direction.

---

## User-Facing Behaviour

- A control in the app header toggles PiP on and off, labelled "Picture in Picture" / "Exit Picture in Picture" (`en.json` `LABELS.documentPip`, `LABELS.documentPipExit`).
- A second toggle exists inside the caption container, so it is reachable without the sidebar.
- The control is only shown when PiP is supported **and** a caption element has been registered **and** either a recognition session is active or PiP is already open (`header.component.ts:104-105`).
- Opening pops out 640x320 by default; the window is user-resizable and draggable by the OS/browser.
- The caption pane moves entirely into the floating window, including the translation target selector, the language swap button, and the download-progress controls. The sidebar and settings drawer stay behind.
- Opening PiP closes the drawer (`recognition-render.component.ts:202-207`).
- Closing the floating window (X button) restores the element to its exact original DOM position via a placeholder comment node.
- Theme is carried into the PiP window and kept live: a store-driven effect rewrites `data-theme` when the app theme changes.
- While PiP is active the app hints "Captions are displaying in Picture-in-Picture" with a "Return to Window" action (`HINTS.pipActive`, `HINTS.pipReturn`).
- PiP content is configurable while translation is on: original only, translated only, or split (bilingual). See the translation analysis for `PipContent`.

---

## Implementation

### Location

| Package | File | Role |
|---|---|---|
| `packages/client` | `src/app/services/document-pip/document-pip.service.ts` | The whole mechanism. 190 lines, no dependencies beyond Angular DI and NgRx store for theme. |
| `packages/client` | `src/app/services/document-pip/document-pip.service.spec.ts` | Unit tests for the service. |
| `packages/client` | `src/app/components/header/header.component.ts` / `.html` | Header toggle. |
| `packages/client` | `src/app/modules/media/components/document-pip/document-pip.component.ts` / `.html` | Inline toggle inside the caption container. |
| `packages/client` | `src/app/modules/media/components/recognition-render/recognition-render.component.ts` | Registers the caption element, closes the drawer when PiP opens. |

### Mechanism

The service declares the API itself (TypeScript `lib.dom` had no types for it at the time):

```ts
interface DocumentPictureInPicture extends EventTarget {
  window: Window | null;
  requestWindow(options?: DocumentPictureInPictureOptions): Promise<Window>;
  onenter: ((this: DocumentPictureInPicture, ev: Event) => any) | null;
}
declare global {
  interface Window { documentPictureInPicture?: DocumentPictureInPicture; }
}
```

Support gate requires **both** Document PiP and Web Speech:

```ts
const hasDocPip = typeof window !== 'undefined' && 'documentPictureInPicture' in window;
const hasWebSpeech = typeof window !== 'undefined' && ('SpeechRecognition' in window || 'webkitSpeechRecognition' in window);
this.isSupported = Boolean(hasDocPip && hasWebSpeech);
```

That pairing is deliberate: PiP with nothing to display is pointless, so a browser lacking speech recognition is treated as unsupported even if it has the PiP API.

`open()` does, in order:

1. Guard `isSupported`, element registered, not already open, not already opening (`isOpening` re-entrancy flag).
2. Capture the registered `ElementRef` into a local so a deregistration race can be detected.
3. `await window.documentPictureInPicture.requestWindow({ width: 640, height: 320 })`.
4. Re-check that the element reference is still the registered one; if not, close the new window and bail.
5. `_copyStyles(pipWindow.document)` — copies every `document.styleSheets` rule via `cssRules`, falling back to a `<link href>` clone for cross-origin sheets that throw on `cssRules`. Also clones `link[rel="preconnect"]` (font origins).
6. Set `data-theme`, zero out body margin/padding/overflow, make body a 100vw/100vh flex column.
7. Insert a `Comment('document-pip-placeholder')` at the element's current position.
8. `pipWindow.document.body.appendChild(targetElement)` — the actual move. Angular keeps its binding because it is the same DOM node, just reparented.
9. `pipWindow.addEventListener('pagehide', ...)` restores the element and clears state.

`close()` closes the window, restores the element, clears state. `_restoreElement()` is idempotent through the placeholder guard.

`toggle()` is `isPipActive() ? close() : open()`.

State exposed to components is three signals: `isSupported` (plain boolean), `isPipActive`, `hasElement`.

### Platform Coverage

| Platform | Supported | Mechanism | Notes |
|---|---|---|---|
| Chrome/Edge desktop | Yes | Document PiP API | Requires Chrome 116+; the app's support gate also requires Web Speech. |
| Safari | No | — | No `documentPictureInPicture`. Falls back to the normal caption view with the control hidden. |
| Firefox | No | — | Same. |
| Chrome on Android/iOS | No | — | Document PiP is desktop-only. |
| macOS / Windows / Linux native | Not applicable | — | V1 ships as a web app; the desktop story is the browser. |

No feature flag. No polyfill. Unsupported browsers simply don't see the control.

---

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| `@angular/core` | Angular 16 | DI, signals, `effect`. |
| `@ngrx/store` | NgRx (Angular 16 line) | Theme selector for cross-window theme sync. |
| Browser Document PiP API | Chrome 116+ | The mechanism itself. |
| Web Speech API | any | Second half of the support gate. |

No third-party PiP package.

---

## Data Flow

1. `recognition-render` registers the caption container element with the service on init (`registerElement`).
2. Header or inline button calls `documentPip.toggle()`.
3. Service requests a PiP window from the browser.
4. Service copies stylesheets, sets theme, moves the registered element node into the PiP document.
5. Angular continues to render into the moved node; captions update in the floating window with no extra plumbing, because it is the same live DOM subtree and the same component instance.
6. Theme changes reach the floating window through the store `effect` in the service constructor.
7. On close or `pagehide`, the node returns to the placeholder.

There is no serialization, no message passing, no second render pipeline. That is the central design property and the main thing V2 cannot reproduce.

---

## Constraints and Limitations

- **Single PiP window.** One at a time by browser design; `documentPictureInPicture.window` is per-window, verified in `aidlc-docs/audit.md:166`.
- **Element move, not content copy.** Only one DOM node can live in one document, so the caption view is temporarily absent from the main window while popped out.
- **Cross-origin stylesheet fallback is lossy.** Sheets that throw on `cssRules` are linked by href, which re-fetches but cannot inline overrides.
- **No persistence.** PiP open/closed state is not saved; the window does not reopen after reload. Deliberate: the browser controls the window lifetime.
- **No sizes beyond 640x320.** The window is user-resizable but the app has no PiP-specific layout logic; it inherits the same layout settings as the main window.
- **Support gate couples PiP to Web Speech.** A browser with PiP but without Web Speech reports unsupported. Some accessibility browsers may fall in that gap.
- **Not available on mobile**, including Chrome Android, which has no Document PiP.
- **`isSupported` is captured once at construction**, so it does not react to environment changes (irrelevant in practice).
- **`console.warn` / `console.error` on the unsupported and failure paths.** No caption text is logged.

---

## Test Coverage

`document-pip.service.spec.ts` covers the service in isolation: support detection, open/close/toggle, element move and restore, placeholder handling, style copying, theme application, deregistration while open, and the race where the element is deregistered during `requestWindow`.

Not covered, per the functional design's own note: component-level PiP behaviour depends on the `webkitSpeechRecognition` setup gap that predates this feature, so component rendering of the moved element is covered by manual/agentic verification rather than unit tests. `aidlc-docs` records a Puppeteer check of the release candidate but not of PiP specifically.

---

## Observability and Privacy

Only `console.warn`/`console.error` with fixed strings and error objects. No caption text, no transcript content, no telemetry, no analytics events. Moving a live DOM node does not send data anywhere. The PiP window is same-origin and local.

---

## Implications for V2 Parity

- **The V1 mechanism has no direct Flutter equivalent.** `documentPictureInPicture` is a browser-only API. On Flutter desktop the parity target is an always-on-top, resizable, frameless secondary window that renders the caption view.
- **V2 already has the pieces, unconsumed.** `desktop_multi_window: ^0.2.0` is a dependency, `DesktopWindowService` exists with create/close/invoke, and `CaptionOverlayTarget` encodes `targetDisplayId`. What is missing is the secondary-window entry point in `packages/zip_broadcast/lib/main.dart` and a call to `show()`. This is Unit 8 work, so PiP parity and Unit 8 should be designed together rather than as separate features.
- **The web build cannot reuse the V1 approach wholesale, but can use the same API.** A Flutter web build in Chrome can call `documentPictureInPicture`, but it cannot move the Flutter canvas into it the way V1 moves an Angular DOM node. A web PiP would need a separate HTML overlay driven from Dart, which is the same shape as the desktop secondary window: a second render surface, not a DOM move.
- **Behaviour to reproduce for parity:**
  - Toggle from the app chrome, with an in-surface toggle so it is reachable when the main window is not focused.
  - Hide the control when unsupported rather than showing a disabled button.
  - Remember whether it was popped out only as a preference, if at all; V1 does not persist it.
  - Return to the main view when the floating window closes.
  - Carry the theme.
- **Behaviour not to carry forward:** the coupling of PiP availability to speech-recognition availability. In V2 the recognition engine is independent of window capability, so the gate should be on windowing support alone.
- **New V2 concerns with no V1 analogue:** multi-monitor placement (V1 had none, the browser chose), always-on-top policy per platform, and interaction with recording/capture of the overlay window. These need a design decision, and the desktop specifics are exactly what makes this a research-friendly area rather than a port.
- **No new dependency is needed for desktop PiP** beyond what Unit 8 requires. A web PiP would need no dependency either (it is a browser API), but does need a second rendering path.
- **Suggestion:** fold PiP into the Unit 8 functional design as a named mode of the overlay window, rather than adding a roadmap line item with its own phase. The user-facing feature is distinct, but the implementation surface is shared.

---

## Evidence

- `git log -1` — `78637386a79db6ac965ad12952b8c4e4acde3b80`, tag `v0.5.0-rc.5`, branch `release/v0.5.0`.
- `grep -rln "pictureInPicture|PictureInPicture" packages` — hits only in `document-pip.service.ts`, its spec, and `translation-settings.component.ts`.
- `cat packages/client/src/app/services/document-pip/document-pip.service.ts` — full source, 190 lines.
- `packages/client/src/app/components/header/header.component.ts:104-105,125`.
- `packages/client/src/app/modules/media/components/recognition-render/recognition-render.component.ts:202-207`.
- `packages/client/src/app/modules/media/media.module.ts:18,31,49`.
- `packages/client/src/assets/i18n/en.json:590-591,616-617`.
- `aidlc-docs/audit.md:166` — single-window behaviour of `documentPictureInPicture.window`.
- `aidlc-docs/inception/requirements/requirements.md:141` — FR-W1.
- `aidlc-docs/construction/u3-split-orientation-pip/functional-design.md` — §8 PiP content setting, §14 deviations, §13 out of scope (per-language windows deferred to FR-W2 backlog).