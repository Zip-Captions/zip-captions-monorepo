# Phase 2 — Broadcasting & Transport: Requirements Verification Questions

Please answer the following questions to clarify Phase 2 scope, priorities, and cross-phase dependencies. Fill in the letter choice after each `[Answer]:` tag. If none of the options match, choose the last option (Other) and describe your preference.

**Context for this phase (from `docs/03-roadmap.md` and ADR-008/011/006):** Phase 2 restores v1's live broadcast (broadcaster → viewers), replacing Socket.IO + PeerJS with **Supabase Realtime signaling + WebRTC data channels**, self-hosted **Coturn** for STUN/TURN, an **opt-in Supabase Realtime relay** fallback, and **stable broadcast URLs** (`zipcaptions.app/b/{id}`) replacing v1 join codes. The caption bus (ADR-008) already exists, and the OBS WebSocket + browser-source output targets already shipped in Phase 1 (Unit 6). Phase 2 can run in parallel with Phase 3 (Auth, Encryption & Sync) — several questions below exist because Phase 2 deliverables in the roadmap reference capabilities (accounts, zero-knowledge encryption) whose foundations land in Phase 3.

---

## Question 1 — Research spike sequencing (you flagged this)
The roadmap flags three spikes for Phase 2: **2.1** Supabase Realtime channel limits/throughput, **2.2** OBS WebSocket closed-caption protocol confirmation, **2.3** Coturn/TURN deployment alongside Supabase (symmetric-NAT relay). My assessment: none of these block *Requirements Analysis* — they validate feasibility/infrastructure and feed Construction-phase NFR Design and Infrastructure Design, not the WHAT/WHY of requirements. This matches the Phase 1 precedent, where spikes 1.1–1.3 ran as early Construction units, not before requirements. How should the spikes relate to Phase 2?

A) Run all 3 spikes as **early Phase 2 Construction units** (before their dependent units), and proceed with Requirements Analysis now — recording any requirement whose *target value* depends on a spike outcome as "TBD pending Spike X" (matches Phase 1 precedent) — **(Recommended)**
B) Complete all 3 spikes **before** Requirements Analysis proceeds (block requirements on spike outcomes)
C) Split — run only spikes that could change the *architecture* before requirements (e.g. 2.1 if Realtime can't scale), defer the rest to Construction
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 2 — Broadcaster identity vs. the Phase 3 auth dependency
ADR-011 defines stable broadcast URLs as **"a persistent broadcast ID tied to their account"** for each *authenticated* broadcaster. But authentication (Supabase GoTrue / OAuth) is a **Phase 3** deliverable, and Phases 2 and 3 run in parallel. Phase 2 needs *some* broadcaster identity to anchor a persistent broadcast ID and to key session persistence. How should Phase 2 handle broadcaster identity?

A) Build Phase 2 against an **abstracted broadcaster-identity interface** with an anonymous device-local stub (a persistent per-device broadcaster ID, no account); real account-tied IDs are wired in when Phase 3 lands, migrating the device-local ID to the account — **(Recommended)**
B) **Pull minimal authentication forward** into Phase 2 (a broadcaster must sign in before broadcasting); full OAuth/account-merging stays Phase 3
X) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 3 — E2E encryption of relayed caption payloads vs. the Phase 3 encryption dependency
The Phase 2 roadmap lists **"E2E encryption of caption payloads over Realtime channels"** as a deliverable, and ADR-006's Zero-Retention Principle requires the relay to never inspect content. But the encryption *infrastructure* (256-bit key generation, secure storage, AES-256-GCM — ADR-006) is a **Phase 3** deliverable. Note WebRTC data channels are already DTLS-encrypted in transit regardless; this question is specifically about the **opt-in Supabase Realtime relay** payloads. How should Phase 2 treat relay-payload encryption?

A) Build **minimal ephemeral per-session payload encryption** in Phase 2 (a symmetric session key exchanged over the already-encrypted WebRTC/signaling channel), independent of and separate from the Phase 3 zero-knowledge *transcript* key system — **(Recommended)**
B) **Defer** caption-payload E2E encryption to Phase 3; Phase 2 relay uses Supabase's TLS-in-transit only, and the relay opt-in warning explicitly states content is not yet end-to-end encrypted
C) **Gate the relay** entirely on Phase 3 — Phase 2 ships WebRTC-only (P2P + TURN); the opt-in Realtime relay is added once Phase 3 encryption exists
X) Other (please describe after [Answer]: tag below)

[Answer]: C

---

## Question 4 — Transport scope: internet-only vs. include local transports
ADR-011 defines four transports: WebRTC (internet P2P/TURN), Supabase Realtime relay (internet fallback), **local Wi-Fi WebSocket**, and **BLE GATT**. The roadmap places BLE discovery in **Phase 5**. Which transports are in Phase 2 scope?

A) **Internet transports only** for Phase 2: WebRTC (P2P + self-hosted Coturn STUN/TURN) + opt-in Supabase Realtime relay. Local Wi-Fi WebSocket **and** BLE GATT both stay in Phase 5 (they depend on BLE discovery for peer-finding anyway) — **(Recommended)**
B) Internet transports **plus** the local Wi-Fi WebSocket server in Phase 2 (BLE discovery/GATT stays Phase 5, but the local WebSocket transport is built now so same-network delivery works via the stable URL)
X) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 5 — Remote broadcast output target + OBS closed-caption API (Spike 2.2)
The caption bus (ADR-008) already has OBS WebSocket and browser-source output targets from Phase 1 (Unit 6 — `ObsWebSocketTarget`, `BrowserSourceTarget`). Phase 2 adds the **Realtime/WebRTC broadcast output target** (publishes the `SttResult` stream to remote viewers). What Phase 2 work touches the *existing* OBS output?

A) Phase 2 adds the **Realtime/WebRTC broadcast output target** only; the existing OBS send is left as-is, and **Spike 2.2 confirms whether it already uses the correct OBS closed-caption API** — any required change becomes a scoped follow-up if the spike finds a gap — **(Recommended)**
B) Phase 2 adds the Realtime/WebRTC broadcast target **and** proactively reworks the OBS output to use the proper closed-caption API (per Spike 2.2) as planned Phase 2 work
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 6 — External display / second-screen output
The roadmap lists **"External display / second screen output (where platform supports it)"** as a Phase 2 caption output target (auditorium mode). It is platform-gated and independent of the remote-viewer transport work. Is it in Phase 2 scope?

A) **Defer** external/second-screen output to a later phase; Phase 2 concentrates on remote-viewer transport (WebRTC/Realtime) plus the existing OBS/browser-source outputs — **(Recommended)**
B) **Include** external/second-screen output in Phase 2 on platforms that support it
X) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 7 — Vanity broadcast URLs (premium)
ADR-011 makes **vanity URLs** (`/b/jordan`) a premium feature; the roadmap says "URL reservation logic built here, but enforcement is a Phase 4 dependency." Entitlements (ADR-009) land in Phase 4. What's in Phase 2?

A) **Defer vanity URLs entirely to Phase 4** (when the entitlement system exists); Phase 2 ships auto-generated stable IDs only — **(Recommended)**
B) Build the **vanity-URL reservation + uniqueness-checking logic** in Phase 2, with the premium entitlement gate left as a stub/feature-flag until Phase 4 enforces it
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 8 — Viewer identity
On the viewer side (Zip Captions app receiving a broadcast), does joining a broadcast require any account or sign-in?

A) Viewers are **fully anonymous** — join via stable URL or broadcast ID with no account and no sign-in (matches v1 and the roadmap's viewer UI) — **(Recommended)**
B) Anonymous join is always supported, but viewers **may optionally** sign in (to enable future per-viewer features)
X) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 9 — Broadcast session persistence (Postgres + RLS) timing
The roadmap says broadcast sessions are "persisted in Supabase Postgres," and the broadcast-ID → active-session resolution needs a lookup. Postgres RLS is normally keyed to authenticated users, which ties this to Question 2. When does persistence land?

A) Persist the **broadcast-ID registry + session records in Supabase Postgres now**, with RLS keyed to whatever broadcaster identity Question 2 establishes (device-local ID or pulled-forward auth) — **(Recommended)**
B) Keep broadcast/session state **ephemeral** (in Supabase Realtime presence/channel state) for Phase 2 and defer Postgres persistence + RLS to Phase 3 when auth exists
X) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 10 — Concurrent-viewer scale target (NFR — informs Spike 2.1)
Spike 2.1 will measure how many concurrent connections self-hosted Supabase Realtime can handle. To give the spike and NFR design a target, what concurrent-viewer scale should a single broadcast aim to support?

A) **Small** — up to ~25 concurrent viewers per broadcast (classroom / meeting focus)
B) **Medium** — up to ~100–200 concurrent viewers (conference-session focus)
C) Record the target as **"TBD pending Spike 2.1"** and set it once the spike measures real capacity — **(Recommended)**
X) Other (please describe after [Answer]: tag below)

[Answer]: C but the target size is medium, up to ~100-200 concurrent viewers if capacity allows

---

## Question 11 — Security Baseline extension
Should security extension rules be enforced for this project?

A) Yes — enforce all SECURITY rules as blocking constraints (recommended for production-grade applications; Phase 2 introduces networking, signaling, TURN relay, and a public broadcast surface)
B) No — skip all SECURITY rules (suitable for PoCs, prototypes, and experimental projects)
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 12 — Property-Based Testing extension
Should property-based testing (PBT) rules be enforced for this project?

A) Yes — enforce all PBT rules as blocking constraints (recommended for projects with business logic, data transformations, serialization, or stateful components — Phase 2 has SDP/ICE signaling payloads, session-state machines, transport negotiation, and broadcast-ID serialization)
B) Partial — enforce PBT rules only for pure functions and serialization round-trips
C) No — skip all PBT rules (suitable for simple CRUD, UI-only, or thin integration layers)
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---
