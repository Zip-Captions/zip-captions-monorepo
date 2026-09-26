# Phase 2 Requirements — Broadcasting & Transport

## Intent Analysis

- **User Request**: Plan Phase 2 (Broadcasting & Transport) per `docs/03-roadmap.md`: restore v1 live broadcast (broadcaster to remote viewers), replacing Socket.IO + PeerJS with Supabase Realtime signaling + WebRTC data channels, self-hosted Coturn, and stable broadcast URLs
- **Request Type**: New Feature (multiple components, multi-platform, new backend surface)
- **Scope**: System-wide — zip_core (auth, signaling, WebRTC transport, broadcast output target), zip_broadcast (auth UI, broadcast UI, external display), zip_captions (viewer UI, web route), zip_supabase (migration, RLS, Realtime authorization, possibly Edge Functions), infrastructure (Coturn)
- **Complexity**: Complex — networking and NAT traversal, a pulled-forward authentication slice, a public broadcast surface, broadcaster fan-out to 100-200 peers, and cross-phase dependencies on Phases 3, 4 and 5
- **Requirements Depth**: Comprehensive
- **Sources**: `phase2-requirement-verification-questions.md` (12 answers), `phase2-clarification-questions.md` (8 answers), ADR-006, ADR-007, ADR-008, ADR-011, `docs/01-user-personas.md` (Jordan S2.1-S2.3, Sam S3.x), `docs/04-technical-specification.md` Sections 6 and 9

---

## Scope Decisions

| Topic | Decision | Source |
|---|---|---|
| Research spikes | Run 2.1, 2.2, 2.3 as early Phase 2 Construction units; spike-dependent values recorded as TBD | Q1:A |
| Broadcaster identity | Minimal authentication pulled forward from Phase 3; broadcaster must sign in to broadcast remotely | Q2:B, CQ3:A |
| Auth mechanism | Supabase GoTrue with the provider-agnostic OAuth architecture; one or two providers enabled in Phase 2 | CQ2:A |
| Persistence | Hybrid: permanent `broadcast_id` registry in Postgres with RLS; active-session state ephemeral in Realtime presence/channel state | Q9:B, CQ1:A |
| Supabase Realtime relay | Deferred to Phase 3 (after encryption); Phase 2 Realtime carries signaling and presence only, never caption payloads | Q3:C, CQ6:A |
| Transports | WebRTC only (P2P + self-hosted Coturn TURN). Local Wi-Fi WebSocket and BLE GATT deferred to Phase 5 | Q4:B, CQ5:A |
| OBS output | Unchanged; Spike 2.2 confirms the closed-caption API; any gap becomes a scoped follow-up | Q5:A |
| External display | Included, Zip Broadcast desktop only (macOS, Windows, Linux) | Q6:B, CQ8:A |
| Vanity URLs | Deferred entirely to Phase 4 | Q7:A |
| Viewer identity | Viewers are anonymous in practice; join protocol carries an optional, nullable viewer identity; viewer sign-in UI arrives in Phase 3 | Q8:B, CQ4:A |
| Viewer scale | Target 100-200 concurrent viewers per broadcast; enforced cap set from Spike 2.1 measurement | Q10:C, CQ7:A |
| Extensions | Security Baseline and Property-Based Testing fully enforced | Q11:A, Q12:A |

---

## Functional Requirements

### FR-1: Broadcaster Authentication (minimal slice)

**FR-1.1**: Authentication uses Supabase GoTrue via `supabase_flutter` (approved dependency). The auth service abstraction lives in `zip_core` so Zip Captions can reuse it in Phase 3 without changes.

**FR-1.2**: OAuth follows the Phase 3 provider-agnostic architecture: providers are configuration, not code, so Phase 3 adds providers without code changes. Phase 2 enables one or two providers. The specific providers are chosen during the security-critical approach review (FR-1.7).

**FR-1.3**: Sign-in, sign-out, and session persistence with automatic token refresh (JWT + refresh token handled by `supabase_flutter`). Tokens stored per the SDK's secure-storage mechanism; never logged.

**FR-1.4**: Sign-in is required **only** for remote broadcasting (stable URL, WebRTC viewers). Local captioning, transcripts, OBS output, browser-source output and external-display output keep working signed-out, as they do today.

**FR-1.5**: Sign-in UI ships in Zip Broadcast only (macOS, Windows, Linux, web). Starting a remote broadcast while signed-out prompts sign-in and returns the user to broadcast setup afterwards.

**FR-1.6**: Out of scope for Phase 2 (remain in Phase 3): the remaining OAuth providers, cross-provider account merging, account deletion, user profile, and viewer sign-in UI. Phase 3 account deletion must also remove the Phase 2 broadcast registry row.

**FR-1.7**: OAuth flow design (including per-platform redirect handling on desktop and web) is security-critical under AGENTS.md and requires human approval of the approach before implementation.

### FR-2: Stable Broadcast Identity and URL Resolution

**FR-2.1**: Each authenticated broadcaster has one permanent, auto-generated, short broadcast ID (for example `k7m9x2`), created on first remote broadcast and reused across all later sessions (ADR-011).

**FR-2.2**: The `broadcast_id` registry is persisted in Supabase Postgres (one row per broadcaster), following Section 9 conventions (`id`, `created_at`, `updated_at`, snake_case, plural table name) with RLS keyed to `auth.uid()`. The table name is fixed during Functional Design and added to the technical specification at Documentation Refinement.

**FR-2.3**: Broadcast IDs are generated from an unambiguous alphabet, are unique (enforced by a database constraint), and are not derived from user identity.

**FR-2.4**: Stable URL format `zipcaptions.app/b/{broadcast_id}` (ADR-011, a stable contract).

**FR-2.5**: Anonymous viewers can resolve a broadcast ID to its live status (live or not, and the current session's signaling channel) without learning anything about the broadcaster's account beyond the broadcast ID and session name. The mechanism (restricted RPC or view, or an Edge Function) is decided in Functional Design.

**FR-2.6**: Active-session state is ephemeral. The broadcaster publishes live status and the rotating `session_id` through Realtime presence/channel state on `status:{broadcast_id}`. There are no session records in Postgres in Phase 2.

**FR-2.7**: When the broadcaster is not live, resolution returns a "not currently broadcasting" state.

### FR-3: Signaling via Supabase Realtime

**FR-3.1**: WebRTC signaling (SDP offer/answer, ICE candidates) and session control messages (join, leave, broadcast ended, broadcast full) are exchanged over Realtime channels named per Section 9: `signaling:{session_id}` and `status:{broadcast_id}`.

**FR-3.2**: Payloads are JSON with a `type` discriminator field (Section 9). Every inbound message is schema-validated; malformed or unknown messages are dropped without crashing.

**FR-3.3**: Only the owning broadcaster may publish broadcaster-side control and status messages for its channels (Realtime authorization tied to the authenticated broadcaster). Anonymous viewers may only publish their own join and signaling messages.

**FR-3.4**: Realtime presence tracks viewers in a session for viewer count and capacity enforcement.

**FR-3.5**: The viewer join message carries an optional, nullable viewer identity field. It is always null in Phase 2 (reserved for Phase 3 viewer sign-in).

**FR-3.6**: Realtime never carries caption payloads in Phase 2.

### FR-4: WebRTC Transport

**FR-4.1**: The WebRTC data-channel transport is implemented in `zip_core` using `flutter_webrtc` (approved dependency).

**FR-4.2**: Star topology: the broadcaster holds one peer connection per viewer.

**FR-4.3**: ICE servers are exclusively the self-hosted Coturn instance, providing both STUN and TURN. There is no Google STUN or other third-party ICE server (ADR-011; AGENTS.md constraint).

**FR-4.4**: TURN credentials are short-lived and issued per session. Static, long-lived TURN secrets are never embedded in client builds. The issuing mechanism is decided in Spike 2.3 and Infrastructure Design.

**FR-4.5**: Same-network delivery uses WebRTC host candidates (direct LAN path, DTLS-encrypted, no TURN).

**FR-4.6**: Per-viewer connection type is reported to the broadcaster (P2P direct, TURN relayed, connecting, disconnected), and the viewer sees its own connection status.

**FR-4.7**: The transport layer sits behind an abstraction, so the deferred transports (Realtime relay in Phase 3; local Wi-Fi WebSocket and BLE GATT in Phase 5) can be added without changing the caption bus or rendering pipeline (ADR-011 transport negotiation).

### FR-5: Remote Broadcast Output Target

**FR-5.1**: A new `CaptionOutputTarget` (ADR-008) subscribes to the broadcaster's caption bus and sends `SttResult` events and session state changes to all connected viewers over their data channels. It requires no changes to existing targets.

**FR-5.2**: The wire format for caption messages over the data channel is versioned JSON, carrying the `SttResult` fields defined in ADR-005 (a stable contract, not modified).

**FR-5.3**: On the viewer side, received `SttResult` events are published into the viewer's caption bus, so the existing Phase 1 rendering pipeline displays them unchanged (ADR-011: the pipeline does not depend on the transport).

**FR-5.4**: A viewer joining mid-session receives captions from the point of joining. No backlog or replay of earlier captions is sent.

### FR-6: Broadcast Session Management (Zip Broadcast)

**FR-6.1**: Create/configure broadcast screen: session name and output target selection. There is no relay toggle in Phase 2.

**FR-6.2**: Starting a remote broadcast requires sign-in (FR-1.4), obtains or creates the broadcast ID, creates a new ephemeral `session_id`, and publishes live status.

**FR-6.3**: The stable broadcast URL is displayed with copy-to-clipboard.

**FR-6.4**: Live broadcast dashboard: viewer count against the capacity cap, connection type per viewer, caption preview, and audio level.

**FR-6.5**: Ending a broadcast notifies all viewers ("broadcast ended"), closes the peer connections, clears presence and live status, and releases resources.

**FR-6.6**: If the broadcaster disappears without a clean end (crash or network loss), viewers move to "not currently broadcasting" or "reconnecting" within a bounded timeout. Stale live status is cleared by presence expiry.

**FR-6.7** (revision from Application Design Q3): The broadcast lifecycle and the captioning lifecycle are **independent by default**. A broadcaster can go live without captioning running. Pausing or stopping captioning never ends the broadcast, and ending the broadcast never stops local captioning. An optional setting, "start captioning when going live" (default off), couples the start. While a broadcast is live and captioning is not active, the broadcaster sees a large, prominent "captions inactive" notice, and viewers see a message that captions are currently paused by the broadcaster.

### FR-7: Viewer Experience (Zip Captions)

**FR-7.1**: Join screen: enter a broadcast ID or paste a broadcast URL. Both forms are parsed and validated.

**FR-7.2**: Zip Captions web handles the `/b/{broadcast_id}` route and opens the viewer directly.

**FR-7.3**: The live caption viewer reuses the Phase 1 caption rendering and applies the **viewer's own** display settings (text size, font, contrast, flow direction).

**FR-7.4**: The viewer sees these states: connecting, live, live with captions paused by the broadcaster (FR-6.7), reconnecting, not currently broadcasting, broadcast ended, broadcast full, cannot connect (with a specific reason).

**FR-7.5**: Automatic reconnection: after a temporary disconnect (network change, brief loss), the viewer rejoins the same broadcast without user action, via ICE restart or re-signaling.

**FR-7.6**: Viewing requires no account and no sign-in (see FR-3.5 for the reserved identity field).

### FR-8: Viewer Capacity

**FR-8.1**: Each broadcast has a maximum concurrent-viewer cap. The default is set from Spike 2.1 measurements, targeting 100-200.

**FR-8.2**: When the cap is reached, further join attempts are refused with a clear "broadcast is full" message.

**FR-8.3**: The broadcaster's dashboard shows the current count and the cap.

### FR-9: External Display Output (Zip Broadcast desktop)

**FR-9.1**: A new `CaptionOutputTarget` renders captions in a borderless window on a user-selected display (Jordan S2.2 classroom second monitor, S2.3 auditorium projector).

**FR-9.2**: Platforms: macOS, Windows, Linux. Zip Broadcast web is excluded.

**FR-9.3**: It uses the broadcaster's caption display settings and works signed-out (FR-1.4).

**FR-9.4**: Display selection, opening and closing the window, and behaviour when the selected display is disconnected (fall back gracefully and notify the broadcaster) are defined in Functional Design.

**FR-9.5**: Any new dependency (for example a multi-window or screen-enumeration plugin) needs human approval and a supply-chain justification before it is added.

**FR-9.6** (revision during User Stories, brownfield finding): Phase 1 already shipped `CaptionOverlayTarget` with `OverlayConfig.targetDisplayId` and the `desktop_multi_window` dependency, but never opens the window (no `show()` caller, no secondary-window entry point) and cannot list connected displays. FR-9 is delivered by completing this existing target, not by adding a new one. Only a display-enumeration capability can require a new dependency under FR-9.5.

### FR-10: Existing OBS Output

**FR-10.1**: `ObsWebSocketTarget` and `BrowserSourceTarget` (Phase 1) are unchanged by Phase 2 feature work.

**FR-10.2**: Spike 2.2 confirms whether `ObsWebSocketTarget` uses the correct OBS closed-caption API on current OBS versions. A gap becomes a separately scoped follow-up, not part of the Phase 2 feature units.

---

## Non-Functional Requirements

### NFR-1: Performance

**NFR-1.1**: A remote viewer sees a caption within 1 second of it appearing on the broadcaster's own display, over P2P or TURN under normal network conditions. The target is to be validated or adjusted by Spikes 2.1 and 2.3.

**NFR-1.2**: Broadcaster fan-out at the cap must not degrade local captioning latency (Phase 1 NFR-1.1) or OBS output. Low CPU footprint remains a requirement (Phase 1 NFR-1.3; Jordan S2.1).

**NFR-1.3**: Time from opening a broadcast URL to first caption, and reconnection time after network restoration: **TBD pending Spike 2.1**.

**NFR-1.4**: Stable 1-2 hour broadcasts at capacity without memory growth or connection leaks.

### NFR-2: Scale

**NFR-2.1**: Target 100-200 concurrent viewers per broadcast. The enforced cap is **TBD pending Spike 2.1** (broadcaster fan-out on desktop and web, and Realtime signaling/presence load at 200 joining viewers) and Spike 2.3 (TURN load at that scale).

### NFR-3: Privacy and Security

**NFR-3.1**: Zero-retention (ADR-006): Coturn and Supabase Realtime never log, store or inspect caption payloads. Server-side log configuration is security-critical and needs approach pre-approval.

**NFR-3.2**: Caption payloads travel only over DTLS-encrypted WebRTC data channels in Phase 2. No unencrypted caption transport exists.

**NFR-3.3**: No transcript or caption content appears in application logs, telemetry, crash reports or analytics.

**NFR-3.4**: Every new Supabase table has RLS policies. RLS policy definitions are security-critical and need approach pre-approval.

**NFR-3.5**: Broadcast-ID resolution exposes only broadcast ID, live status, session name and signaling channel, never account identifiers or email. The resolution path is protected against bulk enumeration (for example rate limiting). The mechanism is decided in design.

**NFR-3.6**: All signaling and control messages are validated at the boundary (type, size, schema). Viewers cannot impersonate the broadcaster or publish on the broadcaster's control channel.

**NFR-3.7**: TURN credentials are ephemeral (FR-4.4). Coturn is configured to deny relaying to private and internal address ranges.

**NFR-3.8**: Auth tokens are never logged and are stored only via the SDK's secure mechanism. The OAuth approach needs pre-approval (FR-1.7).

### NFR-4: Reliability

**NFR-4.1**: Transport, signaling and auth failures never crash either app. Each surfaces a specific, user-understandable state (FR-7.4).

**NFR-4.2**: A viewer's reconnection does not affect other viewers or the broadcaster's local captioning.

**NFR-4.3**: Broadcaster disconnect is detected, and viewers are informed within a bounded timeout (FR-6.6).

### NFR-5: Accessibility

**NFR-5.1**: WCAG AAA contrast (7:1) for caption text in the viewer and on the external display (carried forward).

**NFR-5.2**: Viewer connection-state changes are announced to screen readers, and status is never conveyed by color alone.

### NFR-6: Observability

**NFR-6.1**: Coturn usage (bytes relayed, concurrent allocations, connection duration, relay ratio) is instrumented and observable, with alerting thresholds (ADR-011, ADR-012). The detail is in Infrastructure Design.

**NFR-6.2**: Transport-type and connection-success metrics, if collected, contain no caption content and no viewer identity.

### NFR-7: Testing

**NFR-7.1**: 80%+ code coverage per package (carried forward).

**NFR-7.2**: Property-based testing per the PBT extension (see Extension Compliance).

**NFR-7.3**: Signaling, transport and output target are testable with fakes, without a network. Integration tests run against the local Supabase stack.

**NFR-7.4**: Two-device manual verification of the exit criteria, including restricted-NAT simulation for TURN.

### NFR-8: Platform Support

**NFR-8.1**: Broadcaster (remote broadcasting): Zip Broadcast on macOS, Windows, Linux and web.

**NFR-8.2**: Viewer: Zip Captions on iOS, Android, macOS, Windows, Linux and web.

**NFR-8.3**: Risk: `flutter_webrtc` data-channel maturity on Windows and Linux desktop. Spike 2.1 must cover at least one Windows or Linux broadcaster. Platform tiering is adjusted after the spike if needed.

---

## Research Spikes (early Phase 2 Construction units)

Spikes run as early Construction units, before the units that depend on them (Phase 1 precedent). Requirement values marked TBD are set from their outcomes.

**Spike 2.1 (re-scoped)**: Measure (1) broadcaster fan-out: CPU, memory and caption latency with N concurrent WebRTC data channels from one Zip Broadcast instance, on desktop (including Windows or Linux) and web, up to 200; and (2) self-hosted Supabase Realtime signaling and presence load with 200 viewers joining. Output: the recommended viewer cap and the NFR-1.3 values.

**Spike 2.2**: Confirm the OBS WebSocket closed-caption API on current OBS versions against `ObsWebSocketTarget`. Output: confirmation or a scoped gap.

**Spike 2.3**: Coturn deployed alongside Supabase: resource usage, configuration (including payload-free logging and private-range denial), the ephemeral credential mechanism, TURN relay through symmetric NAT, and TURN load at target scale.

---

## Deferred Scope

| Item | Deferred to | Reason |
|---|---|---|
| Opt-in Supabase Realtime relay, "Allow server relay" toggle, warning text, mid-broadcast toggling, payload E2E encryption, relay exit criterion | Phase 3 | Q3:C, CQ6:A — relay ships only with encryption |
| Local Wi-Fi WebSocket transport | Phase 5 | CQ5:A — no-internet value depends on BLE discovery; WebRTC host candidates cover same-network in Phase 2 |
| BLE discovery and GATT transport | Phase 5 | Roadmap; Q4 |
| Vanity broadcast URLs (reservation, uniqueness, entitlement gate) | Phase 4 | Q7:A |
| Viewer sign-in UI; remaining OAuth providers; account merging, deletion and profile | Phase 3 | CQ2:A, CQ4:A |
| Persisted session records | Not planned | CQ1:A — session state is ephemeral by design |
| External display on web and mobile | Unscheduled | CQ8:A |

---

## Documentation Updates Required

These are tracked for Documentation Refinement, with per-change approval:

1. **Roadmap**: move the relay deliverables and exit criterion from Phase 2 to Phase 3; move local Wi-Fi WebSocket to Phase 5; record the minimal-auth slice pulled into Phase 2 and remove it from Phase 3's list; move vanity-URL reservation to Phase 4; re-scope the Spike 2.1 description; update Phase 2 exit criteria.
2. **Technical specification Section 9**: add the broadcast-ID registry table name and its RLS summary; note that Phase 2 Realtime carries no caption payloads.
3. **Technical specification Section 6**: add any newly approved dependency (external-display window plugin).
4. **ADR-011**: note the Phase 2 delivery order (WebRTC first; relay after Phase 3 encryption; local WebSocket with BLE).
5. **AGENTS.md "Current Scope"**: still says Phase 0; update to Phase 2.

---

## Extension Compliance

### Security Baseline
All SECURITY rules are enabled as blocking constraints. The full rule file is loaded at the first Construction stage that applies it. Phase 2 applicable rules:
- **SECURITY-01** (Encryption in transit): DTLS data channels; TLS to Supabase and Coturn (TURNS where applicable)
- **SECURITY-02** (Access logging on intermediaries): Coturn and Realtime access logs contain no payloads
- **SECURITY-03** (Application logging): no caption or transcript content and no tokens in logs
- **SECURITY-04** (HTTP security headers): Zip Captions web viewer route
- **SECURITY-05** (Input validation): signaling messages, broadcast ID and URL parsing, resolution endpoint
- **SECURITY-06** (Least privilege): RLS; anonymous role limited to resolution; Realtime channel authorization
- **SECURITY-07** (Restrictive network config): Coturn port exposure and private-range denial
- **SECURITY-08** (Application access control): broadcaster-only control channel publishing
- **SECURITY-09** (Hardening): Coturn and Supabase configuration
- **SECURITY-10** (Supply chain): `flutter_webrtc` and `supabase_flutter` version pinning; approval for the external-display plugin
- **SECURITY-11** (Secure design): enumeration resistance, and abuse and capacity limits
- **SECURITY-12** (Authentication and credentials): OAuth flow, token storage, ephemeral TURN credentials
- **SECURITY-13** (Integrity): signaling message schema versioning
- **SECURITY-14** (Alerting and monitoring): Coturn usage alerting
- **SECURITY-15** (Fail-safe defaults): transport and auth failures degrade gracefully

### Property-Based Testing
All PBT rules are enabled. Phase 2 PBT targets:
- **PBT-02** (Round-trip): signaling message and caption wire-format serialization; broadcast URL and ID parse/format
- **PBT-03** (Invariant): broadcast ID alphabet, length and format; viewer count never exceeds the cap; every connected viewer receives every caption, in order, after its join point
- **PBT-04** (Idempotency): end-broadcast and leave handling; duplicate ICE candidate or join messages
- **PBT-06** (Stateful): broadcaster session state machine; viewer connection and reconnection state machine
- **PBT-07/08**: generators for malformed and adversarial signaling payloads, with shrinking

---

## Phase 2 Exit Criteria (revised from roadmap)

1. A broadcaster signs in and starts a session on Zip Broadcast; a viewer connects on Zip Captions via the stable URL, with no account, and sees live captions
2. WebRTC P2P connection works between two devices on the same network
3. TURN relay works when P2P fails (tested with restricted NAT simulation)
4. A viewer reconnects automatically after a temporary disconnection
5. A broadcast at its cap refuses new viewers with a "broadcast is full" message
6. External-display output shows captions on a second display on at least one desktop platform
7. OBS closed-caption behaviour is confirmed by Spike 2.2 (any gap is tracked as a follow-up)
8. The browser source serves a caption overlay page (Phase 1 regression check)
9. Local captioning and local outputs work signed-out

(The roadmap's "Supabase Realtime relay works when opted in" criterion moves to Phase 3.)

---

## Assumptions to Confirm at Review

1. **FR-5.4**: Viewers joining mid-session receive no backlog.
2. **FR-7**: Native Zip Captions accepts pasted URLs and IDs. OS-level universal or app links (opening `zipcaptions.app/b/...` directly into the native app) are **not** in Phase 2.
3. **Viewer transcripts**: received captions enter the viewer's caption bus, so the existing Phase 1 transcript saving applies to viewers unchanged, with no new viewer-specific saving feature.
4. **Hosting**: serving `zipcaptions.app/b/{id}` (web deployment and domain) is an operations concern outside Phase 2 Construction. Phase 2 delivers the route in the Zip Captions web build.
