# Unit of Work — Phase 2: Broadcasting & Transport

## Overview

Phase 2 is decomposed into 3 research spikes and 9 construction units. All work happens in the existing monorepo packages (zip_core, zip_captions, zip_broadcast, zip_supabase) and the local dev stack. No new packages are created.

**Decisions from the unit plan:**
- Q1:A — both UI units run all design stages
- Q2:A — each unit waits only for the spikes that inform it
- Q3:A — one PR per unit; each spike gets its own docs-only PR
- Q4:A — Unit 5 stays whole
- Q5:A — spike code is thrown away, and units are built test-first

**Working model:** one branch at a time in the main checkout (project preference, no worktrees). Each PR targets `develop`. The PR for a unit is opened before the next unit starts (AGENTS.md).

**Security review gates:** SR-01, SR-02 and SR-03 each produce an approach document during their unit's design stage (Functional or Infrastructure Design). **That unit's Code Generation cannot start until you record approval** (AGENTS.md "Security-Critical Code — Pre-Approval Required").

**Model:** per CLAUDE.md, Construction stages run on Sonnet.

---

## Research Spikes (early Construction units)

Spike reports go in `aidlc-docs/construction/spikes/`. Spike code lives in `spikes/phase2/` at the repo root, is referenced from the report, and is never merged into any package (Q5:A).

### Spike 2.1: Broadcaster Fan-Out and Signaling Load

**Scope**: (1) Broadcaster fan-out: CPU, memory and caption latency with N concurrent WebRTC data channels from one broadcaster process, stepped up to 200. Cover macOS, at least one of Windows or Linux, and a web broadcaster. (2) Self-hosted Supabase Realtime signaling and presence load with 200 viewers joining a session.

**Deliverables**:
- Measurements per platform for N = 25, 50, 100, 150, 200
- The recommended `BroadcastLimits.maxViewers` default, plus values for `presenceTimeout` and `reconnectWindow` and the NFR-1.3 timings (join-to-first-caption, reconnection)
- `flutter_webrtc` data-channel maturity assessment on Windows or Linux desktop, with a platform tiering recommendation (NFR-8.3)
- Report: `aidlc-docs/construction/spikes/spike-2.1-report.md`

**Exit Criteria**: A cap is recommended with evidence, the TBD values are filled in, and the desktop `flutter_webrtc` risk is resolved or escalated.

**Sequencing**: Can start immediately. Must complete before Unit 3 and Unit 5.

---

### Spike 2.2: OBS Closed-Caption API Confirmation

**Scope**: Confirm that `ObsWebSocketTarget` uses the correct OBS WebSocket v5 closed-caption request on current OBS versions, and document the protocol interaction.

**Deliverables**:
- Confirmation, or a gap description with a scoped follow-up proposal
- Report: `aidlc-docs/construction/spikes/spike-2.2-report.md`

**Exit Criteria**: Exit criterion 7 is either satisfied or a follow-up is recorded.

**Sequencing**: Independent; blocks no unit. Can run at any point before Unit 9.

---

### Spike 2.3: Coturn Alongside Supabase

**Scope**: Coturn deployed next to the Supabase stack: resource usage, configuration (payload-free logging, private-range relay denial), the ephemeral TURN credential mechanism (for example the TURN REST shared-secret scheme and where credentials are issued), TURN relay through symmetric NAT, and TURN load at the target scale.

**Deliverables**:
- A recommended Coturn configuration and credential-issuing mechanism (input to SR-03 and Unit 4 Infrastructure Design)
- NAT simulation method that is reusable in Unit 9
- Report: `aidlc-docs/construction/spikes/spike-2.3-report.md`

**Exit Criteria**: TURN relay is shown working through a symmetric NAT simulation, the credential mechanism is recommended, and the log configuration has been checked for payload-free output.

**Sequencing**: Can start immediately. Must complete before Unit 4.

---

## Construction Units

### Unit 1: UI Prototypes

**Package**: aidlc-docs (HTML/CSS) at `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/`
**Stories**: Proto-10 to Proto-15
**Stages**: Code Generation only, then a Human Review Gate (Phase 1 precedent)

**Deliverables**: Six standalone HTML/CSS prototypes in light and dark themes with responsive layouts:
- Proto-10 sign-in
- Proto-11 broadcast setup, with the auto-start captioning option
- Proto-12 live dashboard, with the captions-inactive banner
- Proto-13 external display controls
- Proto-14 join screen
- Proto-15 viewer states (8 states)

**Gate note**: Prototypes can be approved one at a time, so an approved Proto-10 unblocks Unit 2 and an approved Proto-13 unblocks Unit 8 without waiting for the rest.

**Dependencies**: None. Can start immediately.

---

### Unit 2: Broadcaster Auth

**Packages**: zip_core, zip_broadcast (plus `supabase_flutter` initialization in both apps' `main.dart`)
**Stories**: S-15, gated by SR-01
**Stages**: Functional Design (produces the SR-01 OAuth approach document; **approval gate**), NFR Requirements, NFR Design, Code Generation

**Components**: `supabaseClientProvider`, `AuthService`, `SupabaseAuthService`, `AuthProviderConfig`, `AuthState`, `AuthNotifier`; the Zip Broadcast sign-in view; the `main.dart` Supabase initialization in both apps.

**Notes**: The first Construction stage that loads the Security Baseline and PBT rule files (session protocol). The local Supabase stack needs the chosen OAuth provider(s) configured for development.

**Dependencies**: Proto-10 approved. No spike.

---

### Unit 3: Broadcast Identity + Signaling

**Packages**: zip_supabase, zip_core
**Stories**: S-11, S-13, gated by SR-02
**Stages**: Functional Design (produces the SR-02 policy document: registry RLS, resolution path and enumeration controls, Realtime channel authorization; **approval gate**), NFR Requirements, NFR Design, Infrastructure Design (migration, resolution endpoint, Realtime authorization configuration), Code Generation

**Components**: registry migration and RLS; resolution path; Realtime authorization; `BroadcastId`, `BroadcastLink`, `BroadcastIdentityRepository` + Supabase implementation, `BroadcastResolver` + implementation, `BroadcastResolution`; `SignalingService`, `StatusChannel`, `SessionSignalingChannel` + Supabase implementation, `SignalingMessage`, `SignalingCodec`, `PresenceSnapshot`; `BroadcastLimits` (values from Spike 2.1).

**Dependencies**: Unit 2 (authenticated user identity for RLS), Spike 2.1 (presence timeout).

---

### Unit 3.1: Signaling Channel Privacy

**Inserted into the roadmap 2026-10-05**, after Units 3 and 4 shipped. Corrects a real
privacy gap discovered while scoping Unit 5: Unit 3's `signaling:{session_id}` channel
puts the broadcaster and every viewer on one shared Realtime topic. Confirmed by reading
the shipped code (not assumed): every participant's own official `SessionSignalingChannel
.presence` returns the full presence list of everyone on the channel, and `onBroadcast`
forwards every `SignalingMessage` — including another viewer's `SdpOffer`/`IceCandidate`,
which carries real network-address metadata — to every subscriber, with no recipient
filtering. A viewer can see exactly how many other viewers are connected, when they
join/leave, and real connection metadata belonging to connections that aren't theirs.
This does **not** modify or reopen Unit 3's merged PR/artifacts — it ships as new code
in a new unit, the same precedent as `20261001000001_fix_jwt_secret_mismatch.sql`
(a corrective migration, never an edit to the original).

**Packages**: zip_supabase (migration), zip_core (signaling)
**Stories**: S-13.1, gated by SR-04
**Stages**: Functional Design (produces the SR-04 policy document: the per-viewer
channel/topic scheme and its authorization basis; **approval gate**), NFR Requirements,
NFR Design, Code Generation

**Design direction** (confirmed against Supabase's own documentation and an established
industry precedent — AWS Kinesis Video Streams WebRTC's "master/viewer" signaling model,
where "a viewer cannot discover or interact with other viewers" by construction, not by
convention): split the single shared channel into (1) a broadcaster-only "lobby" topic
that viewers may only publish a `JoinRequest` to, never subscribe/read, and (2) a private
per-viewer topic (`signaling:{session_id}:{peerId}`) that only that one viewer and the
broadcaster ever subscribe to. Privacy comes from the per-peer topic name's own
unguessability (a random value, known only to the broadcaster and that one viewer once
exchanged) — not from a persisted session-owner table, keeping this compatible with
FR-2.6's "no session records" constraint the same way Unit 3's own RLS already does.

**Components**: new migration adjusting the Realtime RLS topic-pattern match for the
`signaling:{session_id}:lobby` and `signaling:{session_id}:{peerId}` patterns;
`SignalingService`/`SessionSignalingChannel` redesign in `zip_core` (the per-viewer
channel lifecycle, and the lobby-channel `JoinRequest` hand-off); `SignalingMessage`'s
existing shape is unaffected (same sealed type, same wire codec) — only which channel
topic carries which message type changes.

**Dependencies**: Unit 3 (extends, does not reopen).

**Blocks**: Unit 5, which was paused mid-Functional-Design when this gap was found —
its `BroadcastTransportContext`/`ViewerTransportContext` and join-handshake design
assumed the old single-channel topology and need to be revisited once this unit's
Functional Design fixes the real channel/topic shape.

---

### Unit 4: Coturn Infrastructure

**Packages**: local dev stack (Supabase Docker Compose area in zip_supabase), zip_core (client configuration)
**Stories**: S-12, gated by SR-03
**Stages**: NFR Requirements, NFR Design, Infrastructure Design (produces the SR-03 log configuration document; **approval gate**), Code Generation. Functional Design is skipped because the unit has no business logic.

**Components**: Coturn service (STUN and TURN), TURN credential issuer (per Spike 2.3), `TurnCredentialService` + implementation, `IceServerProvider` + implementation; metrics and alert thresholds; private-range relay denial.

**Dependencies**: Spike 2.3.

---

### Unit 5: WebRTC Transport + Remote Output + Capacity

**Package**: zip_core (adds `flutter_webrtc`)
**Stories**: S-14, S-16, S-18
**Stages**: Functional Design, NFR Requirements, NFR Design, Code Generation

**Components**: `BroadcastTransport`, `ViewerTransport`, `WebRtcBroadcastTransport`, `WebRtcViewerTransport`, `PeerConnectionFactory`, `TransportSelector`, `ConnectionType`, `ConnectionStatus`, `ViewerConnectionInfo`; `CaptionWireMessage`, `CaptionActivity`, `CaptionWireCodec`; `RemoteBroadcastTarget`, `RemoteCaptionReceiver`; `ViewerAdmission`.

**Notes**: Both protocol sides are tested together against fakes (signaling, peer connection). This is where PBT covers the wire format round-trip, in-order delivery after join, the cap invariant and the peer connection state machine. Two-device and TURN verification against the real stack happens in Unit 9.

**Dependencies**: Unit 3 (signaling), Unit 4 (ICE servers), Spike 2.1 (cap, fan-out findings).

---

### Unit 6: Zip Broadcast Broadcast UI

**Packages**: zip_core (session orchestration), zip_broadcast (screens)
**Stories**: S-17
**Stages**: Functional Design, NFR Requirements, NFR Design, Code Generation (Q1:A)

**Components**: `BroadcastSettings` + notifier, `BroadcastSessionNotifier`, `BroadcastSessionState`, `LiveBroadcast`; `BroadcastSetupScreen`, `LiveBroadcastDashboard` (captions-inactive banner); `ZbAppShell` wiring.

**Dependencies**: Unit 5, Proto-11 and Proto-12 approved.

---

### Unit 7: Zip Captions Viewer

**Packages**: zip_core (viewer orchestration), zip_captions (screens, routes)
**Stories**: S-19
**Stages**: Functional Design, NFR Requirements, NFR Design, Code Generation (Q1:A)

**Components**: `ViewerSessionNotifier`, `ViewerSessionState`, `ReconnectPolicy`; `JoinBroadcastScreen`, `BroadcastViewerScreen`; the `/join` and `/b/:broadcastId` routes; path URL strategy and security headers for the web route.

**Dependencies**: Unit 5, Proto-14 and Proto-15 approved. Order relative to Unit 6 is flexible.

---

### Unit 8: External Display

**Package**: zip_broadcast (adds `screen_retriever`)
**Stories**: S-20
**Stages**: Functional Design, Infrastructure Design (secondary-window entry point, desktop platform window configuration; Phase 1 overlay precedent), Code Generation. NFR stages are skipped: the only NFR is WCAG AAA contrast, which is covered by the story criteria and the existing theme. The SECURITY-10 dependency justification for `screen_retriever` is recorded in Functional Design.

**Components**: `DisplayEnumerator`, `ScreenRetrieverDisplayEnumerator`, `DisplayInfo`; `CaptionOverlayTarget` completion; `OverlayWindowEntry`, `OverlayWindowApp`; `OutputTargetSettings` display field; `ExternalDisplayControls`.

**Dependencies**: Proto-13 approved. Independent of the broadcast chain and all spikes.

---

### Unit 9: Integration Milestones

**Packages**: all
**Stories**: M-S2.2, M-S2.3, M-S3.6, M-REG-01
**Stages**: Build and Test, then Documentation Refinement

**Scope**: Two-device P2P on the same network; TURN under restricted-NAT simulation (the Spike 2.3 method); capacity refusal at the cap; reconnection after a network change; signed-out regression; checking the exit criteria (Spike 2.2 result for criterion 7). Documentation Refinement applies the documentation updates listed in `phase2-requirements.md`, the S3.6 persona scenario, and AGENTS.md's out-of-date "Current Scope" and worktree guidance (with per-change approval).

**Dependencies**: Units 1-8 and all spikes.

---

## Construction Stage Summary

| Unit | FD | NFR-R | NFR-D | ID | CG | Gate |
|---|---|---|---|---|---|---|
| Spike 2.1 / 2.2 / 2.3 | — | — | — | — | report | — |
| 1 Prototypes | — | — | — | — | yes | Human review (per prototype) |
| 2 Auth | yes (SR-01) | yes | yes | — | yes | SR-01 before CG |
| 3 Identity + Signaling | yes (SR-02) | yes | yes | yes | yes | SR-02 before CG |
| 4 Coturn | — | yes | yes | yes (SR-03) | yes | SR-03 before CG |
| 5 Transport + Output + Capacity | yes | yes | yes | — | yes | — |
| 6 ZB Broadcast UI | yes | yes | yes | — | yes | — |
| 7 ZC Viewer | yes | yes | yes | — | yes | — |
| 8 External Display | yes | — | — | yes | yes | Dependency record (SECURITY-10) |
| 9 Integration | Build and Test + Documentation Refinement | | | | | Exit criteria |
