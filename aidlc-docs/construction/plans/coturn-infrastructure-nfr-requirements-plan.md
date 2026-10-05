# NFR Requirements Plan: Coturn Infrastructure (Unit 4)

**Unit**: coturn-infrastructure | **Stories**: S-12, gated by SR-03 | **Prior stage**: none — Functional Design is skipped for this unit (no business logic; `phase2-unit-of-work.md`). Inputs instead: Spike 2.3's report (credential mechanism, config, NAT-traversal proof, port-sizing finding) and Application Design's fixed component list.

## Context

**Components** (`phase2-unit-of-work.md`, `phase2-components.md`): Coturn service (STUN/TURN), a TURN credential issuer, `TurnCredentialService` + implementation, `IceServerProvider` + implementation, metrics/alert thresholds, private-range relay denial.

**Fixed interfaces** (Application Design, `phase2-component-methods.md` — not open questions, just the contract this unit implements against):
```dart
abstract interface class IceServerProvider {
  Future<List<IceServer>> iceServersFor(String sessionId);
}
abstract interface class TurnCredentialService {
  Future<TurnCredentials> fetch(String sessionId); // username, credential, expiresAt, urls
}
```

**Already decided by Spike 2.3** (not re-opened here): TURN REST shared-secret credential mechanism (HMAC-SHA1 of a timestamp against a shared secret); `denied-peer-ip` private-range relay denial list; `simple-log` payload-free logging; Prometheus metrics exporter. Validated end-to-end including through a simulated symmetric NAT.

**Open from Spike 2.3's own Recommendations** (this is where this unit's real decisions are): the relay port range (100 ports was proven too narrow), and *where* the credential-issuing endpoint lives (the shared secret must never reach the client).

## Planned Steps

- [ ] Scalability — relay port range sizing
- [ ] Performance — no formal latency target, or one?
- [ ] Availability — restart/health-check posture
- [ ] Security — credential TTL, shared-secret storage, metrics exposure, credential-issuer placement
- [ ] Tech Stack — Coturn version pin, package placement for the two Dart components
- [ ] Reliability — alert thresholds
- [ ] Maintainability — testing approach
- [ ] Generate `aidlc-docs/construction/coturn-infrastructure/nfr-requirements/nfr-requirements.md`
- [ ] Generate `aidlc-docs/construction/coturn-infrastructure/nfr-requirements/tech-stack-decisions.md`

## Scalability

### Q1: What relay port range should the real (non-spike) Coturn config use?

Spike 2.3's own test config used `49152–49252` (100 ports) and a 10-concurrent-client smoke test exhausted it (`create_relay_ioa_sockets: no available ports`) — each client relay allocation holds a port for the session's lifetime.

- A. The full dynamic/private port range, `49152–65535` (~16,384 ports) — Coturn's own common default, ample headroom over Spike 2.1's interim `maxViewers=50` cap even accounting for multiple allocations per client (each viewer's WebRTC connection may need more than one relay candidate). **(recommended — matches Coturn's own documentation default; no reason to under-provision a range that costs nothing extra to reserve)**
- B. A narrower range sized exactly to `maxViewers=50` with a small multiplier (e.g. 500–1000 ports)
- C. Other (write in)

[Answer]: A

## Performance

### Q2: Is there a formal latency target for TURN allocation / ICE gathering?

NFR-1.3 (already fixed, Spike 2.1-informed) covers join-to-first-caption and reconnection timings at the application level, but doesn't separately target the TURN-allocation step itself.

- A. No new formal target — TURN allocation latency is already implicitly bounded by NFR-1.3's end-to-end join-to-first-caption target; adding a second, narrower target for just this one step would be redundant without evidence it's ever the bottleneck (Spike 2.3 didn't measure allocation latency specifically). **(recommended — avoids inventing an unmeasured number; revisit if real usage shows TURN allocation as a specific bottleneck)**
- B. Add an explicit target now (e.g. allocation ≤500ms)
- C. Other (write in)

[Answer]: A

## Availability

### Q3: What's the restart/health-check posture for the Coturn service in the local/self-hosted stack?

- A. `restart: unless-stopped` (matches every other service in `packages/zip_supabase/docker-compose.yml`) plus a basic health check (e.g. a STUN binding request) — single instance, no HA, consistent with this project's existing self-hosted-single-node posture for the whole Supabase stack (Unit 4's own precedent: "Supabase Local Dev"). **(recommended — matches existing project conventions exactly, no new operational pattern introduced)**
- B. Something more elaborate (e.g. a standby instance) — not justified at this project's current stage
- C. Other (write in)

[Answer]: A

## Security

### Q4: Where should the TURN credential-issuing endpoint live?

Spike 2.3 flagged this as explicitly open: the shared secret must never reach the client, and `phase2-components.md` says "zip_supabase or stack, per Spike 2.3" without deciding further.

- A. A `SECURITY DEFINER` Postgres function in `zip_supabase` (mirroring Unit 3's `resolve_broadcast_id`/`get_or_create_my_broadcast_id` precedent exactly) — callable via PostgREST RPC by any `authenticated` caller (a viewer or broadcaster about to start a WebRTC connection needs credentials; TURN credentials aren't sensitive beyond their short TTL, so no additional authorization check beyond "signed in" is needed). The shared secret lives as a Postgres setting (`app.settings.*`), never in application code or client-reachable config, same pattern already used for the JWT secret. **(recommended — direct precedent already proven twice in this codebase, same security properties, no new infrastructure component)**
- B. A Supabase Edge Function (Deno) instead
- C. Other (write in)

[Answer]: A

### Q5: What TTL (`expiresAt`) should issued TURN credentials carry, and what happens when it expires mid-session?

**Correction before answering (raised during review)**: TTL only gates the *credential*, not the underlying TURN allocation. An active allocation is kept alive by periodic `Refresh` requests (roughly every ~10 minutes, per the TURN protocol's own allocation lifetime), and every `Refresh` must re-authenticate with the same credential. Once the credential's embedded expiry passes, the next `Refresh` is rejected (401) and the allocation gets torn down shortly after — **a TURN-relayed viewer would be disconnected**, not gracefully degraded. There is no automatic renewal built into TURN; avoiding this requires application code that fetches a fresh credential before expiry and calls `RTCPeerConnection.setConfiguration()` with it.

- A. 1 hour (3600s) TTL, **and** proactive credential refresh before expiry is a **hard requirement of Unit 5** (`WebRtcBroadcastTransport`/`WebRtcViewerTransport`, the components that actually own a long-lived session), not an optional/deferred nicety — Unit 5's own Functional/NFR Design must implement `setConfiguration()`-based renewal before that unit is considered complete, since broadcast sessions can plausibly exceed an hour. This unit's own scope (`TurnCredentialService.fetch`) is unaffected either way — it already supports being called again for a fresh credential; Unit 5 is responsible for calling it again in time. **(recommended — keeps the shorter, more leak-resistant TTL while making the real fix a tracked, binding requirement rather than hoping 1 hour is always enough)**
- B. A TTL long enough that expiry mid-session is very unlikely in practice (e.g. 12 hours), deferring proactive renewal to a future Backlog item instead of a hard Unit 5 requirement
- C. Other (write in)

[Answer]: A

### Q6: Should the Prometheus metrics endpoint be reachable outside the Docker network?

- A. No — internal-only (not published to the host), matching this project's existing posture of binding only what's needed to `127.0.0.1` (Unit 4/Supabase Local Dev's own `infrastructure-design.md` precedent: "All ports bound to 127.0.0.1 to prevent LAN exposure"). A human can `docker exec`/`curl` from inside the stack's network if metrics are ever needed locally; no external scraper exists yet at this project's stage. **(recommended — no current consumer for external metrics access, and publishing it would be a wider attack surface for no present benefit)**
- B. Publish it to `127.0.0.1` like the other service ports, for future scraping
- C. Other (write in)

[Answer]: A

## Tech Stack

### Q7: Coturn version pin?

- A. `coturn/coturn:4.6.2` — exactly what Spike 2.3 validated everything against (credential mechanism, NAT traversal, denial rules, logging). Pinning a different version without re-validation would reopen questions this spike just closed. **(recommended — don't drift from the exact version the spike's evidence is about)**
- B. A newer tag
- C. Other (write in)

[Answer]: A

### Q8: Where do `TurnCredentialService`/`IceServerProvider` and their implementations live?

- A. `zip_core`, mirroring every prior unit's package-placement precedent (`SupabaseAuthService`, `SupabaseBroadcastIdentityRepository`, `SupabaseSignalingService` are all in `zip_core`, consumed by both apps). `SupabaseTurnCredentialService` calls the Postgres RPC from Q4; `SupabaseIceServerProvider` composes it with the Coturn STUN/TURN URLs to build the `IceServer` list `flutter_webrtc` expects. **(recommended — identical placement reasoning to every prior unit: shared logic, used by both apps, no app-specific UI involved)**
- B. Split differently (write in)
- C. Other (write in)

[Answer]: A

## Reliability

### Q9: What alert thresholds matter for Coturn (the "metrics and alert thresholds" component explicitly listed for this unit)?

- A. Defer concrete alert-threshold *wiring* (an actual alerting pipeline) as out of scope for Phase 2 — this project has no alerting/monitoring infrastructure yet, a distinct gap from Unit 2's already-recorded crash-reporting-SDK deferral (that one's about client-side error visibility; this is operational/infrastructure health monitoring). **A new Backlog entry is added for this** (operational alerting infrastructure, project-wide, not yet adopted), explicitly separate from the crash-reporting one, so the two don't get conflated when someone eventually picks either up. This unit's Infrastructure Design documents *which* Prometheus metrics matter and *what* threshold would indicate a problem (e.g. relay port exhaustion, allocation failure rate), as guidance for whenever the project does adopt monitoring. **(recommended — avoids standing up a one-off alerting mechanism for a single unit when the project has no monitoring strategy at all yet, while still tracking the gap explicitly rather than letting it go unrecorded)**
- B. Build actual alerting now (e.g. a simple script/webhook) scoped to just this unit
- C. Other (write in)

[Answer]: A

## Maintainability

### Q10: Testing approach for `SupabaseTurnCredentialService`/`SupabaseIceServerProvider`?

- A. Unit tests with mocktail fakes for the Postgres RPC call (matching `SupabaseBroadcastIdentityRepository`'s precedent exactly), plus a real-backend integration test against the local stack (tagged `integration-supabase`, skipped by default — the pattern already established in Unit 3) verifying the actual HMAC credential issuance and that Coturn accepts it. **(recommended — identical testing-layer split to Unit 3, reuses the exact tagging convention already in place)**
- B. Unit tests only, no integration test
- C. Other (write in)

[Answer]: A
