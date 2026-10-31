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

**Exit criteria carried in from Unit 8.1 (deferred 2026-10-23 by James Petersen, so PR #41 could be approved)**: Unit 8.1's two OS-close runtime checks could not be run during its review rounds, because both need synthetic input through System Events and Accessibility was never granted to the verifying host. They move here as Unit 9 exit criteria. Unit 9 does not close until both pass on macOS in a debug build, with Accessibility granted to the host that drives them, and are recorded with evidence. If a check is run on Windows or Linux too, record that platform; if not, say so.

| Id | App | Check | Passes when |
|---|---|---|---|
| A7 | Zip Captions (repeat in Zip Broadcast, per Unit 8.1's B1) | Pop the captions out, then close the pop-out window from the OS (title-bar close button, or Cmd-W with the pop-out focused) | The main window's return panel goes away and the captions come back in the same frame; the chrome and in-surface controls read "Picture in Picture" again; the controller is `Off`; no window is left behind in `CGWindowListCopyWindowInfo` |
| B4 | Zip Broadcast | Turn the external display on, then close its window from the OS | The output switches off at once through `subWindowClosed`, not at the next failed window call (the `'-1'` fallback); the output setting and status pill read off; no window is left behind |

The evidence trail is the PR #41 thread (runtime comments of 2026-10-23 and 2026-10-24) and `aidlc-docs/construction/pop-out/code/summary.md`, section "Review round 7 fixes".

---

## Mobile Alpha Units (appended 2026-10-24)

**Appended to the Phase 2 cycle 2026-10-24**, after Unit 8.1 merged (PR #41, `cd0451f`). James Petersen approved the plan on 2026-10-22. It is recorded only now so that it never shared a checkout with the Unit 8.1 branch. It follows the Unit 3.1 and Unit 8.1 precedent: new units are appended, and no completed phase or unit is reopened. James Petersen assigned the unit numbers on 2026-10-24. The approved plan called these units A to D: **A = Unit 10, B = Unit 11, C = Unit 12, D = Unit 13**. The parked on-device multilingual STT unit stays unnumbered. Under its own OQ-1 (`aidlc-docs/construction/on-device-multilingual-stt/execution-plan.md`), it takes the next free number when it is approved.

**Why these units exist.** The roadmap had no alpha milestone, and phones first appear at the Phase 6 store submission. The AI-DLC records and the platform configuration show that some mobile requirements in completed work were never verified on a device, and others were never assigned to a unit. The gap table below records where each one came from. The original units stay as written.

**Decisions (2026-10-22):**
- **Two-stage internal alpha.** Alpha 1 is local captioning on iPhone and Android (Units 10 and 11). Alpha 2 adds the broadcast viewer once Unit 9 and a staging backend exist (Units 12 and 13).
- **Placement:** appended to the Phase 2 cycle.
- **Order:** Unit 10 runs first after Unit 8.1 merges.
- **Testers:** a small internal group, through TestFlight internal testing and Play Internal Testing.

**Relation to Unit 9 (decided 2026-10-24).** Unit 9 is unchanged and still closes the original Phase 2 scope: Units 1 to 8.1 and the spikes. Units 10 and 11 do not depend on Unit 9 and may run before it. Units 12 and 13 run **after** Unit 9, as post-close Phase 2 units. Each carries its own verification, and Unit 13's Build and Test is the Alpha 2 exit gate. Unit 9's Build and Test does not wait for them.

### Gaps found (origin recorded; the original units are not reopened)

| # | Gap | Where it was missed | Evidence | Closed by |
|---|---|---|---|---|
| G1 | The mobile captioning exit criterion was never verified on a device | Phase 1 exit criterion 1 | `construction/build-and-test/build-and-test-summary.md`: integration and E2E "pending manual", macOS artifacts only. `audit.md` has no iPhone, simulator or Android-device run | Unit 10 |
| G2 | iOS microphone permission is likely always denied | Phase 1 Unit 2 (FR-6.3) | `packages/zip_captions/ios/Podfile` `post_install` sets no `PERMISSION_MICROPHONE=1` macro, and `zip_core`'s `stt_session_manager.dart` (`_checkPermission`) gates on `permission_handler` | Unit 10 |
| G3 | Android declares no `RECORD_AUDIO` and no `RecognitionService` `<queries>` entry | Phase 1 Unit 2 (FR-6.1, FR-6.3) | `android/app/src/main/AndroidManifest.xml` declares no permission; its only `<queries>` intent is `PROCESS_TEXT` | Unit 10 |
| G4 | The Android release build has no `INTERNET` permission | Phase 2 Unit 7 (NFR-8.2) | Only the `debug` and `profile` manifests declare it | Unit 13 |
| G5 | Release identity and signing are unset | No unit before Phase 6 | The release build signs with the debug keystore; `android:label` is `zip_captions`; there is no iOS `DEVELOPMENT_TEAM`; the bundle IDs (`com.zipcaptions.zip_captions`, `com.zipcaptions.zipCaptions`) are not reconciled with the v1 store listings | Unit 10 (identity), Unit 11 (signing) |
| G10 | No real speech recogniser is registered in either app. Captioning "works" on a phone only because the debug build registers a fake engine | Phase 1 Unit 2 delivered `PlatformSttEngine`, `SherpaOnnxSttEngine` and the registry, but no plan document found assigns the app-level registration. Found 2026-10-24 while reproducing G3 | `zip_captions/lib/src/bootstrap.dart:83-85` registers only `FakeSttEngine`, under `kDebugMode`, so a release build registers no engine. `zip_broadcast`'s `sttEngineFactory` returns the fake in debug and throws `UnimplementedError` otherwise. Neither real engine is instantiated outside its own file. Observed on `Pixel_9_Pro_API_36` (debug, `RECORD_AUDIO` not granted): tapping Start Captioning opens `/recording` with no prompt, and `console_logs` shows `Engine fake initialized` and `Engine fake listening`. Detail: `construction/mobile-platform-readiness/evidence/g2-g3-g10-observations.md` | Unit 10 (zip_captions); zip_broadcast is recorded only |
| G6 | No unit verifies the mobile viewer | NFR-8.2 vs Unit 9's scope | Unit 9's device checks do not name a phone | Unit 13 |
| G7 | No automated mobile E2E | The Phase 1 Build and Test summary deferred it "to Phase 2" | No Phase 2 unit carries it | Unit 13 |
| G8 | No hosted non-production backend | The roadmap has only Phase 6 production infrastructure | `zip_core`'s `supabase_config.dart` and `turn_config.dart` default to `localhost` | Unit 12 |
| G9 | Screen-on during mobile captioning is unverified | Project constraint (the screen stays on while captioning) | `wakelock_plus` is declared in `zip_core` but has never been observed working on a phone | Unit 10 |

G2, G3, G4, G5 and G8 were re-checked against `develop` at `cd0451f` on 2026-10-24. Unit 8.1 changed no `ios/` or `android/` file. G2 and G3 come from reading the configuration, so reproducing them on a device is Unit 10's first task.

**Amendment 2026-10-25 (from the Unit 10 reproduction run of 2026-10-24):**
- G10 was found. Until a real engine is registered, G2 and G3 cannot be reproduced through the app. The fake engine never reaches the permission check.
- G3 is partly wrong. The merged debug manifest does declare `RECORD_AUDIO`, supplied by a plugin; the source manifest alone declares none. What is missing is the `RecognitionService` `<queries>` entry. Whether the merged release manifest also carries `RECORD_AUDIO` is not yet checked, and Unit 10 records it.
- `speech_to_text` and `record` are the plugins to check for who supplies each permission.

### Virtual-device development and QA (applies to Units 10-13)

Day-to-day development and QA run on virtual devices, driven through the `flutter-agent-lens` MCP server. Physical devices are kept for the gates that emulators cannot prove.

- **iOS Simulator** (Xcode 26, iOS 26.0): the default is **iPhone 17**, and **iPhone 16e** is the small-screen check.
- **Android emulator:** `Pixel_9_API_35` and `Pixel_9_Pro_API_36`. Both are `google_apis_playstore` images with `hw.audioInput=yes`, because `speech_to_text` needs Google's on-device recognizer. The `google_apis`-only AVDs are not used for STT testing.
- **Build mode:** run in **debug or profile** mode only. Release builds disable the VM Service, so the MCP cannot attach to them.
- **Evidence per check:**
  - `screenshot`, using `capture_baseline` and `compare` for the Recording, Settings and Viewer screens.
  - `console_logs`, for permission and STT errors.
  - `get_navigation_stack`, for route assertions such as `/recording` and `/b/:broadcastId`.
  - `widget` → `get_tree`.
  - `network`, for Supabase and signaling calls in Units 12 and 13.
  - Emulator `profiling` results are indicative only.
- **Limit:** the MCP has no tap or text-entry tool. The UI is driven by `integration_test` flows (Unit 13's harness), by `adb shell input` on Android, or by hand on the Simulator. `evaluate_expression` is for diagnostics, not for driving the UI.
- **Permissions:** pre-grant them for repeatable runs:
  - Android: `adb shell pm grant com.zipcaptions.zip_captions android.permission.RECORD_AUDIO`
  - iOS: `xcrun simctl privacy <udid> grant microphone com.zipcaptions.zipCaptions`

  Also test the un-granted path (`pm revoke`, `simctl privacy … reset`), because that path reproduces G2 and G3. iOS speech-recognition consent is OQ-MA-1 (Unit 10).
- **Audio:** route the Mac's input to the emulator. For repeatable STT checks, play a fixed speech clip through the Mac's output rather than speaking live.
- **Local backend:** the Android emulator reaches the host's Supabase and coturn through `10.0.2.2` or `adb reverse`, passed with `--dart-define`. The Simulator can use `localhost`.

**What emulators cannot prove, so the physical-device gate stays:**
- real-microphone latency for Phase 1 NFR-1.1 (< 1 s)
- screen-on and wake lock under real power management (G9)
- recognizer availability on real hardware
- a signed install from TestFlight or Play
- a real Wi-Fi to cellular network change

Every exit gate in Units 10-13 therefore needs **both** a recorded emulator QA pass (screenshots and logs captured through the MCP) and a physical-device pass.

### Unit 10: Mobile Platform Readiness (Alpha 1)

**Package**: zip_captions (`ios/` and `android/` runner configuration, plus app-level STT engine registration in `lib/`). zip_broadcast is checked for the same defects, and the result is only recorded, because zip_broadcast ships on desktop. G10 (added 2026-10-25) makes a `lib/` change part of this unit.
**Stories**: S-22
**Stages** (amended 2026-10-25 to add G10): Functional Design, then NFR Requirements, then Code Generation, then a device verification pass. Functional Design is no longer skipped, because G10 adds engine-selection behaviour. It covers:
- which engine each platform registers (`PlatformSttEngine` on iOS and Android is the expected default)
- what happens when the engine reports unavailable, or `initialize()` fails
- whether the debug-only fake stays registered alongside the real engine, and how it is kept out of release builds
- that no transcript content is logged in the new path (AGENTS.md critical constraint)

Functional Design stays small, with no new entities beyond the registration seam. It does not change the `SttEngine` interface or `SttResult`, which AGENTS.md lists as stable contracts. If the work needs either to change, stop and ask.

**Amendment 2026-10-25 (N9):** the work did need the contract surface to grow. The platform engine cannot caption continuously (the locked `speech_to_text` 7.3.0 is built for short phrases, and `PlatformSttEngine` never restarts or listens for errors), and `SttEngine` has no error channel. James Petersen approved an additive error channel on 2026-10-25 and reopened Functional Design narrowly (`construction/mobile-platform-readiness/functional-design/amendment-01-continuous-listening.md`). `SttResult` is still unchanged. Any further change to `SttEngine` or `SttResult` still needs a stop and ask.

NFR Requirements covers:
- the permission matrix per platform
- how signing secrets are handled under the Security Baseline (the keystore and `key.properties` are never in git)
- the app identity and bundle-ID decision against the v1 store listings
- the G10 real-engine requirements, which are recognizer availability per platform and failure behaviour. Latency stays a physical-device check.

**Gate**: OQ-MA-1 (below) must be answered and recorded before NFR Requirements is approved.

**Closes**: G1, G2, G3, G5 (identity only), G9, G10.

**Verification**:
1. Reproduce G10 first (done 2026-10-24 on `Pixel_9_Pro_API_36`; see the evidence file). Then reproduce G2 and G3 on the iPhone 17 Simulator and the `Pixel_9_Pro_API_36` emulator, with permissions **not** pre-granted. This needs a real engine registered, so it uses a throwaway local registration that is reverted, never committed, and needs James Petersen's approval first. Capture evidence through `flutter-agent-lens` (`console_logs`, `screenshot`).
2. Repeat the same run after the fix, with the real engine registered by the committed change.
3. Run on a physical iPhone and a physical Android device against Phase 1 exit criterion 1 and Phase 1 NFR-1.1 (< 1 s latency).

Evidence is recorded in this unit's artifacts. Phase 1's records stay unchanged.

**Dependencies**: Unit 8.1 merged, because work runs on one branch at a time (merged 2026-10-24). Unit 10 shares no files with Unit 8.1.

#### Open questions: blocking gates (no Code Generation until answered and recorded)

| ID | Question | Blocks | How to answer | Answer |
|---|---|---|---|---|
| OQ-MA-1 | Can the iOS Simulator's **speech-recognition** consent be pre-granted, as the microphone is with `xcrun simctl privacy <udid> grant microphone <bundle>`? Or does the `NSSpeechRecognitionUsageDescription` prompt need accepting by hand every time the app is installed fresh? | Unit 10 Code Generation (it decides whether repeatable emulator QA is scriptable on iOS, or needs a manual step in the QA procedure) | On the iPhone 17 Simulator, run `xcrun simctl privacy help` and check whether a speech-recognition service is listed. If it is, grant it, run the app with `flutter-agent-lens` attached, and confirm through `console_logs` and `screenshot` that no prompt appears and captioning starts. If it isn't, record the manual step and check whether `simctl privacy … reset all` returns the prompt between runs. | **ANSWERED 2026-10-25** (iPhone 17 Simulator, iOS 26.0). No speech-recognition service is listed, so consent cannot be pre-granted. `simctl privacy … reset all` brings **both** the microphone and the speech-recognition prompts back on the next Start Captioning, so iOS QA is scriptable for the microphone and needs one manual Allow on the speech prompt after each fresh install or reset. Evidence: `construction/mobile-platform-readiness/evidence/q3-throwaway-check.md`. |

Rules for this table:
- Each row is answered with evidence (command output plus the MCP screenshot or logs) and recorded in Unit 10's NFR Requirements artifact and in `audit.md`.
- **Unit 10 must not leave NFR Requirements while any row it blocks is still OPEN.**
- New open questions found during planning go into this table with the stage they block.

---

### Unit 11: Internal Alpha Distribution (Alpha 1)

**Packages**: zip_captions (release configuration), CI (`.github/workflows/`)
**Stories**: S-22 (continued: the app installs from the test tracks)
**Stages**: NFR Requirements, then Infrastructure Design (CI release lanes for a signed `ipa` and `aab`, plus GitHub Actions secrets), then Code Generation.

**Closes**: the rest of G5 (signing and distribution).

**Human prerequisites**: an Apple Developer team with an App Store Connect record, a Play Console app, and an upload key.

**Testers**: internal only, so there is no Beta App Review. Builds go to TestFlight internal testing (up to 100 testers) and Play Internal Testing. NFR Requirements checks whether Play needs a privacy policy or a Data safety form for internal testing of an app that requests `RECORD_AUDIO`.

**Exit (Alpha 1 gate)**: an internal tester installs from both test tracks and completes a captioning session.

**Dependencies**: Unit 10. Unit 11 needs the human prerequisites above, so other units may proceed while it waits on them.

---

### Unit 12: Staging Backend (Alpha 2)

**Packages**: zip_supabase (staging deployment configuration), zip_core (build-time configuration only)
**Stories**: none new (enabler for S-23), gated by SR-05
**Stages**: NFR Requirements, then Infrastructure Design, then Code Generation. Infrastructure Design produces the SR-05 document and is an **approval gate**: the services are exposed to the public, so the review follows the SR-03 pattern.

**Closes**: G8.

**Scope**: hosted Supabase and coturn as **staging**, kept explicitly separate from the Phase 6 production infrastructure. The apps take build-time `--dart-define` values for `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ICE_SERVER_URLS` and `BROADCAST_BASE_URL`. Internal testers join through `JoinBroadcastScreen`, so universal links and app links stay deferred.

**Dependencies**: Unit 9, so that the desktop broadcast path is verified first. Unit 12 runs after Unit 9 as a post-close Phase 2 unit.

---

### Unit 13: Mobile Viewer Verification (Alpha 2)

**Packages**: zip_captions (Android manifest, `integration_test` smoke harness), CI
**Stories**: S-23
**Stages**: NFR Requirements, then Code Generation, then Build and Test.
- NFR Requirements decides the smoke-harness choice: `integration_test`, Patrol or Maestro. A new dependency needs the usual approval.
- Code Generation adds the `INTERNET` permission and the mobile smoke E2E harness.

**Closes**: G4, G6, G7.

**Scope**: a phone joins a desktop Zip Broadcast session over staging. The run covers P2P, TURN, reconnection after a Wi-Fi to cellular switch, and the capacity-refusal copy.

**Emulator first**:
- Run the join, receive and reconnect flows on the Simulator and the Android emulator, first against the local stack and then against staging.
- Simulate network loss with the emulator's network controls or with airplane mode.
- Assert with `get_navigation_stack`, `network` and `screenshot` `compare`.
- The `integration_test` smoke harness runs on both virtual devices in a form CI can run.
- The real Wi-Fi to cellular switch stays a physical-device check.

**Exit (Alpha 2 gate)**: an internal tester on each platform views a live session from the test-track build.

**Dependencies**: Units 11 and 12. Unit 13 runs after Unit 9 as a post-close Phase 2 unit.

---

### Unit 14: Automated Test Suite (Device QA + Regression Coverage)

**Raised**: 2026-10-30 by James Petersen during the Unit 10 physical-device pass ("is there any way to define these tests in code so that we can re-run the entire suite with an automation rather than requiring an active LLM session?"), and recorded in the Backlog (`aidlc-state.md`). **Rescoped same day by James Petersen**: "The intent of this unit we're describing is to cover the software with high quality tests that can help us during the remainder of the build. We are not going to restrict it to only zip-captions nor restrict it to only on-device tests. I want to ensure that we are using a solid testing approach to cover the platform, so that future automated builds can check quality." The unit is therefore the project's automated quality suite: both apps, all shipped platforms, run by the automated build and available for PR review. **Unit definition PROPOSED 2026-10-30 (rescoped), awaiting James Petersen's approval.** Unit numbers stay James Petersen's to assign (the Units 10-13 precedent): if the parked on-device multilingual STT unit is approved before this one, the numbers are swapped.

**Packages**: zip_captions (`patrol_test/` — Patrol 4's test directory, not `integration_test/` — and app-level desktop tests), zip_broadcast (app-level desktop tests), CI (`.github/workflows/`), both `pubspec.yaml` files (dev dependencies only). `zip_core` is not changed. Production code is not changed except where a test genuinely cannot reach a flow through the UI, which is a stop-and-ask, not a workaround.

**Stories**: none new. Regression protection for the features Units 1 to 11 and 13 ship; it automates the S-22 physical-device gate.

**Test strategy — two tiers** (the pyramid below the app level already exists and stays: `melos run test` / `dart analyze --fatal-infos` in CI, 1233 / 443 / 195 tests across `zip_core`, `zip_captions`, `zip_broadcast` as of the Unit 10 pass):

- **Tier A — app-level tests on virtual devices, run in CI on every PR and build.** This is the regression check for PR review and must stay fast and deterministic.
  - **zip_captions (Android emulator + iOS Simulator): Patrol.** The same tests run unchanged on physical devices (Tier B), so CI and device exercise one codebase. Deterministic flows use the debug **fake engine** (scripted results): permission grant/deny/blocked with native dialogs via `$.platform.mobile`, Start/Stop/Pause/Resume, History rows, stop notices, empty session, navigation, settings.
  - **zip_broadcast (macOS, Linux; Windows): `integration_test`.** Patrol does not support Windows or Linux and macOS is alpha (verified against the Patrol supported-platforms docs, 2026-10-30), so desktop app-level tests use Flutter's `integration_test` (ships with the SDK; no new dependency), driven through the existing provider override seams (`sttEngineFactoryProvider`, `captionBusProvider`, `authServiceProvider`, fakes from `test/helpers/`): dashboard, Go Live/End unwind, settings, external-display and pop-out controls.
  - **zip_captions desktop and web:** non-captioning flows only (Settings, History, navigation). Mobile is where captioning exists until the desktop-engine decision (G10 Backlog).
  - The existing provider-level tests under `test/integration/` stay; these new tests add the real widget tree and native dialogs on top.
- **Tier B — the physical-device suite, on demand.** The original scope, unchanged: Unit 10's checks run as Patrol tests on the attached phones with **real on-device recognition** (a bundled speech clip played from the phone's own speaker; no fake engine, no host-microphone routing). Nothing is scheduled (James Petersen, 2026-10-30: "There's no need for nightly, only for when I'm testing a PR for tier B."). The long waits (5-minute renewal, inactivity stop) form a separate **long-running** tag so they run only when asked for; the fast group covers everything else. Tier B runs when James Petersen tests a PR or gates a release.

**Device checks to cover** (source of truth: `aidlc-docs/construction/mobile-platform-readiness/evidence/code-generation-qa.md`, "Physical Android device pass, 2026-10-30", plus the joint QA runbook, in-repo at `aidlc-docs/construction/automated-test-suite/joint-qa-runbook.md` — Part B is the Android checklist, Part A is Simulator input checks that the physical-iOS suite does not carry, Part D is the Unit 9 agenda and is out of scope. The runbook's four pass rules for a captions run apply: recognised text on screen; `segmentCount` > 0; expected locale; no SnackBar or toast. Speech only after the recogniser is ready):
- the permission grant, deny and "blocked" paths, including Open settings and Try again (the AC-2 checks);
- captions appearing and segments saved (History rows) (B1, B4);
- the last phrase kept at Stop and at Pause (B7, BR-U10-55/56, Amendment 06);
- no words lost at the 5-minute renewal (B9, D-2, Amendment 01; BR-U10-39/44);
- the stop notices: one combined notice per stop (Amendment 07, BR-U10-65/66/67);
- the empty session (Q-2, the `nothingRecognised` notice and no History row);
- the wake lock set while captioning and cleared after Stop (B10, G9, `dumpsys` observation);
- airplane mode: captioning works with no network (NFR, "works without an internet connection");
- the 5-minute inactivity stop (B11, Amendment 05, BR-U10-53).

**Stays manual**: the sounds (chimes, BR-U10-43). There is no reliable automated check for audible output; the sounds remain a manual checklist alongside the suite.

**Platform matrix** (Patrol docs, verified 2026-10-30): Android API 21+ and iOS 13+ on physical and virtual devices — Patrol. macOS — Patrol alpha; Windows and Linux — not supported, use `integration_test`. Web — Patrol Web (v4) vs `integration_test` on Chrome, decided at Functional Design.

**Determinism principle**: real recognition lives only in Tier B. Tier A uses the debug fake engine with scripted results, so CI is flake-resistant and fast; the real engine and real microphone path are never claimed by a Tier A pass. No transcript text in logs, test output or artifacts at any tier (SECURITY-03); assertions use counts and states, never recognised words.

**Runner**: Tier A — GitHub-hosted CI jobs added to the existing workflow set (Android emulator job, macOS and Linux desktop jobs; Simulator job if the iOS tier-A suite earns its wall-clock cost — NFR Design sets the budget). Tier B — this Mac with the phones attached, **on demand only**: a self-hosted GitHub Actions runner **locked down so fork pull requests cannot run on it**, triggered by `workflow_dispatch` when James Petersen tests a PR, or the local `patrol test --device <id>` command. No scheduled runs. Hosted runners cannot reach physical devices.

**Constraints that bind this unit** (project rules, restated so the harness cannot violate them):
- **App flows only.** Every check goes through the app's own screens, driven by the test framework. adb is for setup and observation only (logcat, `dumpsys`, screenshots): no `pm grant`, no `adb input` shortcuts past a step a real user could not take.
- **Screen on.** The screen stays on while captioning (the consent/visibility constraint). Any test that would let it sleep must keep it awake the way the app does, not with a hidden `adb` keep-awake that hides a wake-lock regression.
- **No transcript text.** (SECURITY-03, as above.)
- **Strings.** Any new test-support string that ships in the app goes through `l10n/arb/app_en.arb` with a `ZcStrings` getter. Test-only strings live in the test code, not the app.

**Relation to Unit 13**: Unit 13 keeps G7 (the viewer-join smoke E2E). This unit now makes the harness decisions for the project (Patrol on mobile, `integration_test` on desktop/web); Unit 13's NFR Requirements adopts them and reuses this unit's harness instead of picking independently.

**Closes**: no G gaps; G7 stays with Unit 13. What it closes is the recurring manual cost of the physical-device gate and the missing app-level regression layer for both apps.

**Devices**: Pixel 6, adb serial `25071FDF600953`, Android 17, cleared for this project. iOS: a physical iPhone with Developer Mode and a signing team, device to be named by James Petersen (the Simulator cannot substitute for Tier B: `simctl privacy` cannot pre-grant speech recognition, OQ-MA-1).

**Dependencies**: Unit 10 (decided 2026-10-30). PR #44 is nearly ready to merge; the suite works from that state — `feature/mobile-device-test-suite` is cut from `feature/mobile-platform-readiness` now and Unit 10's new commits are merged in as they land; once PR #44 merges to `develop`, the branch rebases onto `develop` and tracks it from then on. All tiers share that one base (James Petersen: "we will be working from that state once that PR is merged"). `patrol`, `patrol_cli` and any audio-playback package are new dev dependencies and need James Petersen's approval with a SECURITY-10-style record before Code Generation (the Unit 8.1 `window_manager` precedent). `integration_test` needs no dependency.

**Verification**: a Tier B test counts as passing only when it has run on the device. A Tier A test counts as passing only when it has run green in CI on the virtual device or platform it claims. The unit's Build and Test is the full Tier A suite green in CI plus the Tier B suite (including the long-running tag) passing on the Pixel 6 (and on the iPhone once one is assigned) during this unit's own run; afterwards Tier B runs on demand, not on a schedule.

**Sequencing** (James Petersen, 2026-10-30: "as soon as possible so that we can leverage it during the remaining build phases"): Tier A desktop (`zip_broadcast`) first — usable for PR review immediately and independent of Unit 10; then Tier A mobile (`zip_captions` on emulator/Simulator); then Tier B on the physical phones as Unit 10 lands.

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
| 10 Mobile Platform Readiness | yes (G10, added 2026-10-25) | yes | — | — | yes | OQ-MA-1 answered before NFR-R approval; emulator and physical-device pass |
| 11 Internal Alpha Distribution | — | yes | — | yes | yes | Alpha 1: install from both test tracks and complete a session |
| 12 Staging Backend | — | yes | — | yes (SR-05) | yes | SR-05 before CG; runs after Unit 9 |
| 13 Mobile Viewer Verification | — | yes | — | — | yes, then Build and Test | Alpha 2: a tester on each platform views a live session; runs after Unit 9 |
| 14 Automated Test Suite (definition pending) | yes | yes | yes | yes | yes, then Build and Test | `patrol`/`patrol_cli` + audio-playback dependency record (SECURITY-10) before CG; a Tier B test counts as passing only when it has run on the device, a Tier A test only when green in CI on the platform it claims |
