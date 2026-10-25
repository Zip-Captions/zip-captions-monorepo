# Unit of Work Dependencies — Phase 2: Broadcasting & Transport

## Dependency Matrix

Rows depend on columns. "X" means a hard dependency (must be complete, or for prototypes approved). "P" means only the specific prototype(s) listed must be approved.

| Unit | Sp 2.1 | Sp 2.2 | Sp 2.3 | U1 Proto | U2 Auth | U3 Ident+Sig | U3.1 Sig Privacy | U4 Coturn | U5 Transport | U6 ZB UI | U7 ZC Viewer | U8 Ext Disp |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Spike 2.1 | | | | | | | | | | | | |
| Spike 2.2 | | | | | | | | | | | | |
| Spike 2.3 | | | | | | | | | | | | |
| U1 Prototypes | | | | | | | | | | | | |
| U2 Auth | | | | P (Proto-10) | | | | | | | | |
| U3 Identity + Signaling | X | | | | X | | | | | | | |
| U3.1 Signaling Privacy | | | | | | X | | | | | | |
| U4 Coturn | | | X | | | | | | | | | |
| U5 Transport + Output + Capacity | X | | | | | X | X | X | | | | |
| U6 ZB Broadcast UI | | | | P (Proto-11, 12) | | | | | X | | | |
| U7 ZC Viewer | | | | P (Proto-14, 15) | | | | | X | | | |
| U8 External Display | | | | P (Proto-13) | | | | | | | | |
| U8.1 Pop-out (PiP) | | | | | | | | | | | | X (U8) |
| U9 Integration | X | X | X | X | X | X | X | X | X | X | X | X |

Units 6 and 7 get Unit 2, Unit 3, and Unit 3.1 indirectly, through Unit 5.

**Unit 8.1 — Pop-out Live Captions (PiP), S-21** (inserted 2026-10-20, per PR #37 review
decision D-1): the pop-out designed inside Unit 8 is split into its own unit. Depends only
on Unit 8, which supplies the window machinery this unit **promotes to `zip_core`**
(option A, approved 2026-10-20) so both apps consume one implementation rather than
duplicating a window state machine or making one app depend on another. Blocks the v2.0
RC and Unit 9. Desktop only for Phase 2; web Document PiP moves to Phase 5. Adds
`desktop_multi_window` and `window_manager` to **both** apps; the supply-chain record is
`aidlc-docs/construction/pop-out/functional-design/window-manager-security-10.md`.

**Unit 3.1 — Signaling Channel Privacy** (inserted 2026-10-05, after Units 3 and 4
shipped): corrects a privacy gap in Unit 3's signaling channel found while scoping Unit
5 (every viewer could see every other viewer's presence and raw SDP/ICE messages on the
shared `signaling:{session_id}` topic). Ships as new code extending Unit 3's package,
never reopening Unit 3's merged artifacts. Depends only on Unit 3 (done). Blocks Unit 5,
which was paused mid-Functional-Design when this was found — nothing past Unit 5 had
started, so the blast radius is contained to exactly one in-flight unit.

## Dependency Graph

```
Start ──┬── Spike 2.1 ─────────────────────────┐
        ├── Spike 2.2 ───────────────────────────────────────────────────────┐
        ├── Spike 2.3 ──► U4 Coturn ──────────┐ │                            │
        └── U1 Prototypes                     │ │                            │
              ├─ Proto-10 ──► U2 Auth ──► U3 Identity + Signaling            │
              │                                 │                            │
              │                                 ▼                            │
              │                      U3.1 Signaling Privacy                  │
              │                                 │                            │
              │                                 ▼                            │
              │                      U5 Transport + Output + Capacity ◄── U4 │
              │                           │                 │                │
              ├─ Proto-11/12 ──────────► U6 ZB UI          │                 │
              ├─ Proto-14/15 ─────────────────────────► U7 ZC Viewer         │
              └─ Proto-13 ──► U8 External Display                            │
                                    │        │               │               │
                                    └────────┴───────┬───────┴───────────────┘
                                                     ▼
                                          U9 Integration Milestones
                                   (Build and Test + Documentation Refinement)
```

**Text alternative:** Spikes 2.1, 2.2 and 2.3 and Unit 1 (Prototypes) can all start immediately. Unit 2 (Auth) needs Proto-10. Unit 3 needs Unit 2 and Spike 2.1. Unit 3.1 needs Unit 3. Unit 4 needs Spike 2.3. Unit 5 needs Units 3, 3.1 and 4 and Spike 2.1. Unit 6 needs Unit 5 and Proto-11 and Proto-12. Unit 7 needs Unit 5 and Proto-14 and Proto-15. Unit 8 needs only Proto-13. Unit 8.1 needs Unit 8. Unit 9 needs everything.

## Critical Path

Proto-10 → Unit 2 → Unit 3 (also waits for Spike 2.1) → Unit 3.1 → Unit 5 (also waits for Unit 4 and Spike 2.1) → Unit 6 or 7 → Unit 9.

Spike 2.1 and Spike 2.3 run alongside Units 1-2 so they don't delay the critical path.

## Suggested Build Order (one branch at a time)

Because units are built one at a time in the main checkout, this order keeps the critical path moving and uses independent units to fill waiting time (for example while a security review or prototype review is pending):

| # | Work item | Why now |
|---|---|---|
| 1 | Unit 1 Prototypes (Proto-10 reviewed first) | Unblocks Units 2, 6, 7 and 8 |
| 2 | Spike 2.1 | Longest lead time; feeds Units 3 and 5 |
| 3 | Unit 2 Auth | Critical path. SR-01 review time can overlap with item 4 |
| 4 | Spike 2.3 | Feeds Unit 4 |
| 5 | Unit 3 Identity + Signaling | Critical path. SR-02 review time can overlap with item 6 |
| 6 | Unit 4 Coturn | Needed by Unit 5. SR-03 review time can overlap with item 7 |
| 7 | Unit 8 External Display | Independent; fills review wait time |
| 7.5 | Unit 3.1 Signaling Privacy | Inserted 2026-10-05; critical path, blocks Unit 5. SR-04 review time can overlap with finishing item 7 |
| 8 | Unit 5 Transport + Output + Capacity | Critical path |
| 9 | Unit 6 ZB Broadcast UI | After Unit 5 |
| 10 | Unit 7 ZC Viewer | After Unit 5 |
| 10.5 | Unit 8.1 Pop-out (PiP) | Inserted 2026-10-20; needs Unit 8's window machinery while it is fresh. Blocks the v2.0 RC |
| 11 | Spike 2.2 | Any time before Unit 9; slot it in wherever it fits |
| 12 | Unit 9 Integration | Last |

The order is a recommendation. Only the dependency matrix is binding.

## Shared Resources and Coordination Points

| Resource | Owner unit | Consumers | Coordination |
|---|---|---|---|
| `supabaseClientProvider` + app Supabase init | U2 | U3, U4, U5, U6, U7 | Fixed in U2; later units only consume it |
| Registry schema, RLS, Realtime authorization | U3 (registry), U3.1 (channel topology) | U5, U6, U7 | Forward-only migrations; policy per the approved SR-02, then SR-04 |
| `SignalingMessage` schema (versioned) | U3 | U5, U6, U7 | Version field; changes need codec round-trip PBT; U3.1 changes which topic carries it, not its shape |
| `CaptionWireMessage` schema (versioned) | U5 | U6, U7 | Same as above |
| `BroadcastLimits` values | U3 (model), Spike 2.1 (values) | U5, U6, U7 | Configuration, not code |
| Coturn endpoint + credential issuer | U4 | U5 | Contract is `TurnCredentialService` |
| Local dev stack (Docker Compose) | U3, U4 | all | Additive services only; `docs/TEST_SETUP.md` updated at Documentation Refinement |
| `CaptionOverlayTarget`, `OutputTargetSettings` | U8 | U6 (output target selection UI) | U6 lists the external display option added by U8 if it has landed; otherwise it is added in U9 |
| `OverlayWindowMode`, `OverlayWindowController`, overlay codec, sub-engine entry | U8 | U8.1 | U8.1 moves these from `zip_broadcast` to `zip_core` (one implementation for both apps); it must not fork or copy the controller, codec or entry contract, and must not regress Unit 8's external display |
| `windowManager` instance in the sub-engine | U8.1 | U9 (manual verification) | One global per process; the call must run in the sub-engine that owns the pop-out window, in both apps |

## Testing Checkpoints

- **U3**: signaling and wire codec PBT; RLS and authorization tests against the local stack
- **U3.1**: per-viewer channel isolation — a viewer client must receive zero presence or signaling events for any other viewer; verified against the real local stack with 2+ concurrent viewers, not just unit tests
- **U4**: TURN allocation with ephemeral credentials; log output inspected for payloads
- **U5**: both protocol sides tested together with fakes; cap and ordering invariants
- **U6 / U7**: widget tests for every broadcaster and viewer state, including the captions-inactive banner and the paused-captions viewer message
- **U9**: two-device, NAT simulation, capacity, reconnection and regression milestones
- **U10**: G2 and G3 reproduced on the iOS Simulator and the Android emulator with permissions not pre-granted, then re-run after the fix. Then captioning on a physical iPhone and a physical Android phone (Phase 1 exit criterion 1, Phase 1 NFR-1.1, screen kept on)
- **U11**: a signed `ipa` and `aab` from CI; an internal tester installs from both test tracks and completes a captioning session (Alpha 1 gate)
- **U12**: SR-05 approved before Code Generation; the staging endpoints are reachable from a test-track build
- **U13**: the `integration_test` smoke harness passes on both virtual devices; a phone joins, receives and reconnects across a real Wi-Fi to cellular switch (Alpha 2 gate)

## Mobile Alpha Units (Units 10-13), appended 2026-10-24

The existing matrix, graph and build order above are unchanged. Unit 9 still closes the original Phase 2 scope. Units 10-13 are defined in `phase2-unit-of-work.md`, section "Mobile Alpha Units". The approved plan labelled them A to D.

### Dependency Matrix (appended units)

| Unit | U8.1 Pop-out | U9 Integration | U10 Mobile Readiness | U11 Alpha Distribution | U12 Staging Backend |
|---|---|---|---|---|---|
| U10 Mobile Platform Readiness | X (merged 2026-10-24) | | | | |
| U11 Internal Alpha Distribution | | | X | | |
| U12 Staging Backend | | X | | | |
| U13 Mobile Viewer Verification | | (via U12) | | X | X |

The dependency on Unit 8.1 is a branch-scheduling rule (one branch at a time), not a code dependency: Unit 10 shares no files with Unit 8.1. Unit 11 also waits on human prerequisites: an Apple Developer team with an App Store Connect record, a Play Console app, and an upload key.

### Dependency Graph (appended units)

```
U8.1 Pop-out (merged) ──► U10 Mobile Platform Readiness ──► U11 Internal Alpha Distribution ══► ALPHA 1
                                                                       │
U9 Integration Milestones ──► U12 Staging Backend ─────────────────────┴──► U13 Mobile Viewer Verification ══► ALPHA 2
```

**Text alternative:** Unit 10 needs Unit 8.1 merged. Unit 11 needs Unit 10, and its completion is the Alpha 1 gate. Unit 12 needs Unit 9. Unit 13 needs Units 11 and 12, and its Build and Test is the Alpha 2 gate. Units 10 and 11 do not depend on Unit 9 and may run before it. Units 12 and 13 run after Unit 9 as post-close Phase 2 units.

The parked on-device multilingual STT unit is unnumbered and is not placed in this graph. Its position relative to Unit 9 and to these units is decided when it is approved (its OQ-1).

### Suggested Build Order (appended units)

| # | Work item | Why now |
|---|---|---|
| A1 | Unit 10 Mobile Platform Readiness | First after Unit 8.1 merges (decided 2026-10-22). OQ-MA-1 is answered at its NFR Requirements stage |
| A2 | Unit 11 Internal Alpha Distribution | After Unit 10. Can wait on the store accounts while other units proceed |
| A3 | Unit 12 Staging Backend | After Unit 9. SR-05 review time can overlap with finishing Unit 11 |
| A4 | Unit 13 Mobile Viewer Verification | Last; its Build and Test is the Alpha 2 gate |

Where Unit 9 (and the multilingual STT unit) fall relative to Units 10 and 11 is flexible. Only the dependency matrix is binding.

### Shared Resources and Coordination Points (appended units)

| Resource | Owner unit | Consumers | Coordination |
|---|---|---|---|
| App identity (bundle IDs, display name) | U10 | U11, U13 | Decided once at Unit 10's NFR Requirements, against the v1 store listings |
| Signing keys, `key.properties`, CI signing secrets | U10 (handling policy), U11 (CI lanes) | U13 | Never in git; GitHub Actions secrets only (Security Baseline) |
| Staging `--dart-define` values (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ICE_SERVER_URLS`, `BROADCAST_BASE_URL`) | U12 | U13, U11's release lanes | Staging only; kept separate from Phase 6 production infrastructure |
| Virtual-device QA procedure (`flutter-agent-lens`) | U10 | U11, U12, U13 | Defined in `phase2-unit-of-work.md`, "Virtual-device development and QA"; extended, not forked
