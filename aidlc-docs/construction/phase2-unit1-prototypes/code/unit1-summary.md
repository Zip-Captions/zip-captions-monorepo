# Unit 1: UI Prototypes — Summary

## Deliverables

All 6 prototypes generated at `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/`, reviewed and approved individually per the unit's gate note.

| Story | File | Story mapping | Approved |
|---|---|---|---|
| Proto-10 | `zip-broadcast-sign-in.html` | Blocks S-15 (Unit 2 Broadcaster Auth) | 2026-09-25 |
| Proto-11 | `zip-broadcast-setup.html` | Blocks S-17 (Unit 6 ZB Broadcast UI) | 2026-09-25 |
| Proto-12 | `zip-broadcast-dashboard.html` | Blocks S-17 (Unit 6 ZB Broadcast UI) | 2026-09-25 |
| Proto-13 | `zip-broadcast-external-display.html` | Blocks S-20 (Unit 8 External Display) | 2026-09-25 |
| Proto-14 | `zip-captions-join.html` | Blocks S-19 (Unit 7 ZC Viewer) | 2026-09-25 |
| Proto-15 | `zip-captions-viewer-states.html` | Blocks S-19 (Unit 7 ZC Viewer) | 2026-09-25 |

## Downstream unblocks

- Unit 2 (Broadcaster Auth): unblocked — Proto-10 approved.
- Unit 6 (ZB Broadcast UI): unblocked — Proto-11 and Proto-12 approved (still needs Unit 5 for full dependency).
- Unit 7 (ZC Viewer): unblocked — Proto-14 and Proto-15 approved (still needs Unit 5 for full dependency).
- Unit 8 (External Display): unblocked — Proto-13 approved; independent of the rest of the dependency chain.

## Notable review outcomes (beyond the acceptance criteria)

- **Proto-12**: iterated through 6 rounds of feedback — audio level folded into the stat row, a controls row added (End Broadcast, Pause/Resume/Start Captioning, Clear Caption Text), per-input audio enable/disable toggles added, a 5th "captions inactive at start" state added distinct from the mid-broadcast pause state, and broadcast-full changed from a blocking full-screen state to a non-blocking banner (matching the captions-inactive banner pattern) so the dashboard stays usable at capacity.
- **Proto-15**: flow-direction behavior (top-to-bottom vs bottom-to-top) was corrected to match the exact Phase 1 `ScrollDirection` spec (`stories.md` lines 146-152), and a reconnecting-state spinner replaces a static icon to signal an in-progress action. A prototype-only control demonstrates the "cannot connect" state carrying a reconnection-specific reason, since S-19 does not define a separate reconnection-failure state.

## Backlog items raised during review (not implemented; see `aidlc-state.md`)

1. **Caption attribution / speaker-name prefix on captions** — whether a per-input speaker label should be prepended as caption text, not just conveyed via color/indicator. Flagged for Unit 6 Functional Design.
2. **Pop out live captions into a small floating window (PiP-style)** — not in S-19/FR-7.1-7.6. Flagged for Unit 7 Functional Design; would need FR-9.5 approval if a new dependency is required.

## Open questions for downstream units

- The exact reconnection window duration is TBD pending Spike 2.1 (per S-19).
- The specific UX for a reconnection that fails after the window expires reuses "cannot connect" with a distinct reason (confirmed with the human reviewer during Proto-15 review); Unit 7 Functional Design should formalize this.
