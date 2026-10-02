# NFR Requirements — Broadcast Identity + Signaling (Unit 3)

**Prior stage**: Functional Design + SR-02, approved 2026-09-30. Most of this unit's
NFRs are already substantively fixed there; this stage formalizes them and resolves the
two genuinely open items (Q1, Q2).

## Performance

- **Q1 (A)**: `resolve_broadcast_id` is rate-limited at Kong to 30 requests/minute per
  IP with a short burst allowance (~10 in the first 5 seconds) — generous for a
  legitimate viewer retrying a mistyped code, restrictive enough that a brute-force
  sweep of the ~1.07 billion-code space is impractical. Exact Kong config is
  Infrastructure Design's job; this is the target it implements against.
- **Q2 (A)**: No formal latency NFR for `get_or_create_my_broadcast_id` — the 10-attempt
  retry bound is a correctness fail-safe (a real collision streak this long signals a
  broken random source, not expected load), not a performance target worth measuring.
  The expected case is a single round-trip.
- Resolution's two-step design (existence RPC, then a separate presence read for live
  status — SR-02 §2) means a full `resolve()` call's latency is bounded by two
  sequential network round-trips in the worst case (RPC, then channel-join-and-read),
  not one — this is restated here as an accepted design consequence, not a defect to
  optimize away in this unit.

## Reliability (NFR-4.1)

- Every signaling-input failure mode (malformed, unknown-type, unsupported-version,
  oversized) resolves to a dropped message, never a crash or thrown exception
  (`business-rules.md` Rule 4) — this is this unit's contribution to NFR-4.1's "signaling
  failures never crash either app."
- Presence-expiry (60s, Spike 2.1 interim) is the sole "broadcaster disappeared"
  detection mechanism (Rule 6) — no redundant heartbeat to maintain or get out of sync.
- `get_or_create_my_broadcast_id`'s unique-constraint-driven retry (Rule 1) means a
  concurrent-request race degrades to "one extra retry," never a duplicate row or a
  crash.

## Testability (NFR-7.1–7.3)

- **NFR-7.1** (80%+ coverage): applies to the Dart-side repository/resolver/signaling
  implementations; SQL functions and RLS policies are covered by integration tests
  against the local Supabase stack (below), not unit-test line coverage in the usual
  sense.
- **NFR-7.2** (PBT per extension): see PBT Compliance below.
- **NFR-7.3** (testable with fakes; integration tests against the local stack for what
  fakes can't cover): `testable-properties.md` already separates pure-Dart PBT
  candidates (codec round-trips, never-throws invariants) from the two properties that
  need a real Postgres instance (registry uniqueness/reuse) — those become integration
  tests at Code Generation, not unit tests with mocks, since the behavior being verified
  *is* the database constraint working correctly, which a mock can't meaningfully stand
  in for.

## Security

SR-02 stands unchanged. This section adds the Security Baseline compliance pass.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A (platform-level) | Inherited from the existing Supabase stack's TLS/Postgres config — this unit doesn't configure storage encryption itself. |
| SECURITY-02 (Access logging on intermediaries) | N/A | Kong/gateway logging is Unit 4/5's infra, not this unit's. |
| SECURITY-03 (Application-level logging) | Compliant | No credential or account-identifying data is ever logged by this unit's components — the resolution RPC returns only a boolean, and signaling messages never carry account identifiers (`viewerIdentity` stays `null`, Rule 7). |
| SECURITY-04 (HTTP security headers) | N/A | No HTML-serving endpoint in this unit. |
| SECURITY-05 (Input validation) | Compliant | `resolve_broadcast_id(text)`'s parameter is Postgres-type-validated; `SignalingCodec.decode` validates every inbound message's shape (Rule 4). No raw string concatenation into SQL anywhere in this unit's design (parameterized function calls only). |
| SECURITY-06 (Least privilege) | Compliant | `get_or_create_my_broadcast_id` is `SECURITY INVOKER`, relying on RLS rather than elevated privilege; `resolve_broadcast_id`'s `SECURITY DEFINER` scope is minimized to a boolean return (SR-02 §3). |
| SECURITY-07 (Network configuration) | N/A | Kong/firewall config is Unit 4/5's infrastructure. |
| SECURITY-08 (Application-level access control) | Compliant | This unit's entire identity design *is* object-level authorization — RLS scoped to `owner_id = auth.uid()` on every registry operation, and Realtime channel RLS scoped by topic/extension (SR-02 §1, §4). |
| SECURITY-09 (Hardening) | Compliant | No default credentials; no stack traces or internal details surfaced to anonymous callers (a failed `resolve_broadcast_id` call simply returns `false`, never an error detail). |
| SECURITY-10 (Supply chain) | N/A | No new dependency introduced by this unit — SQL functions and RLS policies use only Postgres/Supabase built-ins. |
| SECURITY-11 (Secure design, rate limiting) | Compliant | Rate limiting on the one public-facing RPC is explicitly designed in (SR-02 §2, Q1); misuse cases considered (brute-force enumeration, concurrent-registration races, malformed signaling payloads — Rule 1, Rule 4). |
| SECURITY-12 (Auth/credential management) | N/A | This unit consumes Unit 2's auth (`auth.uid()`), it doesn't manage credentials itself. |
| SECURITY-13 (Data integrity) | Compliant | `broadcast_identities` rows are immutable in Phase 2 (no `UPDATE` policy) — nothing to audit-trail beyond the existing `created_at`. |
| SECURITY-14 (Alerting/monitoring) | N/A | No alerting infrastructure exists yet for this project (same Backlog item as Unit 2's — a project-wide decision, not this unit's). |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant | Every signaling failure mode fails closed to "drop the message" (Rule 4); `get_or_create_my_broadcast_id`'s retry bound fails closed to an explicit error rather than looping forever (SR-02 §3). |

## PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | Compliant | `testable-properties.md` identifies 2 round-trip, 3 invariant properties, and explicitly flags 2 stateful/integration-level properties needing the real Supabase stack, not the in-process PBT shim. |
| PBT-02 (Round-trip) | Compliant | `BroadcastLink.toUrl`/`parseInput` and `SignalingCodec.encode`/`decode` round-trips. |
| PBT-03 (Invariant) | Compliant | `BroadcastId.parse` value-preservation, `BroadcastLink.parseInput`/`SignalingCodec.decode` never-throws invariants. |
| PBT-04 (Idempotence) | N/A | No pure-function idempotence claim in this unit's domain (`getOrCreateMine()`'s "same value on repeat calls" is a stateful/database property, not a pure-function one — see `testable-properties.md`). |
| PBT-05 (Oracle) | N/A | No reference/brute-force implementation to compare against. |
| PBT-06 (Stateful) | N/A for pure-Dart PBT | The registry's stateful uniqueness/reuse behavior is covered by integration tests against the local Supabase stack, not an in-process stateful PBT model (there's no in-memory fake of Postgres's unique-constraint behavior worth building here). |
| PBT-07 (Generator quality) | Compliant (planned) | `SignalingMessage` needs two distinct generators (realistic-valid and adversarial-malformed) per `testable-properties.md`'s "Carried to Code Generation" note — not yet written. |
| PBT-08 (Shrinking/reproducibility) | Compliant (framework-provided) | Same existing shim as Unit 2 — seeded, reproducible trials. |
| PBT-09 (Framework selection) | Compliant | Reuses `packages/zip_core/test/helpers/pbt.dart` — no new framework decision needed, same as Unit 2. |
| PBT-10 (Complementary testing) | Compliant (planned) | Example-based tests pin each named `BroadcastResolution` scenario from S-11/S-13's acceptance criteria explicitly; PBT covers the general codec/parsing properties on top. Enforced at Code Generation. |
