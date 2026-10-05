# NFR Requirements — Coturn Infrastructure (Unit 4)

**Prior stage**: none — Functional Design is skipped for this unit (no business logic;
`phase2-unit-of-work.md`). Inputs: Spike 2.3's report (TURN REST credential mechanism,
private-range denial, NAT-traversal proof, port-range sizing finding) and Application
Design's fixed `IceServerProvider`/`TurnCredentialService` interfaces.

## Scalability

- **Q1 (A)**: Relay port range widened to the full dynamic/private range,
  `49152–65535` (~16,384 ports), from Spike 2.3's accidentally-narrow 100-port test
  config that a mere 10-client smoke test exhausted. Sized with real headroom over
  Spike 2.1's interim `maxViewers=50` cap, accounting for multiple relay allocations per
  client.

## Performance

- **Q2 (A)**: No new formal latency target for TURN allocation/ICE gathering —
  already implicitly bounded by NFR-1.3's join-to-first-caption target. Revisit only if
  real usage shows TURN allocation as a specific bottleneck.

## Availability

- **Q3 (A)**: `restart: unless-stopped` plus a basic STUN-binding health check, single
  instance, no HA — matches every other service in this project's self-hosted Supabase
  stack (Unit 4/Supabase-Local-Dev precedent).

## Reliability

- **Q9 (A, corrected)**: No alerting *pipeline* built for this unit — this project has
  no operational monitoring infrastructure at all yet (new Backlog item added,
  2026-10-02, distinct from Unit 2's crash-reporting-SDK deferral). This unit's
  Infrastructure Design instead documents which Prometheus metrics matter and what
  threshold would indicate a problem (relay port exhaustion, allocation failure rate),
  as guidance for whenever the project adopts real monitoring.
- Credential expiry is a reliability-relevant finding from this stage's own review (see
  Security, Q5): a TURN allocation is kept alive by periodic `Refresh` requests that
  must re-authenticate, so an expired credential causes the *next* refresh to fail and
  the allocation to be torn down shortly after — a real disconnection for any
  TURN-relayed (not direct-P2P) viewer, with no automatic renewal built into the TURN
  protocol itself.

## Testability

- **Q10 (A)**: `SupabaseTurnCredentialService`/`SupabaseIceServerProvider` get
  mocktail-based unit tests (matching `SupabaseBroadcastIdentityRepository`'s precedent)
  plus a real-backend integration test against the local stack (tagged
  `integration-supabase`, skipped by default — Unit 3's established convention),
  verifying the actual HMAC credential issuance and that Coturn accepts it.

## Security

### Credential Mechanism and Lifecycle (Q4, Q5)

- **Q4 (A)**: The TURN credential-issuing endpoint is a `SECURITY DEFINER` Postgres
  function in `zip_supabase`, mirroring Unit 3's `resolve_broadcast_id`/
  `get_or_create_my_broadcast_id` precedent exactly — callable via PostgREST RPC by any
  `authenticated` caller. The shared secret used for the HMAC-SHA1 TURN REST scheme
  lives as a Postgres setting (`app.settings.*`), never in application code or any
  client-reachable config — same pattern as the existing JWT secret.
- **Q5 (A, corrected during review)**: Issued credentials carry a 1-hour (3600s) TTL.
  **This is not sufficient on its own** — TTL only gates the credential, not the
  underlying TURN allocation (kept alive by periodic re-authenticated `Refresh`
  requests), so an expired credential causes a real mid-session disconnection for any
  TURN-relayed viewer, with no automatic renewal built into TURN itself. Per the user's
  explicit decision: proactive credential refresh (fetching a new credential before
  expiry and calling `RTCPeerConnection.setConfiguration()`) is a **hard requirement of
  Unit 5** (`WebRtcBroadcastTransport`/`WebRtcViewerTransport`, the components that own
  long-lived sessions) — not an optional/deferred Backlog item. This unit's own scope
  (`TurnCredentialService.fetch`) already supports being called again for a fresh
  credential; Unit 5 is responsible for calling it again in time.
- **Q6 (A)**: The Prometheus metrics endpoint is internal-only (not published to the
  host), matching this project's existing `127.0.0.1`-only posture for everything that
  doesn't need external exposure (Unit 4/Supabase-Local-Dev precedent). No current
  consumer needs external scraping.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | Compliant | `tls-listening-port` configured in the recommended Coturn config (TURN-over-TLS available); the credential-issuing RPC rides the same TLS-terminated PostgREST/Kong path every other RPC in this project uses. |
| SECURITY-02 (Access logging on intermediaries) | N/A | Kong/gateway access logging is existing infrastructure, unchanged by this unit. |
| SECURITY-03 (Application-level logging) | Compliant | Coturn's recommended config is payload-free by construction (`simple-log`, no `-v`/`-V`) — confirmed in Spike 2.3 across every test run. The credential-issuing function logs nothing beyond what Postgres/PostgREST already log for any RPC call. |
| SECURITY-04 (HTTP security headers) | N/A | No HTML-serving endpoint in this unit. |
| SECURITY-05 (Input validation) | Compliant | The credential-issuing RPC takes no attacker-controlled parameters beyond the caller's own `auth.uid()` (session id, if any, is server-derived); Coturn's own STUN/TURN message parsing is the library's responsibility, not this unit's. |
| SECURITY-06 (Least privilege) | Compliant | The credential-issuing function is `SECURITY DEFINER` scoped to exactly "compute and return an HMAC," nothing broader (Q4) — mirrors Unit 3's least-privilege `resolve_broadcast_id` precedent. |
| SECURITY-07 (Network configuration) | Compliant | Coturn's relay port range is now correctly sized (Q1); the Prometheus metrics port stays internal-only (Q6); STUN/TURN ports are the only ones intentionally reachable. |
| SECURITY-08 (Application-level access control) | Compliant | Credential issuance requires `authenticated` (Q4) — no anonymous caller can obtain TURN credentials, consistent with this project's broader "anon gets only what's explicitly needed" posture. |
| SECURITY-09 (Hardening) | Compliant | `denied-peer-ip` private-range relay denial (validated twice independently in Spike 2.3); `no-cli`, `fingerprint`, `no-multicast-peers` hardening flags already in the recommended config. |
| SECURITY-10 (Supply chain) | Compliant | `coturn/coturn:4.6.2` pinned (Q7) — the exact version Spike 2.3's evidence is about; no floating tag. |
| SECURITY-11 (Secure design, rate limiting) | N/A | No new public-facing high-frequency endpoint comparable to Unit 3's `resolve_broadcast_id` — the credential-issuing RPC is called once per session start, not a brute-forceable enumeration surface. |
| SECURITY-12 (Auth/credential management) | Compliant | This unit *is* a credential-management surface — TURN credentials are short-lived (1hr TTL, Q5), HMAC-derived from a never-client-exposed shared secret (Q4), never persisted anywhere beyond the issuing request/response. |
| SECURITY-13 (Data integrity) | N/A | No persisted data model in this unit (no table — the credential function is stateless, computing the HMAC fresh each call). |
| SECURITY-14 (Alerting/monitoring) | N/A-with-Backlog-note | See Q9 — this project has no alerting infrastructure yet; new Backlog item added, distinct from Unit 2's. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant | An expired or malformed credential fails closed (Coturn rejects with 401, never partially authenticates); the credential-issuing function has no failure mode beyond "caller not authenticated," which PostgREST/RLS already handles uniformly. |

## PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | N/A | No pure-Dart business logic in this unit to identify properties for — `SupabaseTurnCredentialService`/`SupabaseIceServerProvider` are thin RPC-calling adapters, the same category as `SupabaseBroadcastIdentityRepository` (Unit 3), whose actual correctness properties (HMAC computation, credential validity) live server-side and are covered by the integration test (Q10), not PBT. |
| PBT-02 through PBT-10 | N/A | Same reasoning — no pure-function round-trip/invariant/stateful-model candidates exist in this unit's Dart surface. Mirrors Unit 3's own precedent of marking the repository-layer adapters as outside PBT's scope while the pure-Dart *model* types (none exist in this unit) would be the actual PBT candidates. |
