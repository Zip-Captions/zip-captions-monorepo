# Application Design Plan — Phase 2: Broadcasting & Transport

## Plan Overview

Phase 2 adds the first networked layer on top of the Phase 1 architecture (CaptionBus + CaptionOutputTargetRegistry, registry-managed targets, settings split per concern). New components cover broadcaster authentication, broadcast identity and resolution, Realtime signaling, a transport abstraction with a WebRTC implementation, a remote broadcast output target and its viewer-side receiver, capacity admission, TURN credential issuance, and completion of the Phase 1 `CaptionOverlayTarget`.

This stage defines components, interfaces and dependencies only. Mechanisms left open by earlier stages stay open, and the design will define interfaces only for them:
- **Resolution mechanism** (restricted RPC/view vs Edge Function): Unit 3 Functional Design, under SR-02
- **TURN credential issuance**: Spike 2.3 and Unit 4 Infrastructure Design, under SR-03
- **OAuth flow per platform**: Unit 2 Functional Design, under SR-01

**Design constraints carried forward** (not questions):
- Services are plain Dart classes held by Riverpod providers (Phase 1 Q1). Output targets are registry-managed (Phase 1 Q2).
- Side effects are explicit calls from notifiers, not reactive watchers (project Riverpod convention).
- Stable contracts are consumed unchanged: `SttResult`, the caption bus contract, the stable URL format, and the Section 9 channel names.
- Signaling sits behind an interface (a Supabase Realtime implementation plus fakes for tests), so later phases can add other signaling paths.
- New dependencies: `supabase_flutter` and `flutter_webrtc` are pre-approved. Anything else needs approval (see Q6).

Output files use a `phase2-` prefix, matching the Phase 1 convention (`phase1-components.md`, etc.).

Fill in the letter choice after each `[Answer]:` tag. If none of the options match, choose X and describe your preference.

## Design Steps

- [x] Step 1: Identify all new Phase 2 components and their package locations (per Q1)
- [x] Step 2: Define modifications to existing Phase 1 components (CaptionOverlayTarget, app shells, routers, output target settings)
- [x] Step 3: Design the auth service abstraction and Supabase client ownership (per Q5)
- [x] Step 4: Design broadcast identity: registry client and resolver interface
- [x] Step 5: Design the signaling interface and message model (status and signaling channels, presence)
- [x] Step 6: Design the transport abstraction and the WebRTC implementation boundary (per Q2)
- [x] Step 7: Design the remote broadcast output target, the viewer-side receiver and capacity admission
- [x] Step 8: Design broadcaster session orchestration and its relationship to recording (per Q3) — independent by default, optional auto-start, captions-inactive signalling
- [x] Step 9: Design viewer session orchestration and caption bus usage (per Q4)
- [x] Step 10: Design external display completion: secondary-window entry point and display enumeration (per Q6)
- [x] Step 11: Design the Zip Captions `/b/{broadcast_id}` route and join flow wiring
- [x] Step 12: Record security design notes (tokens, zero-retention, enumeration, authorization boundaries)

## Mandatory Artifacts

- [x] Generate `phase2-components.md` with component definitions and high-level responsibilities
- [x] Generate `phase2-component-methods.md` with method signatures
- [x] Generate `phase2-services.md` with service definitions and orchestration patterns
- [x] Generate `phase2-component-dependency.md` with dependency relationships and communication patterns
- [x] Generate `phase2-application-design.md` as the consolidated summary
- [x] Validate design completeness and consistency against phase2-requirements.md and phase2-stories.md — Q3 revisions applied to FR-6.7, FR-7.4, S-16, S-17, S-19, Proto-11, Proto-12, Proto-15

---

## Questions

### Question 1 — Package placement for broadcast components
Phase 1 placed shared components in zip_core and broadcaster-only targets (OBS, browser source, overlay) in zip_broadcast. Phase 2 has components used by only one side (the remote output target and session orchestration on the broadcaster; the receiver and viewer session on the viewer), but both sides share the same protocol, wire format and transport. Phase 3 also plans P2P key transfer over WebRTC in both apps.

A) **All protocol, transport and session components in zip_core (broadcaster and viewer sides).** The apps hold only UI, routing and wiring. Both sides of the protocol live in one package and can be tested against each other there. **(Recommended)**
B) **Strict Phase 1 split.** Signaling, transport, wire format and identity go in zip_core. Broadcaster-only components (remote output target, broadcast session, capacity) go in zip_broadcast. Viewer-only components (receiver, viewer session) go in zip_captions.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 2 — Transport abstraction shape
FR-4.7 requires that the Phase 3 relay and the Phase 5 local WebSocket and BLE GATT transports plug in later without changing the caption bus or rendering. How should the abstraction be shaped?

A) **Role-specific interfaces.** A `BroadcastTransport` on the broadcaster side accepts viewers, sends to all of them and reports per-viewer connection info. A `ViewerTransport` on the viewer side connects and exposes a stream of caption messages and connection state. `WebRtcBroadcastTransport` and `WebRtcViewerTransport` implement them. A `TransportSelector` picks the transport per ADR-011 negotiation; in Phase 2 it always returns WebRTC. **(Recommended)**
B) **One symmetric `PeerLink` interface** per point-to-point connection (send, receive, state). The broadcaster keeps a collection of links and the viewer holds one. Fan-out logic lives in the broadcast session, not the transport.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 3 — Broadcast lifecycle vs recording lifecycle
In Zip Broadcast, `RecordingStateNotifier` controls captioning (start, pause, resume, stop). A remote broadcast adds a second lifecycle: live, viewers connected, ended. How should the two relate?

A) **Coupled start, decoupled stop.** Going live starts captioning if it is not already running. Pausing or stopping captioning keeps the broadcast live, and viewers see a paused or waiting state (FR-5.1 session state changes). Ending the broadcast is a separate, explicit action and does not stop local captioning. **(Recommended)**
B) **Fully coupled.** The broadcast is a mode of the recording session. Starting recording with "broadcast" enabled goes live, and stopping recording ends the broadcast for all viewers.
C) **Fully independent.** Going live never starts captioning. Viewers wait until the broadcaster starts captioning.
X) Other (please describe after [Answer]: tag below)

[Answer]: It should be independent, so that broadcast can start without starting captions, but there should be a configuration option to provide the coupled start if a user desires. In the case where a broadcast exists but no active caption session is running, the UI for any connected user should render a message similar to the paused message, whereby it informs the user that there is no active text stream because the broadcast has paused captions. The broadcaster should be able to easily see a large notification that the captions are inactive when in an active broadcast with no live captioning sessions yet started.

### Question 4 — Viewer session and caption bus usage
FR-5.3 requires received captions to flow through a caption bus so the Phase 1 rendering pipeline shows them unchanged. Zip Captions already has one app-wide `CaptionBus` fed by self-captioning.

A) **Separate `ViewerSessionNotifier` with its own viewer-scoped `CaptionBus` instance and `OnScreenCaptionTarget`.** Viewing never mixes with self-captioning. Saving a transcript of viewed captions (requirements assumption 3) attaches a `TranscriptWriterTarget` to the viewer bus. **(Recommended)**
B) **Publish received captions into the existing app-wide `CaptionBus`.** Viewing and self-captioning are mutually exclusive, so starting one stops the other.
C) **Extend `RecordingState` and `RecordingStateNotifier` with a "viewing" mode**, reusing the recording screen for viewing.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 5 — Supabase client ownership
Auth, identity and signaling all need a Supabase client. No package depends on `supabase_flutter` yet.

A) **Each app initializes Supabase at startup** (URL and anon key from build-time config) and injects the client into zip_core through a provider override. This follows the existing `sharedPreferencesProvider.overrideWithValue(...)` pattern, and zip_core services receive the client through their constructors, so they can be tested without a network. **(Recommended)**
B) **zip_core owns initialization.** A zip_core bootstrap function reads the config and initializes Supabase itself, and apps call it from `main()`.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 6 — Display enumeration for external display (S-20)
The Phase 1 `CaptionOverlayTarget` accepts a `targetDisplayId`, but nothing can list the connected displays, and `desktop_multi_window` does not provide that.

A) **Add `screen_retriever`** (macOS, Windows, Linux; from the same maintainer family as the common desktop window plugins) behind a `DisplayEnumerator` interface. Choosing this option approves the new dependency, subject to the SECURITY-10 version pinning and justification recorded in Unit 8. **(Recommended)**
B) **Implement enumeration with platform channels** (`com.zipcaptions.displays`) on each desktop OS. There is no new dependency, but it adds native code on three platforms.
C) **Define only the `DisplayEnumerator` interface now**, and choose between A and B during Unit 8 Functional Design (the Phase 1 precedent for the overlay).
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Instructions

Fill in each `[Answer]:` tag with a letter, plus any context. Once all are answered, the design artifacts are generated for your review.
