# Unit of Work Story Map — Phase 2: Broadcasting & Transport

## Story to Unit

| Item | Title | Unit | Gate / Notes |
|---|---|---|---|
| S-11 | Broadcast Identity Backend | U3 | SR-02 |
| S-12 | Coturn STUN/TURN Service | U4 | SR-03; Spike 2.3 |
| S-13 | Realtime Signaling | U3 | SR-02; Spike 2.1 |
| S-14 | WebRTC Transport | U5 | Spike 2.1 |
| S-15 | Broadcaster Authentication | U2 | SR-01; Proto-10 |
| S-16 | Remote Broadcast Output Target | U5 | — |
| S-17 | Broadcast Session Management | U6 | Proto-11, Proto-12 |
| S-18 | Viewer Capacity | U5 | Spike 2.1 (cap value) |
| S-19 | Broadcast Viewer | U7 | Proto-14, Proto-15 |
| S-20 | External Display Output | U8 | Proto-13; `screen_retriever` record |
| SR-01 | OAuth Flow Approach Review | U2 (Functional Design) | Blocks U2 Code Generation |
| SR-02 | RLS and Realtime Authorization Policy Review | U3 (Functional Design) | Blocks U3 Code Generation |
| SR-03 | Server-Side Log Configuration Review | U4 (Infrastructure Design) | Blocks U4 Code Generation |
| Proto-10 | ZB Sign-In | U1 | Blocks U2 |
| Proto-11 | ZB Broadcast Setup | U1 | Blocks U6 |
| Proto-12 | ZB Live Dashboard | U1 | Blocks U6 |
| Proto-13 | ZB External Display Controls | U1 | Blocks U8 |
| Proto-14 | ZC Join Broadcast | U1 | Blocks U7 |
| Proto-15 | ZC Live Viewer States | U1 | Blocks U7 |
| M-S2.2 | Jordan — Classroom (completed) | U9 | — |
| M-S2.3 | Jordan — Auditorium (Phase 2 slice) | U9 | — |
| M-S3.6 | Sam — Joining a Remote Broadcast by Link | U9 | — |
| M-REG-01 | Signed-Out Local Features Regression | U9 | — |
| Spike 2.1 | Fan-out and signaling load | Spike | Feeds U3, U5 |
| Spike 2.2 | OBS closed-caption confirmation | Spike | Feeds FR-10 / exit criterion 7 |
| Spike 2.3 | Coturn alongside Supabase | Spike | Feeds U4 |

**Coverage:** 10 of 10 stories, 3 of 3 security reviews, 6 of 6 prototypes, 4 of 4 milestones and 3 of 3 spikes are assigned. Each item appears in exactly one unit.

## Unit to Requirements and Exit Criteria

| Unit | FRs | Key NFRs | Exit criteria |
|---|---|---|---|
| U1 | FR-1.5, FR-6, FR-7, FR-9 (UI) | NFR-5.2 | — |
| U2 | FR-1 | NFR-3.8 | 1, 9 |
| U3 | FR-2, FR-3 | NFR-3.4, 3.5, 3.6 | 1 |
| U4 | FR-4.3, FR-4.4 | NFR-3.1, 3.7, 6.1 | 3 |
| U5 | FR-4, FR-5, FR-8 | NFR-1.1, 1.2, 2.1, 3.2, 4.2 | 1, 2, 3, 5 |
| U6 | FR-6 (incl. FR-6.7) | NFR-1.4, 4.3 | 1 |
| U7 | FR-7 (incl. FR-7.4 paused state) | NFR-4.1, 5.1, 5.2 | 1, 4 |
| U8 | FR-9 (incl. FR-9.6) | NFR-5.1 | 6, 9 |
| U9 | all (verification) | NFR-7.4 | 1-9 |
| Spike 2.2 | FR-10 | — | 7 |

## Persona Coverage by Unit

| Persona | Units |
|---|---|
| Jordan | U1, U2, U3, U4, U5, U6, U8, U9 |
| Sam | U1, U3, U5, U7, U9 |
| Alex (regression) | U2, U9 |
