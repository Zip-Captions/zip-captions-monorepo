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

**Package**: zip_broadcast (adds `screen_retriever`; `window_manager` removed per the PR #37 review, 2026-10-19)
**Stories**: S-20
**Stages**: Functional Design, NFR Requirements, NFR Design, Infrastructure Design (secondary-window entry point, desktop platform window configuration; Phase 1 overlay precedent), Code Generation. (Amended 2026-10-19 per the PR #37 review comment: NFR Requirements and NFR Design are run, not skipped; the pop-out is split into its own unit after this one and blocks the v2.0 RC.) The SECURITY-10 dependency justification for `screen_retriever` is recorded in Functional Design.

**Components**: `DisplayEnumerator`, `ScreenRetrieverDisplayEnumerator`, `DisplayInfo`; `CaptionOverlayTarget` completion; `OverlayWindowEntry`, `OverlayWindowApp`; `OutputTargetSettings` display field; `ExternalDisplayControls`.

**Dependencies**: Proto-13 approved. Independent of the broadcast chain and all spikes.

---

### Unit 8.1: Pop-out Live Captions (PiP)

**Inserted into the roadmap 2026-10-20**, per the PR #37 review decision D-1 (2026-10-19). Unit 8 was scoped to external-display output only; the pop-out was designed inside it against `pip-ux-parity.md` §8 and is split out here as its own unit so that neither feature ships half-built. It **blocks the v2.0 RC**: `docs/03-roadmap.md` §Phase 6 Definition of Done lists Picture-in-Picture UX parity as a release gate.

**Package**: zip_core (window machinery, promoted from Unit 8), zip_broadcast, zip_captions (toggle wiring in both; both add `desktop_multi_window` + `window_manager`). **Amended 2026-10-20** to span both apps (option A) — see `pip-ux-parity.md` §8 and §8.7.
**Stories**: S-21
**Stages**: Functional Design, NFR Requirements, NFR Design, Code Generation. Infrastructure Design covers the `zip_core` platform fence and the per-app runner registration, which differ from Unit 8's single-app case.

**Scope**: The user can pop the live captions out into a small window that floats above all other application windows, and bring them back — **in both Zip Broadcast and Zip Captions**. §8 applies to both apps; nothing in the contract is broadcaster-specific. The window machinery Unit 8 built in `zip_broadcast` (controller and state machine, versioned codec, sub-engine entry contract, ready handshake) is **promoted to `zip_core`** so both apps consume one implementation, then each app adds its own toggle wiring and sub-engine entry. `pip-ux-parity.md` §8 is the binding user-visible contract; its 18 acceptance criteria are checked **once per app**, and items 8-10 (translation-dependent) are recorded as deferred to Phase 8 rather than claimed.

**Components** (proposed; confirmed or amended in Functional Design): in `zip_core` — the promoted `OverlayWindowController` + `OverlayWindowMode` hierarchy, the launch/snapshot codec, the sub-engine entry contract, and a `window_manager` registration helper behind the established `_io`/`_stub` fence (so `zip_core` stays platform-agnostic per tech-spec §4); `PopOutWindowMode` as a sibling of the external-display mode; `CaptionOverlaySnapshot` content-setting field. In each app — `PopOutControls` (the chrome toggle, UX-PIP-01), the in-surface toggle (UX-PIP-02), pop-out ARB keys, and the app's own sub-engine entry point.

**Dependencies**: Unit 8 complete (it supplies the machinery this unit promotes). Independent of the broadcast chain and all spikes.

**Platform scope**: **desktop only for Phase 2** (decided 2026-10-20). Web Document Picture-in-Picture is explicitly deferred to Phase 5 alongside the rest of the web scaffold, which Unit 7 also deferred; the `document-pip` documentation is indexed for that later work. S-20's web exclusion carries over unchanged.

**Known constraints carried in from verification** (2026-10-20): `desktop_multi_window` 0.2.1 exposes no always-on-top, window-level or topmost API on any of its three backends — the capability must come from `window_manager`. On macOS that is `NSFloatingWindowLevel`, which floats above normal windows but not above another application's full-screen window; floating above a foreign full-screen window needs an `NSPanel`-derived window class, which is recorded as a known limitation and a Unit 9 manual check rather than silently claimed. The always-on-top assertion itself is platform-level and belongs to Unit 9 (pip-ux-parity §8.8 item 15).

**Plugin registration — decided 2026-10-20**: `window_manager` is registered in the **`desktop_multi_window` window-created callback** on each desktop runner, not by adding it to the sub-engine's `plugins` list. Unit 8's ID-1 deliberately passed an empty plugin list to the sub-engine (its locked set needed none); the window-created callback already gives each runner the created window's `FlutterViewController` (macOS) / `FlView` (Linux, via `desktop_multi_window_plugin_set_window_created_callback`) / the created window (Windows, via `DesktopMultiWindowSetWindowCreatedCallback`), so it can run `RegisterGeneratedPlugins(registry:)`-equivalent registration against that engine before the window is shown. This keeps ID-1's empty-list invariant intact and keeps all three runner callbacks as the single place where sub-engine window configuration lives. Unit 8 installed these callbacks in Zip Broadcast's runners only; **this unit adds the equivalent to Zip Captions' three desktop runners**, which have no windowing today. The always-on-top call itself still runs from Dart in the sub-engine (see above), because `setAlwaysOnTop` needs the plugin's channel; the runner callback is what makes that channel exist.

**Blocks**: the v2.0 RC, and Unit 9 (which verifies the always-on-top behaviour on real desktops, in both apps).

---

### Unit 9: Integration Milestones

**Packages**: all
**Stories**: M-S2.2, M-S2.3, M-S3.6, M-REG-01
**Stages**: Build and Test, then Documentation Refinement

**Scope**: Two-device P2P on the same network; TURN under restricted-NAT simulation (the Spike 2.3 method); capacity refusal at the cap; reconnection after a network change; signed-out regression; checking the exit criteria (Spike 2.2 result for criterion 7). Also the platform-level checks the units could not assert in tests: Unit 8's five manual checks (hot-plug with the output on, borderless on each platform, the shipped font on a real display, an opaque surface, a theme change reaching the window) plus the Windows/Linux runner callback compile, and Unit 8.1's always-on-top behaviour (pip-ux-parity §8.8 item 15) including the foreign-full-screen limitation. Documentation Refinement applies the documentation updates listed in `phase2-requirements.md`, the S3.6 persona scenario, and AGENTS.md's out-of-date "Current Scope" and worktree guidance (with per-change approval).

**Dependencies**: Units 1-8.1 and all spikes.

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
| 8 External Display | yes | yes | yes | yes | yes | Dependency record (SECURITY-10) |
| 8.1 Pop-out (PiP) | yes | yes | yes | yes | yes | `window_manager` dependency record (SECURITY-10) before CG; spans both apps |
| 9 Integration | Build and Test + Documentation Refinement | | | | | Exit criteria |
