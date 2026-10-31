# Phase 2 User Stories — Broadcasting & Transport

## Organization

Phase 1 conventions carry forward unchanged (plan Q1:A). Stories are organized by **feature area**, at **coarse granularity** (one story per FR group). **Scenario integration milestones** validate end-to-end persona workflows. **UI prototype stories** exist per screen and block their implementation stories. All acceptance criteria use **Given/When/Then**. Research spikes are dependencies, not stories.

Phase 2 additions:
- **Enabler stories** (plan Q6:A): backend and infrastructure capabilities that the exit criteria depend on (S-11 to S-14).
- **Security review stories** (plan Q5:A): SR-01 to SR-03 record the AGENTS.md pre-approval gates. Each blocks its implementation stories in the same way prototypes block UI.
- **Failure paths inside each story** (plan Q7:A): a story is done only when its error, edge-case and security criteria pass.
- **New persona scenario S3.6** (plan Q2:A): drafted in `phase2-personas.md`, applied to `docs/01-user-personas.md` at Documentation Refinement.

Story IDs continue from Phase 1. FR references are to `aidlc-docs/inception/requirements/phase2-requirements.md`. FR-10 (existing OBS output) has no story: Spike 2.2 covers it, and any gap becomes a scoped follow-up.

Values marked **TBD (Spike 2.x)** are set from spike outcomes before the dependent unit's NFR Design.

---

## Enabler Stories

### S-11: Broadcast Identity Backend
**Feature Area:** Broadcast identity | **FR:** FR-2.1, FR-2.2, FR-2.3, FR-2.5, FR-2.7 | **Package:** zip_supabase, zip_core
**Personas:** Jordan, Sam

> As a broadcaster, I need a permanent broadcast ID tied to my account so that the link I share stays the same across every broadcast. As a viewer, I need to look up that link without an account so that I can tell whether the broadcaster is live.

**Acceptance Criteria:**

```gherkin
Given an authenticated broadcaster with no broadcast ID
When the broadcaster starts their first remote broadcast
Then a broadcast ID is created, drawn from an unambiguous alphabet, not derived from the user's identity
And exactly one registry row exists for that broadcaster

Given an authenticated broadcaster who already has a broadcast ID
When the broadcaster starts any later broadcast
Then the same broadcast ID is reused and no new registry row is created

Given two broadcasters requesting IDs concurrently
When both IDs are generated
Then the database uniqueness constraint guarantees the IDs differ
And a generation collision is retried without surfacing an error to the broadcaster

Given the broadcast ID registry table
When its schema is inspected
Then it has id (UUID), created_at, updated_at, snake_case columns, a plural table name, and RLS enabled

Given an authenticated broadcaster
When they attempt to read or modify another broadcaster's registry row
Then the operation is denied by RLS

Given an anonymous client
When it resolves a valid broadcast ID
Then it receives only the broadcast ID, live status, session name (when live) and signaling channel (when live)
And it receives no account identifier, email, or registry row id

Given an anonymous client
When it resolves a broadcast ID that does not exist
Then it receives a "not found" result indistinguishable in shape and timing class from other not-found results

Given an anonymous client
When it attempts to list, enumerate, insert, update or delete registry rows directly
Then every operation is denied

Given a client issuing broadcast-ID resolutions at a rate above the enumeration limit
When the limit is exceeded
Then further resolutions are rejected with a structured rate-limit error

Given a resolution request with a malformed broadcast ID (wrong length, characters outside the alphabet, oversized input)
When it reaches the resolution path
Then it is rejected by input validation with a structured error, without a database query
```

**Blocked by:** SR-02 (RLS policy approach)
**Dependencies:** S-15 (authenticated user identity), S-13 (live status source for resolution)
**PBT:** PBT-02 broadcast ID format/parse round-trip; PBT-03 alphabet, length and uniqueness invariants

---

### S-12: Coturn STUN/TURN Service
**Feature Area:** Infrastructure | **FR:** FR-4.3, FR-4.4 | **NFR:** NFR-3.1, NFR-3.7, NFR-6.1 | **Package:** infrastructure (zip_supabase local stack), zip_core client config
**Personas:** Jordan, Sam

> As a viewer behind a restrictive network, I need a relay that my connection can fall back to so that I still receive captions. As the project, we need that relay to be self-hosted, to keep no caption content, and to have observable costs.

**Acceptance Criteria:**

```gherkin
Given the local development stack is started
When the Coturn service comes up
Then it provides both STUN and TURN on the configured ports
And the apps' ICE configuration lists only this server (no Google or other third-party STUN)

Given a client needs ICE servers for a session
When it requests TURN credentials
Then it receives short-lived credentials scoped to that use, with an expiry
And no static long-lived TURN secret exists in any client build or repository file

Given expired TURN credentials
When a client attempts a TURN allocation with them
Then the allocation is refused

Given Coturn is relaying a session
When its logs are inspected
Then they contain no payload data (only connection metadata permitted by the approved log configuration)

Given a TURN client
When it requests relaying to a private or internal address range
Then Coturn denies the relay

Given Coturn is running
When relay activity occurs
Then bytes relayed, concurrent allocations, connection duration and relay ratio are observable
And alert thresholds for unexpected usage growth are defined

Given Coturn is unreachable
When a client attempts to connect
Then the failure surfaces to the caller as a specific "relay unavailable" reason, not a crash
```

**Blocked by:** SR-03 (server log configuration approach)
**Dependencies:** Spike 2.3 (deployment, credential mechanism, symmetric NAT validation, load at target scale)

---

### S-13: Realtime Signaling
**Feature Area:** Signaling | **FR:** FR-2.6, FR-3.1 to FR-3.6 | **NFR:** NFR-3.6 | **Package:** zip_core, zip_supabase
**Personas:** Jordan, Sam

> As a broadcaster and as a viewer, I need a trusted channel to negotiate connections and learn about broadcast state so that viewers can find and connect to a live broadcast, and no one can impersonate the broadcaster.

**Acceptance Criteria:**

```gherkin
Given a broadcaster starts a session
When signaling is established
Then the broadcaster publishes live status and the current session_id on status:{broadcast_id}
And SDP and ICE exchange uses signaling:{session_id}

Given a signaling or control message is sent
When it is serialized
Then it is JSON with a type discriminator and a schema version
And deserializing it reproduces the original message exactly

Given an inbound message that is malformed, oversized, of unknown type, or of an unsupported schema version
When the receiver processes it
Then it is dropped, the receiver keeps running, and no message content is logged

Given an anonymous viewer on status:{broadcast_id} or signaling:{session_id}
When the viewer attempts to publish a broadcaster-side control or status message
Then the message is rejected by Realtime authorization

Given a viewer joins
When the join message is sent
Then it contains a viewer identity field that is null in Phase 2

Given viewers join and leave
When presence updates
Then the broadcaster's viewer count reflects presence within the presence sync interval

Given a live broadcast
When any Realtime message on these channels is inspected
Then none carries caption text (Realtime carries signaling, control and presence only)

Given the broadcaster's presence expires without a clean end
When a viewer or resolver checks live status
Then the broadcast reports "not currently broadcasting" within the presence timeout TBD (Spike 2.1)

Given duplicate join, leave or ICE candidate messages
When they are processed
Then the resulting state equals processing each once
```

**Blocked by:** SR-02 (Realtime channel authorization is policy-defined)
**Dependencies:** Spike 2.1 (signaling and presence load at 200 joining viewers)
**PBT:** PBT-02 message round-trips; PBT-04 idempotent duplicate handling; PBT-07/08 adversarial message generators

---

### S-14: WebRTC Transport
**Feature Area:** Transport | **FR:** FR-4.1, FR-4.2, FR-4.5, FR-4.6, FR-4.7 | **NFR:** NFR-3.2, NFR-4.2 | **Package:** zip_core
**Personas:** Jordan, Sam

> As a viewer, I need captions delivered directly from the broadcaster, over the local network when we share one and through the relay when we don't, so that I get them quickly and privately.

**Acceptance Criteria:**

```gherkin
Given a broadcaster and a viewer on the same local network
When the connection is negotiated
Then a direct host-candidate path is selected, without TURN
And the connection type is reported as "P2P direct"

Given a broadcaster and a viewer on different networks where direct P2P succeeds
When the connection is negotiated
Then the connection type is reported as "P2P direct"

Given a viewer behind a restrictive NAT where direct P2P fails
When ICE negotiation completes via Coturn
Then the connection type is reported as "TURN relayed"
And captions flow over the relayed data channel

Given all ICE candidates fail
When negotiation times out
Then the viewer receives a "cannot connect" state with the reason "no network path"
And the broadcaster's other viewers are unaffected

Given the broadcaster has N connected viewers
When one viewer's connection drops
Then only that viewer's peer connection is torn down and the other N-1 continue receiving

Given a data channel is open
When a message is sent
Then it travels only over the DTLS-encrypted data channel

Given the transport abstraction
When a new transport type is added in a later phase
Then the caption bus and rendering pipeline require no changes

Given a peer connection closes for any reason
When cleanup runs
Then all native WebRTC resources for that peer are released (no leak across 1-2 hour sessions)
```

**Dependencies:** S-12 (ICE servers), S-13 (signaling), Spike 2.1 (fan-out capacity; Windows or Linux broadcaster coverage)
**PBT:** PBT-06 peer connection state machine

---

## Feature Stories

### S-15: Broadcaster Authentication
**Feature Area:** Auth | **FR:** FR-1.1 to FR-1.7 | **NFR:** NFR-3.8 | **Package:** zip_core, zip_broadcast
**Personas:** Jordan (Alex regression)

> As a broadcaster, I want to sign in so that I get a permanent broadcast link. I still want to caption locally without an account.

**Acceptance Criteria:**

```gherkin
Given Zip Broadcast on macOS, Windows, Linux or web
When the broadcaster chooses to sign in with an enabled provider
Then the OAuth flow completes and the broadcaster is signed in

Given a signed-in broadcaster
When the app restarts
Then the session is restored without signing in again, and tokens are refreshed automatically before expiry

Given a signed-in broadcaster
When they sign out
Then the session and tokens are cleared, and remote broadcasting is no longer available

Given a signed-out user
When they start a remote broadcast
Then they are prompted to sign in, and after signing in they return to broadcast setup with their configuration intact

Given a signed-out user
When they use local captioning, transcripts, OBS output, browser-source output or external-display output
Then every one of these works without an account (as in Phase 1)

Given the OAuth flow is cancelled, denied or fails (network error, provider error)
When control returns to the app
Then the user sees a specific, non-technical message, remains signed out, and can retry

Given a refresh token is revoked or expired
When the app attempts a refresh
Then the user is signed out gracefully and prompted to sign in again only when needed

Given any auth operation
When logs are inspected
Then no tokens, authorization codes or credentials appear

Given the provider configuration
When a new provider is added
Then no application code changes are needed (configuration only)
```

**Blocked by:** SR-01 (OAuth approach, including the choice of providers), Proto-10
**Out of scope (Phase 3):** remaining providers, account merging, deletion, profile, viewer sign-in UI

---

### S-16: Remote Broadcast Output Target
**Feature Area:** Output targets | **FR:** FR-5.1 to FR-5.4 | **NFR:** NFR-1.1, NFR-1.2 | **Package:** zip_core
**Personas:** Jordan, Sam

> As a broadcaster, I want my captions to go to remote viewers as another output alongside OBS and my screen. As a viewer, I want them to look like captions I produce myself.

**Acceptance Criteria:**

```gherkin
Given a live broadcast with connected viewers
When the caption bus emits an SttResult
Then every connected viewer receives it over its data channel, in emission order

Given the remote broadcast target is registered on the caption bus
When existing targets (on-screen, transcript, OBS, browser source, overlay) run alongside it
Then no existing target required code changes and all continue to behave as in Phase 1

Given a caption message
When it is serialized to the wire format
Then it is versioned JSON carrying the ADR-005 SttResult fields
And deserializing it reproduces an equal SttResult

Given a viewer receives a caption message
When it is decoded
Then the SttResult is published into the viewer's caption bus and rendered by the Phase 1 pipeline

Given a viewer joins mid-session
When captions are emitted
Then the viewer receives captions from its join point onward and no earlier captions

Given a wire message with an unsupported version or invalid fields
When the viewer decodes it
Then it is dropped without crashing and without logging its content

Given the broadcaster's captioning state changes (started, paused, resumed, stopped)
When the change is emitted on the bus
Then every connected viewer receives the corresponding caption activity (active, paused, inactive)

Given a viewer joins while captioning is paused or not started
When its data channel opens
Then it immediately receives the current caption activity, without waiting for the next change

Given a viewer's data channel is congested or closed
When captions are emitted
Then sending to other viewers is not blocked or delayed

Given normal network conditions over P2P or TURN
When a caption is shown on the broadcaster's display
Then it appears on a remote viewer within 1 second (target validated by Spike 2.1 and Spike 2.3)
```

**Dependencies:** S-14 (transport)
**PBT:** PBT-02 wire-format round-trip; PBT-03 every connected viewer receives every caption, in order, after its join point

---

### S-17: Broadcast Session Management
**Feature Area:** Broadcast UI | **FR:** FR-6.1 to FR-6.6 | **NFR:** NFR-1.4, NFR-4.3 | **Package:** zip_broadcast
**Personas:** Jordan

> As a broadcaster, I want to set up, start, monitor and end a broadcast from Zip Broadcast so that I can share live captions with a link and see that people are receiving them.

**Acceptance Criteria:**

```gherkin
Given a signed-in broadcaster on the broadcast setup screen
When they enter a session name and choose output targets
Then the configuration is accepted and there is no relay option

Given a valid configuration
When the broadcaster starts the broadcast
Then the broadcast ID is obtained or created, a new session_id is created, live status is published
And the stable URL zipcaptions.app/b/{broadcast_id} is displayed with a copy-to-clipboard action

Given a live broadcast
When the broadcaster views the dashboard
Then it shows viewer count against the cap, connection type per viewer, a caption preview and the audio level

Given a live broadcast
When the broadcaster ends it
Then all viewers are notified "broadcast ended", all peer connections close, presence and live status are cleared, and resources are released

Given the broadcaster ends a broadcast
When they start a new one
Then the same broadcast ID and URL are used with a new session_id

Given "start captioning when going live" is off (the default) and captioning is not running
When the broadcaster goes live
Then the broadcast is live, captioning stays stopped, and a large "captions inactive" notice is shown on the dashboard

Given "start captioning when going live" is on and captioning is not running
When the broadcaster goes live
Then captioning starts as part of going live

Given a live broadcast with captioning running
When the broadcaster pauses or stops captioning
Then the broadcast stays live, viewers stay connected, and the "captions inactive" notice appears until captioning resumes

Given a live broadcast with captioning running
When the broadcaster ends the broadcast
Then local captioning continues unaffected

Given the broadcaster's app crashes or loses network without ending the broadcast
When the presence timeout elapses TBD (Spike 2.1)
Then viewers see "reconnecting" and then "not currently broadcasting", and no stale live status remains

Given a session name that is empty, too long, or contains control characters
When the broadcaster tries to start
Then validation rejects it with a specific message

Given starting fails (signaling unavailable, Coturn unreachable, auth expired)
When the error occurs
Then the broadcaster sees the specific reason, local captioning continues unaffected, and they can retry

Given a 1-2 hour broadcast at capacity
When it runs to completion
Then memory and connection counts remain stable (no growth from viewer churn)
```

**Blocked by:** Proto-11, Proto-12
**Dependencies:** S-11, S-13, S-15, S-16, S-18
**PBT:** PBT-06 broadcaster session state machine; PBT-04 end-broadcast idempotency

---

### S-18: Viewer Capacity
**Feature Area:** Capacity | **FR:** FR-8.1 to FR-8.3 | **NFR:** NFR-2.1 | **Package:** zip_core, zip_broadcast
**Personas:** Jordan, Sam

> As a broadcaster, I want the number of viewers capped at what my machine can serve so that the viewers already watching keep receiving captions reliably. As a viewer, I want to be told clearly when a broadcast is full.

**Acceptance Criteria:**

```gherkin
Given a broadcast with a viewer cap TBD (Spike 2.1, target 100-200)
When the number of connected viewers equals the cap
Then a new join attempt is refused and that viewer sees "broadcast is full"

Given a full broadcast
When a connected viewer leaves
Then a subsequent join attempt succeeds

Given join attempts arrive concurrently near the cap
When they are admitted
Then the connected-viewer count never exceeds the cap

Given a live broadcast
When the broadcaster views the dashboard
Then the current viewer count and the cap are both shown

Given a viewer that was refused as full
When it retries later and capacity is available
Then it joins normally
```

**Dependencies:** S-13 (presence), S-14, Spike 2.1 (cap value)
**PBT:** PBT-03 viewer count never exceeds the cap under arbitrary join/leave interleavings

---

### S-19: Broadcast Viewer
**Feature Area:** Viewer UI | **FR:** FR-7.1 to FR-7.6 | **NFR:** NFR-4.1, NFR-5.1, NFR-5.2 | **Package:** zip_captions
**Personas:** Sam

> As a viewer, I want to open a broadcaster's link, or type their broadcast ID, and read live captions in my own display settings, without an account, so that I can follow along wherever I am.

**Acceptance Criteria:**

```gherkin
Given the Zip Captions join screen
When the viewer enters a broadcast ID or pastes a zipcaptions.app/b/{id} URL
Then both forms are parsed to the same broadcast ID and the viewer starts connecting

Given input that is neither a valid broadcast ID nor a valid broadcast URL
When the viewer submits it
Then a specific validation message is shown and no network request is made

Given Zip Captions web
When the browser opens /b/{broadcast_id}
Then the viewer opens directly for that broadcast

Given a live broadcast
When the viewer connects
Then captions appear using the viewer's own text size, font, contrast and flow direction

Given a live broadcast whose captioning is paused or not started
When the viewer is connected
Then a message says captions are currently paused by the broadcaster, and it clears when captions resume

Given each of the states connecting, live, live with captions paused, reconnecting, not currently broadcasting, broadcast ended, broadcast full, cannot connect
When the viewer is in that state
Then a distinct, clearly worded status is shown, not conveyed by color alone, and announced to screen readers
And "cannot connect" states its specific reason

Given a connected viewer experiences a temporary network loss or network change
When connectivity returns within the reconnection window TBD (Spike 2.1)
Then the viewer rejoins the same broadcast automatically without user action

Given the broadcaster ends the broadcast
When the viewer receives the end notification
Then the viewer shows "broadcast ended" and releases the connection

Given the broadcast is not live
When the viewer opens its URL
Then "not currently broadcasting" is shown with no error

Given any viewer flow
When it runs
Then no sign-in is requested and no account is required

Given the Zip Captions web viewer route
When its responses are inspected
Then the required HTTP security headers are present (SECURITY-04)

Given any transport, signaling or resolution failure
When it occurs
Then the app does not crash and shows the corresponding state
```

**Blocked by:** Proto-14, Proto-15
**Dependencies:** S-11 (resolution), S-13, S-14, S-16
**PBT:** PBT-02 URL/ID parse round-trip; PBT-06 viewer connection and reconnection state machine

---

### S-20: External Display Output
**Feature Area:** Output targets | **FR:** FR-9.1 to FR-9.5 | **NFR:** NFR-5.1 | **Package:** zip_broadcast
**Personas:** Jordan

> As a broadcaster in a classroom or auditorium, I want captions on a second monitor or projector so that the people in the room can read them.

**Brownfield note:** Phase 1 shipped `CaptionOverlayTarget` (`packages/zip_broadcast/lib/src/output/overlay/`) with an injectable `DesktopWindowService`, `OverlayConfig.targetDisplayId`, and the `desktop_multi_window` dependency. It is registered on the caption bus through the `overlayEnabled` setting, but nothing calls `show()`, `main.dart` has no secondary-window entry point that renders captions, and connected displays cannot be listed. This story completes that target rather than creating a new one. A display-enumeration capability may need a new dependency, which requires approval (FR-9.5).

**Acceptance Criteria:**

```gherkin
Given Zip Broadcast on macOS, Windows or Linux with more than one display connected
When the broadcaster opens the external display controls
Then all connected displays are listed and one can be selected

Given a selected display
When the broadcaster enables external display output
Then a borderless caption window opens on that display and shows live captions using the broadcaster's display settings

Given external display output is enabled
When the user is signed out
Then it works unchanged (no account required)

Given the external display window is open
When the broadcaster disables the output
Then the window closes and its resources are released

Given the external display window is open
When the selected display is disconnected
Then the output falls back gracefully (without crashing and without leaving an orphaned window) and the broadcaster is notified

Given Zip Broadcast web
When the broadcaster views output targets
Then external display output is not offered

Given the caption window
When caption text is rendered
Then contrast meets WCAG AAA (7:1)
```

**Blocked by:** Proto-13
**Dependencies:** none from Phase 2 (caption bus from Phase 1)

---

### S-21: Pop-out Live Captions (PiP)
**Feature Area:** Output targets | **FR:** none new — v1 parity, carried by the Phase 6 Definition of Done (`docs/03-roadmap.md:464`) | **NFR:** NFR-5.1 | **Packages:** zip_core, zip_broadcast, zip_captions
**Personas:** Jordan, Alex

> As a person captioning speech, I want to pop the live captions out into a small window that floats on top of every other application, so that I can keep reading captions while I work in another program and bring them back when I am done.

**Brownfield note:** Authored 2026-10-20 (PR #37 review decision D-1). This is v1 feature parity, not new functionality: Zip Captions v1 shipped Picture-in-Picture in v0.5.0-rc.5, and the Phase 6 Definition of Done makes PiP UX parity a v2.0 release gate. The unit was split out of Unit 8 (External Display, S-20) because Unit 8 is scoped to a different surface (a caption window on a selected display) and the two would have shipped half-built together. **Story ID S-21 is new; it does not add an FR.** Its behaviour contract already exists as `aidlc-docs/construction/output-targets/functional-design/pip-ux-parity.md` §8, which is binding and untouched by Unit 8; the V1 behaviour analysis lives in `aidlc-docs/v1-parity/picture-in-picture-v1-analysis.md`.

**Applies to both apps (2026-10-20).** V1 was one web app that both broadcast and self-captioned; v2 splits that in two, and both need the pop-out. Zip Broadcast: read captions while running OBS or slides. Zip Captions: it is a self-contained caption engine, so a user captioning themselves has the same need. The contract in §8 applies identically to both; the unit delivers it in both, and its acceptance criteria are evidenced **per app**.

**Architecture (option A, approved 2026-10-20).** Unit 8's window machinery lives in `zip_broadcast` today and `zip_captions` has no windowing at all (no `desktop_multi_window`, no sub-engine entry). Rather than duplicate the state machine or make one app depend on the other, the machinery is promoted to `zip_core` and both apps consume it; each app adds only its toggle wiring and sub-engine entry point. The promotion is a refactor of shipped Unit 8 code and must leave the external display behaving exactly as it does today.

**Platform scope:** desktop only in Phase 2 (macOS, Windows, Linux). Web Document Picture-in-Picture is deferred to Phase 5 with the rest of the web scaffold, matching the deferral Unit 7 (S-19) already made for the web viewer route.

**Acceptance Criteria:**

```gherkin
Given Zip Broadcast on macOS, Windows or Linux with live captions running
When the broadcaster toggles the pop-out control in the app chrome
Then a small pop-out window opens showing the live captions and its control reads "Exit Picture in Picture"

Given Zip Captions on macOS, Windows or Linux with live captions running
When the user toggles the pop-out control in the app chrome
Then a small pop-out window opens showing the live captions and its control reads "Exit Picture in Picture"

Given the pop-out window is open in either app
When the user activates any other application
Then the pop-out window remains above that application's window and keeps updating

Given the pop-out window is open in either app
When the user uses the in-surface toggle inside the pop-out window itself
Then the captions return to the main window and the pop-out window closes

Given the pop-out window is open in either app
When the user closes it with the OS close button
Then the main window returns to a coherent state and the caption controls still work

Given the pop-out window is open in either app
When the theme, layout settings or text appearance change
Then the pop-out window reflects the change live without being reopened

Given an active pop-out window in either app
When the user toggles pop-out a second time
Then no second pop-out window is created

Given Zip Broadcast after the machinery is promoted to zip_core
When the broadcaster uses external display output
Then it behaves exactly as it did before the move (no regression in Unit 8's shipped behaviour)

Given Zip Broadcast web or Zip Captions web
When the user views the caption surface
Then the pop-out control is not offered (web PiP is deferred to Phase 5)

Given any pop-out path
When the application logs
Then no caption text appears in the logs
```

**Deferred:** §8.8 items 8-10 (content setting, live content-setting update, orientation/pane swap/translation controls inside the pop-out) depend on translation, which is Phase 8. They are recorded as deferred with that reason, not claimed as delivered.

**Known limitation (accepted 2026-10-20):** on macOS the window floats above all normal application windows but not above another application's full-screen window; lifting that restriction requires an `NSPanel`-derived window class and is recorded in the Backlog rather than claimed here.

**Blocked by:** Proto-15 (the caption-surface toggle is prototyped there; §8.3 defines the apparent conflict with S-19's surface)
**Dependencies:** S-20 (reuses its window machinery, codec and sub-engine entry); caption bus from Phase 1

---

### S-22: Mobile Captioning Alpha
**Feature Area:** Mobile platform readiness | **FR:** none new. It verifies Phase 1 FR-6.1 and FR-6.3 on mobile | **NFR:** Phase 1 NFR-1.1 | **Packages:** zip_captions (`ios/`, `android/`, release configuration), CI
**Personas:** Alex

> As a Zip Captions user on iPhone or Android, I can start captioning, speak, and see live captions, with the screen kept on, then save and share the transcript.

**Brownfield note:** Added 2026-10-24 from the mobile alpha plan, which James Petersen approved on 2026-10-22. Units 10 and 11 deliver it (`phase2-unit-of-work.md`, "Mobile Alpha Units"). **Story ID S-22 is new; it adds no FR.** The behaviour was specified in Phase 1, but Phase 1's mobile exit criterion was never verified on a device (gap G1). The configuration also suggests that microphone permission fails on both platforms (G2, G3). **G10 (2026-10-24):** neither app registers a real speech recogniser, only a debug-only fake, so no phone can caption real speech until Unit 10 registers one. The Phase 1 records are not reopened, and the evidence is recorded in Units 10 and 11.

**Acceptance Criteria:**

```gherkin
Given Zip Captions freshly installed on a physical iPhone or Android phone, with no permission granted
When the user starts captioning
Then the operating system asks for microphone access (and, on iOS, speech recognition)
And once access is granted, captioning starts

Given microphone access was denied
When the user starts captioning
Then the app shows its permission-denied state with a way to open the system settings, and does not crash

Given captioning is running on a physical device
When the user speaks
Then live captions appear with less than 1 second of perceived latency (Phase 1 NFR-1.1)

Given captioning is running
When the device's screen timeout elapses with no interaction
Then the screen stays on until captioning stops, after which the normal timeout applies again

Given a finished session on a device with a PIN or biometrics
When the user saves and shares the transcript
Then the transcript is saved and the platform share sheet opens

Given a device with no PIN and no biometrics
When the user tries to save a transcript
Then saving is refused, as on every other platform

Given a signed release build installed from TestFlight internal testing or Play Internal Testing
When an internal tester completes a captioning session
Then every criterion above holds on that build (the Alpha 1 gate)

Given the installed app
When the user looks at the home screen and the system settings
Then it shows the app identity decided at Unit 10's NFR Requirements, not the scaffold label `zip_captions`

Given any captioning path on mobile
When the application logs
Then no transcript content appears in the logs
```

**Verification:** each criterion needs both a recorded emulator QA pass and a physical-device pass (`phase2-unit-of-work.md`, "Virtual-device development and QA"). Latency, wake lock, recognizer availability and the signed install can only be proved on a physical device.

**Open question:** OQ-MA-1 (whether iOS Simulator speech-recognition consent can be pre-granted) must be answered before Unit 10's NFR Requirements is approved.

**Dependencies:** Phase 1 captioning; Unit 8.1 merged (one branch at a time). Independent of the broadcast chain.

---

### S-23: Mobile Broadcast Viewer Alpha
**Feature Area:** Viewer (mobile) | **FR:** FR-7 (verified on mobile) | **NFR:** NFR-1.3, NFR-8.2 | **Packages:** zip_captions (Android manifest, `integration_test` harness), zip_supabase (staging, via Unit 12), CI
**Personas:** Sam

> As a viewer on iPhone or Android, I can join a live broadcast and keep receiving captions across a network change.

**Brownfield note:** Added 2026-10-24 from the mobile alpha plan, which James Petersen approved on 2026-10-22. Unit 13 delivers it, after Unit 9 and Unit 12 (`phase2-unit-of-work.md`, "Mobile Alpha Units"). **Story ID S-23 is new; it adds no FR.** NFR-8.2 names iOS and Android as viewer platforms, but no unit verifies a phone viewer (G6). The Android release build cannot reach the network (G4). No automated mobile E2E exists (G7). S-19 is not reopened.

**Acceptance Criteria:**

```gherkin
Given a test-track build on iPhone or Android and a live Zip Broadcast desktop session on the staging backend
When the viewer enters the broadcast ID on the join screen
Then live captions appear

Given an Android release build (not debug or profile)
When it joins a broadcast
Then it reaches the staging backend and connects

Given the phone and the broadcaster are on the same network
When the viewer joins
Then the connection is peer-to-peer

Given peer-to-peer connection fails
When the viewer joins
Then captions arrive over the TURN relay

Given a phone viewing a live broadcast on Wi-Fi
When the phone switches from Wi-Fi to cellular
Then it reconnects automatically and captions resume

Given a broadcast at its viewer cap
When a phone tries to join
Then it shows the "broadcast is full" message

Given the mobile smoke harness
When it runs on the iOS Simulator and the Android emulator
Then the join, receive and reconnect flows pass, in a form CI can run

Given an internal tester on each platform with the test-track build
When they view a live session
Then the criteria above hold (the Alpha 2 gate)

Given any viewer path on mobile
When the application logs
Then no caption text appears in the logs
```

**Verification:** the emulator flows run first, against the local stack and then against staging. The real Wi-Fi to cellular switch is a physical-device check only.

**Blocked by:** SR-05 (through Unit 12)
**Dependencies:** S-19 (viewer); S-22 (the test-track build from Unit 11); the staging backend (Unit 12); Unit 9 (the desktop broadcast path is verified first)

---

## Security Review Stories

Each review produces an approach document in the relevant unit's design folder and needs explicit human approval. The listed implementation stories cannot start Code Generation until their review is approved.

### SR-01: OAuth Flow Approach Review
**Area:** Authentication (AGENTS.md: OAuth flows) | **FR:** FR-1.2, FR-1.7 | **Blocks:** S-15

```gherkin
Given the proposed OAuth approach document
When it is reviewed
Then it specifies the Phase 2 providers, the flow type per platform (macOS, Windows, Linux, web), redirect handling, token storage, refresh, sign-out, and failure handling
And it shows how providers are added by configuration only
And a human reviewer has recorded approval before implementation begins
```

### SR-02: RLS and Realtime Authorization Policy Review
**Area:** Supabase RLS (AGENTS.md: RLS policy definitions) | **FR:** FR-2.2, FR-2.5, FR-3.3 | **NFR:** NFR-3.4, NFR-3.5 | **Blocks:** S-11, S-13

```gherkin
Given the proposed policy document
When it is reviewed
Then it defines RLS for the broadcast ID registry, the anonymous resolution path and what it exposes, the enumeration controls, and Realtime channel authorization (who may publish what on status and signaling channels)
And a human reviewer has recorded approval before implementation begins
```

### SR-03: Server-Side Log Configuration Review
**Area:** Server log configuration (AGENTS.md) | **NFR:** NFR-3.1, NFR-6.1 | **Blocks:** S-12

```gherkin
Given the proposed log configuration for Coturn and the Supabase Realtime service
When it is reviewed
Then it demonstrates that no payload data is logged, lists which connection metadata is retained and for how long, and states how usage metrics are collected without caption content
And a human reviewer has recorded approval before implementation begins
```

### SR-05: Staging Backend Exposure Review
**Area:** Publicly exposed server configuration (AGENTS.md: server-side log configuration, RLS policy definitions) | **NFR:** NFR-3.1, NFR-6.1 | **Blocks:** Unit 12 Code Generation, and so S-23

Added 2026-10-24 with the mobile alpha. It follows the SR-03 pattern and is produced at Unit 12's Infrastructure Design.

```gherkin
Given the proposed staging deployment of Supabase and coturn
When it is reviewed
Then it lists which services and ports are exposed to the public, and why
And it states how each secret is stored and kept out of git and out of app builds
And it shows that the payload-free logging approved in SR-03, and the RLS and channel authorization approved in SR-02 and SR-04, hold unchanged on staging
And it states how staging stays separate from Phase 6 production infrastructure, who may reach it, and how it is torn down
And a human reviewer has recorded approval before implementation begins
```

---

## UI Design Prototype Stories

Each prototype is a standalone HTML/CSS file demonstrating the screen in light and dark themes with responsive layout, placed in `aidlc-docs/construction/{unit-name}/prototypes/`. Approval is required before the blocked implementation story begins.

### Proto-10: Zip Broadcast — Sign-In
**Screen:** Sign-in prompt and signed-in account state | **App:** zip_broadcast
**Blocks:** S-15

```gherkin
Given the prototype HTML file is opened in a browser
When the sign-in design is displayed
Then provider sign-in buttons, the signed-in state with sign-out, and an auth-failure message are shown
And the copy makes clear that sign-in is needed only for remote broadcasting
And the design works at desktop and web widths in both themes
```

### Proto-11: Zip Broadcast — Broadcast Setup
**Screen:** Create/configure broadcast | **App:** zip_broadcast
**Blocks:** S-17

```gherkin
Given the prototype HTML file is opened in a browser
When the broadcast setup design is displayed
Then session name entry with a validation error, output target selection, the "start captioning when going live" option (off by default), the stable URL with copy action, and the signed-out prompt state are shown
And no relay option appears
```

### Proto-12: Zip Broadcast — Live Broadcast Dashboard
**Screen:** Live dashboard | **App:** zip_broadcast
**Blocks:** S-17

```gherkin
Given the prototype HTML file is opened in a browser
When the dashboard design is displayed
Then viewer count against cap, per-viewer connection type (P2P direct, TURN relayed, connecting, disconnected), caption preview, audio level and an end-broadcast control are shown
And a "broadcast full" state and a start-failure state are shown
And a large, prominent "captions inactive" notice is shown for a live broadcast with captioning not running
```

### Proto-13: Zip Broadcast — External Display Controls
**Screen:** External display selection and status | **App:** zip_broadcast (desktop)
**Blocks:** S-20

```gherkin
Given the prototype HTML file is opened in a browser
When the external display controls are displayed
Then the display list, enable/disable control, the active state and the display-disconnected notice are shown
And a mock of the borderless caption window is shown at projector scale
```

### Proto-14: Zip Captions — Join Broadcast
**Screen:** Join screen | **App:** zip_captions
**Blocks:** S-19

```gherkin
Given the prototype HTML file is opened in a browser
When the join screen design is displayed
Then ID/URL entry, an invalid-input message and the connecting state are shown
And the design works at mobile and desktop widths in both themes
```

### Proto-15: Zip Captions — Live Viewer States
**Screen:** Live caption viewer | **App:** zip_captions
**Blocks:** S-19

```gherkin
Given the prototype HTML file is opened in a browser
When the viewer design is displayed
Then all eight states (connecting, live, live with captions paused by the broadcaster, reconnecting, not currently broadcasting, broadcast ended, broadcast full, cannot connect with reason) can be switched between
And each state is distinguishable without color
And live captions use the Phase 1 caption rendering style
```

---

## Scenario Integration Milestones

### M-S2.2: Jordan — Classroom (completed)
**Persona:** Jordan, Sam | **Scenario:** S2.2
**Composed from:** S-11 to S-20
**Note:** Phase 1 delivered the local parts of this milestone. Phase 2 adds the second-monitor display and remote students.

```gherkin
Given Jordan is signed in to Zip Broadcast on a desktop in a classroom with a second monitor
When Jordan enables external display output on the second monitor and starts a broadcast
Then in-room students read captions on the second monitor
And Jordan shares the stable URL with remote students

Given remote students open the URL on their own phones, laptops or browsers
When they join
Then each sees live captions in their own display settings without an account
And Jordan's dashboard shows each student's connection type

Given a remote student's connection briefly drops
When their network returns
Then they rejoin automatically, and other students and the second monitor are unaffected

Given the class ends
When Jordan ends the broadcast
Then remote students see "broadcast ended" and the second-monitor window closes when captioning stops
```

### M-S2.3: Jordan — Auditorium (Phase 2 slice)
**Persona:** Jordan, Sam | **Scenario:** S2.3 (partial: profiles, line-in, projection formatting and bilingual display are out of Phase 2 scope)
**Composed from:** S-11 to S-20

```gherkin
Given Jordan runs Zip Broadcast at an event with a projector as a second display
When Jordan enables external display output on the projector and starts a broadcast
Then the audience reads captions on the projector
And audience members who open the shared URL read captions on their own devices

Given the audience grows to the viewer cap
When one more person tries to join
Then they see "broadcast is full", and the connected viewers and the projector are unaffected

Given some audience members are on restrictive networks
When they join
Then their connections are relayed through TURN and shown as "TURN relayed" on the dashboard

Given the event runs for two hours at capacity
When it ends
Then the broadcaster's local captioning latency and resource use stayed within Phase 1 targets throughout
```

### M-S3.6: Sam — Joining a Remote Broadcast by Link
**Persona:** Sam | **Scenario:** S3.6 (new, see `phase2-personas.md`)
**Composed from:** S-11, S-13, S-14, S-16, S-19

```gherkin
Given Sam receives a zipcaptions.app/b/{id} link
When Sam opens it in a browser, or pastes it into Zip Captions on a phone
Then live captions appear without Sam creating an account or signing in
And they use Sam's own text size, font, contrast and flow direction

Given Sam's phone switches from Wi-Fi to cellular mid-session
When the network changes
Then Sam's viewer shows "reconnecting" and resumes captions automatically

Given Sam opens the link before the broadcaster has started
When the page loads
Then Sam sees "not currently broadcasting"
```

### M-REG-01: Phase 2 Regression — Signed-Out Local Features
**Persona:** Alex, Jordan | **Exit criteria:** 8, 9
**Composed from:** Phase 1 S-04, S-05, S-07, S-08; Phase 2 S-15, S-20

```gherkin
Given a user who has never signed in
When they caption locally in Zip Captions or Zip Broadcast
Then captioning, transcripts and display settings behave exactly as in Phase 1

Given a signed-out Zip Broadcast user
When they enable OBS output, browser source output or external display output
Then each works without an account
And the browser source still serves the caption overlay page
```

---

## Traceability Matrix

| Story | FR | NFR | Personas | Milestones | Exit criteria |
|---|---|---|---|---|---|
| S-11 | FR-2 | NFR-3.4, 3.5 | Jordan, Sam | M-S2.2, M-S2.3, M-S3.6 | 1 |
| S-12 | FR-4.3, 4.4 | NFR-3.1, 3.7, 6.1 | Jordan, Sam | M-S2.2, M-S2.3 | 3 |
| S-13 | FR-2.6, FR-3 | NFR-3.6 | Jordan, Sam | M-S2.2, M-S2.3, M-S3.6 | 1 |
| S-14 | FR-4 | NFR-3.2, 4.2 | Jordan, Sam | M-S2.2, M-S2.3, M-S3.6 | 1, 2, 3 |
| S-15 | FR-1 | NFR-3.8 | Jordan (Alex regression) | M-S2.2, M-S2.3, M-REG-01 | 1, 9 |
| S-16 | FR-5 | NFR-1.1, 1.2 | Jordan, Sam | M-S2.2, M-S2.3, M-S3.6 | 1 |
| S-17 | FR-6 | NFR-1.4, 4.3 | Jordan | M-S2.2, M-S2.3 | 1 |
| S-18 | FR-8 | NFR-2.1 | Jordan, Sam | M-S2.3 | 5 |
| S-19 | FR-7 | NFR-4.1, 5.1, 5.2 | Sam | M-S2.2, M-S2.3, M-S3.6 | 1, 4 |
| S-20 | FR-9 | NFR-5.1 | Jordan | M-S2.2, M-S2.3, M-REG-01 | 6, 9 |
| S-21 | (none new — Phase 6 DoD PiP parity) | NFR-5.1 | Jordan, Alex | M-S2.2, M-S2.3 | — (v2.0 RC gate) |
| S-22 | (none new — verifies Phase 1 FR-6.1, 6.3 on mobile) | Phase 1 NFR-1.1 | Alex | — (Alpha 1 gate) | Phase 1 criterion 1; 9 on mobile |
| S-23 | FR-7 (on mobile) | NFR-1.3, 8.2 | Sam | — (Alpha 2 gate) | 1, 2, 3, 4, 5 on a phone |
| SR-01 | FR-1.7 | NFR-3.8 | — | Blocks S-15 | — |
| SR-02 | FR-2, FR-3.3 | NFR-3.4, 3.5 | — | Blocks S-11, S-13 | — |
| SR-03 | — | NFR-3.1, 6.1 | — | Blocks S-12 | — |
| SR-05 | — | NFR-3.1, 6.1 | — | Blocks S-23 (via Unit 12) | — |
| Proto-10..13 | FR-1, 6, 9 | — | Jordan | Block S-15, S-17, S-20 | — |
| Proto-14..15 | FR-7 | NFR-5.2 | Sam | Block S-19 | — |
| (Spike 2.2) | FR-10 | — | Jordan | — | 7 |

Every FR from FR-1 to FR-10 and every exit criterion from 1 to 9 maps to at least one story, spike or milestone.

---

## Story Dependencies and Sequencing

```
Spike 2.3 ──► S-12 (Coturn)          SR-03 ──► S-12
Spike 2.1 ──► S-13, S-14, S-18 (TBD values: cap, timeouts)
Spike 2.2 ──► FR-10 confirmation (no story)

SR-01 + Proto-10 ──► S-15 (Auth)
SR-02 ──► S-11 (Identity backend), S-13 (Signaling)

S-15 ──► S-11
S-13 ──► S-11 (live status for resolution)
S-12 + S-13 ──► S-14 (WebRTC)
S-14 ──► S-16 (Remote output target)
S-13 + S-14 ──► S-18 (Capacity)
S-11 + S-13 + S-15 + S-16 + S-18 + Proto-11 + Proto-12 ──► S-17 (Session mgmt)
S-11 + S-13 + S-14 + S-16 + Proto-14 + Proto-15 ──► S-19 (Viewer)
Proto-13 ──► S-20 (External display; independent of the broadcast chain)
Proto-15 ──► S-21 (Pop-out; reuses S-20's window machinery)

S-17 + S-19 + S-20 ──► M-S2.2, M-S2.3
S-21 ──► M-S2.2, M-S2.3 (PiP parity)
S-19 ──► M-S3.6
S-15 + S-20 ──► M-REG-01

S-22 (Units 10, 11; independent of the broadcast chain) ══► ALPHA 1
S-19 + S-22 + SR-05 ──► S-23 (Unit 13, after Units 9 and 12) ══► ALPHA 2
```

S-20 and its prototype do not depend on the broadcast chain, so they can run in parallel with it from the start of Construction. S-21 is sequenced after S-20 because it reuses S-20's window machinery.

---

## INVEST Compliance

| Criterion | Assessment |
|---|---|
| **Independent** | Feature stories have explicit dependencies, and each can be built and tested against fakes of the stories it depends on (NFR-7.3). S-20 is fully independent of the broadcast chain. Review and prototype stories are independent of each other. |
| **Negotiable** | Criteria define observable behaviour. Mechanisms (resolution RPC vs Edge Function, credential issuance, display enumeration) are left to Functional and Infrastructure Design. |
| **Valuable** | Feature stories deliver user-visible value. Enablers are named for the user outcome they unlock. Security reviews carry the AGENTS.md compliance value. |
| **Estimable** | Scope is bounded by FR groups. The main estimation risk (fan-out, TURN, desktop `flutter_webrtc`) is isolated in the spikes. |
| **Small** | Coarse granularity per Phase 1 convention; each story maps to one design-implement-test cycle. S-19 and S-17 are the largest and the natural split points if a unit grows too large. |
| **Testable** | All criteria are Given/When/Then, including failure and security paths. Values that depend on spikes are marked TBD with the spike that sets them. |
