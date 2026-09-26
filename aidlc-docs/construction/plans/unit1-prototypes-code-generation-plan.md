# Unit 1: UI Prototypes — Code Generation Plan

## Unit Context

- **Package**: `aidlc-docs` (HTML/CSS, documentation-only; never workspace application code)
- **Location**: `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/`
- **Stories**: Proto-10 through Proto-15 (`aidlc-docs/inception/user-stories/phase2-stories.md`)
- **Stages**: Code Generation only, then a Human Review Gate per prototype (no FD/NFR — matches the Phase 1 Unit 4 precedent)
- **Dependencies**: None; can start immediately
- **Downstream unblocks**: An approved Proto-10 unblocks Unit 2 (Broadcaster Auth). An approved Proto-13 unblocks Unit 8 (External Display) independently of the rest. Proto-11/12 unblock Unit 6; Proto-14/15 unblock Unit 7.

## Design Precedent

Each file is a standalone, self-contained HTML document (inline `<style>`/`<script>`, Google Fonts `Inter` import, no build step), following the Phase 1 prototype pattern (`aidlc-docs/construction/prototypes/*.html`):
- CSS custom properties on `:root` for light theme, overridden under `[data-theme="dark"]`, toggled via a `toggleTheme()` button (🌙/☀️)
- Responsive layout: sidebar nav collapses to a hamburger + drawer under 640px for app shells; join/viewer screens (zip_captions) additionally verified at mobile width per Proto-14
- A `desktop-hint` caption at the bottom naming the proto number and interaction notes
- All interactive elements carry `data-testid="{component}-{element-role}"` per the Automation Friendly Code Rule

## Steps

- [x] **Step 1 — Proto-10: Zip Broadcast Sign-In**
  File: `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-sign-in.html`
  Shows: provider sign-in buttons, signed-in state with sign-out, auth-failure message, copy clarifying sign-in is only required for remote broadcasting. Desktop + web widths, both themes.
  Story: Proto-10 (blocks S-15 / Unit 2)

- [x] **Step 2 — Proto-11: Zip Broadcast Broadcast Setup**
  File: `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-setup.html`
  Shows: session name entry with a validation error, output target selection, "start captioning when going live" toggle (off by default), stable URL with copy action, signed-out prompt state. No relay option.
  Story: Proto-11 (blocks S-17 / Unit 6)

- [x] **Step 3 — Proto-12: Zip Broadcast Live Dashboard**
  File: `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-dashboard.html`
  Shows: viewer count against cap, per-viewer connection type (P2P direct, TURN relayed, connecting, disconnected), caption preview, audio level, end-broadcast control, "broadcast full" state, start-failure state, and a large/prominent "captions inactive" banner when live but not captioning.
  Story: Proto-12 (blocks S-17 / Unit 6)

- [x] **Step 3 — Proto-12** approved 2026-09-25.

- [x] **Step 4 — Proto-13: Zip Broadcast External Display Controls**
  File: `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-external-display.html`
  Shows: display list, enable/disable control, active state, display-disconnected notice, and a mock of the borderless caption overlay window at projector scale.
  Story: Proto-13 (blocks S-20 / Unit 8)

- [x] **Step 4 — Proto-13** approved 2026-09-25.

- [x] **Step 5 — Proto-14: Zip Captions Join Broadcast**
  File: `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-captions-join.html`
  Shows: ID/URL entry, invalid-input message, connecting state. Mobile + desktop widths, both themes.
  Story: Proto-14 (blocks S-19 / Unit 7)

- [x] **Step 5 — Proto-14** approved 2026-09-25.

- [x] **Step 6 — Proto-15: Zip Captions Live Viewer States** approved 2026-09-25.
  File: `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-captions-viewer-states.html`
  Shows: all 8 states switchable via an in-page control — connecting, live, live-with-captions-paused-by-broadcaster, reconnecting, not-currently-broadcasting, broadcast-ended, broadcast-full, cannot-connect-with-reason. Each state distinguishable without color (icon/text, not just a dot color). Live captions reuse the Phase 1 caption rendering style (large, high-contrast text block).
  Story: Proto-15 (blocks S-19 / Unit 7)

- [x] **Step 7 — Documentation Summary**
  File: `aidlc-docs/construction/phase2-unit1-prototypes/code/unit1-summary.md`
  Lists the 6 files generated, their story mapping, and open questions (if any) for reviewer sign-off, matching the Phase 1 e2e-test-instructions.md checklist style.

## Review Gate

Per the unit's gate note, prototypes may be approved individually and out of order — Proto-10 first is the priority since it unblocks Unit 2. Each step above will be presented for review as it completes; you may approve incrementally (e.g. "Proto-10 approved, continue") rather than waiting for all 6.
