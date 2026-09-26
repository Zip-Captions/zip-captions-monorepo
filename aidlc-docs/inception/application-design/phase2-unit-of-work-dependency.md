# Unit of Work Dependencies — Phase 2: Broadcasting & Transport

## Dependency Matrix

Rows depend on columns. "X" means a hard dependency (must be complete, or for prototypes approved). "P" means only the specific prototype(s) listed must be approved.

| Unit | Sp 2.1 | Sp 2.2 | Sp 2.3 | U1 Proto | U2 Auth | U3 Ident+Sig | U4 Coturn | U5 Transport | U6 ZB UI | U7 ZC Viewer | U8 Ext Disp |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Spike 2.1 | | | | | | | | | | | |
| Spike 2.2 | | | | | | | | | | | |
| Spike 2.3 | | | | | | | | | | | |
| U1 Prototypes | | | | | | | | | | | |
| U2 Auth | | | | P (Proto-10) | | | | | | | |
| U3 Identity + Signaling | X | | | | X | | | | | | |
| U4 Coturn | | | X | | | | | | | | |
| U5 Transport + Output + Capacity | X | | | | | X | X | | | | |
| U6 ZB Broadcast UI | | | | P (Proto-11, 12) | | | | X | | | |
| U7 ZC Viewer | | | | P (Proto-14, 15) | | | | X | | | |
| U8 External Display | | | | P (Proto-13) | | | | | | | |
| U9 Integration | X | X | X | X | X | X | X | X | X | X | X |

Units 6 and 7 get Unit 2 and Unit 3 indirectly, through Unit 5.

## Dependency Graph

```
Start ──┬── Spike 2.1 ─────────────────────────┐
        ├── Spike 2.2 ───────────────────────────────────────────────────────┐
        ├── Spike 2.3 ──► U4 Coturn ──────────┐ │                            │
        └── U1 Prototypes                     │ │                            │
              ├─ Proto-10 ──► U2 Auth ──► U3 Identity + Signaling ◄──┘       │
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

**Text alternative:** Spikes 2.1, 2.2 and 2.3 and Unit 1 (Prototypes) can all start immediately. Unit 2 (Auth) needs Proto-10. Unit 3 needs Unit 2 and Spike 2.1. Unit 4 needs Spike 2.3. Unit 5 needs Units 3 and 4 and Spike 2.1. Unit 6 needs Unit 5 and Proto-11 and Proto-12. Unit 7 needs Unit 5 and Proto-14 and Proto-15. Unit 8 needs only Proto-13. Unit 9 needs everything.

## Critical Path

Proto-10 → Unit 2 → Unit 3 (also waits for Spike 2.1) → Unit 5 (also waits for Unit 4 and Spike 2.1) → Unit 6 or 7 → Unit 9.

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
| 8 | Unit 5 Transport + Output + Capacity | Critical path |
| 9 | Unit 6 ZB Broadcast UI | After Unit 5 |
| 10 | Unit 7 ZC Viewer | After Unit 5 |
| 11 | Spike 2.2 | Any time before Unit 9; slot it in wherever it fits |
| 12 | Unit 9 Integration | Last |

The order is a recommendation. Only the dependency matrix is binding.

## Shared Resources and Coordination Points

| Resource | Owner unit | Consumers | Coordination |
|---|---|---|---|
| `supabaseClientProvider` + app Supabase init | U2 | U3, U4, U5, U6, U7 | Fixed in U2; later units only consume it |
| Registry schema, RLS, Realtime authorization | U3 | U5, U6, U7 | Forward-only migrations; policy per the approved SR-02 |
| `SignalingMessage` schema (versioned) | U3 | U5, U6, U7 | Version field; changes need codec round-trip PBT |
| `CaptionWireMessage` schema (versioned) | U5 | U6, U7 | Same as above |
| `BroadcastLimits` values | U3 (model), Spike 2.1 (values) | U5, U6, U7 | Configuration, not code |
| Coturn endpoint + credential issuer | U4 | U5 | Contract is `TurnCredentialService` |
| Local dev stack (Docker Compose) | U3, U4 | all | Additive services only; `docs/TEST_SETUP.md` updated at Documentation Refinement |
| `CaptionOverlayTarget`, `OutputTargetSettings` | U8 | U6 (output target selection UI) | U6 lists the external display option added by U8 if it has landed; otherwise it is added in U9 |

## Testing Checkpoints

- **U3**: signaling and wire codec PBT; RLS and authorization tests against the local stack
- **U4**: TURN allocation with ephemeral credentials; log output inspected for payloads
- **U5**: both protocol sides tested together with fakes; cap and ordering invariants
- **U6 / U7**: widget tests for every broadcaster and viewer state, including the captions-inactive banner and the paused-captions viewer message
- **U9**: two-device, NAT simulation, capacity, reconnection and regression milestones
