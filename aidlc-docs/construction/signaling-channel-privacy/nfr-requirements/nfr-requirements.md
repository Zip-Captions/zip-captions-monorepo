# NFR Requirements — Signaling Channel Privacy (Unit 3.1)

**Prior stage**: Functional Design + SR-04, approved 2026-10-05. Most of this unit's
NFRs are already substantively fixed there; this stage formalizes them and resolves the
genuinely open items (Q1, Q4).

## Scalability

- **Q1 (A)**: the broadcaster's up-to-51-concurrent-channel-subscription load at the
  interim `maxViewers=50` cap will be verified directly against the real local stack at
  Code Generation, not assumed from `supabase_flutter`'s documented multiplexing-over-
  one-WebSocket behavior alone. If a real limit surfaces, the fallback (closing a
  departed viewer's channel immediately rather than batching) is applied and
  re-verified before this unit's Code Generation closes.

## Performance

- **Q2 (A)**: no new measurable latency target. The two-hop join sequence (lobby
  `JoinRequest` → broadcaster subscribes to the new per-viewer topic) adds one Realtime
  channel-subscribe round-trip versus the old one-hop design — folds into Unit 5's own
  NFR-1.3 (join-to-first-caption ≤3s, itself an unmeasured interim target), not a new
  number this unit owns or needs to hit independently.

## Reliability (NFR-4.1)

- **Q3 (A)**: no new cleanup mechanism beyond what already exists. A dropped WebSocket
  connection implicitly ends every channel subscription on it (Realtime platform
  behavior) — this already produces the correct outcome for a crashed broadcaster
  (every viewer losing their connection is the right result, not a leak to prevent).
- Every happy-path teardown (`Leave`, `BroadcastEnded`, Unit-5-detected disconnect)
  closes exactly the one per-viewer channel affected — consistent with Unit 5's own
  per-viewer isolation guarantee (NFR-4.2), now extended to the signaling layer itself.

## Testability (NFR-7.3)

- **Q4 (A)** — the load-bearing item for this unit: channel isolation is a negative
  claim ("Viewer B can observe nothing belonging to Viewer A") that fakes cannot
  demonstrate by construction — a hand-wired fake pair simply never routes cross-viewer
  traffic regardless of whether the real RLS policies are correct. Verified instead by
  a real-backend integration test (tagged `integration-supabase`, Unit 3's established
  skip-by-default convention) with **two concurrently-connected real viewer clients**
  plus one broadcaster client against the local Supabase stack — matching the
  dependency doc's own testing checkpoint for this unit ("verified against the real
  local stack with 2+ concurrent viewers, not just unit tests").
- Dart-side unit tests (fakes/mocktail) cover `LobbyChannel`/`SessionSignalingChannel`'s
  own logic (Q1's cleanup paths, message routing) — NFR-7.3's "testable with fakes"
  half, same as every prior unit; the isolation guarantee itself is NFR-7.3's "real
  stack" half.

## Security

SR-04 stands unchanged. This section adds the Security Baseline compliance pass.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A (platform-level) | Inherited from the existing stack's TLS/Postgres config, unchanged by this unit. |
| SECURITY-02 (Access logging on intermediaries) | N/A | Kong/gateway logging is not touched by this unit — no new HTTP route. |
| SECURITY-03 (Application-level logging) | Compliant | No credential or account-identifying data logged by this unit's components; `peerId` is ephemeral and single-use (business-rules.md Rule 5), carrying no identity to protect in the first place. |
| SECURITY-04 (HTTP security headers) | N/A | No HTML-serving endpoint in this unit. |
| SECURITY-05 (Input validation) | Compliant | `SignalingCodec.decode`'s existing validation is unchanged (Unit 3); this unit changes only channel routing, not message shape or validation. |
| SECURITY-06 (Least privilege) | Compliant | No new `SECURITY DEFINER`/`SECURITY INVOKER` function in this unit — purely RLS-policy-based authorization (SR-04 §3), the least-privilege mechanism already preferred by Unit 3. |
| SECURITY-07 (Network configuration) | N/A | No infrastructure/firewall change — same Realtime endpoint as Unit 3. |
| SECURITY-08 (Application-level access control) | Compliant | This unit's entire purpose *is* finer-grained object-level authorization — per-viewer channel isolation (SR-04 §3) and lobby ownership scoping via the existing `broadcast_identities` table, closing a gap in Unit 3's original, coarser channel-level authorization. |
| SECURITY-09 (Hardening) | Compliant | No internal detail surfaced on an RLS rejection (a viewer attempting to subscribe to another's per-viewer channel or the lobby simply receives nothing — Realtime's own RLS-rejection behavior, not a custom error path this unit adds). |
| SECURITY-10 (Supply chain) | N/A | No new dependency (NFR Requirements Q5). |
| SECURITY-11 (Secure design, rate limiting) | Compliant | This entire unit is a secure-design correction — the misuse case considered is specifically "a legitimate viewer attempts to observe another viewer's connection," now closed by construction (unguessable per-viewer topics) rather than relying on caller discipline. |
| SECURITY-12 (Auth/credential management) | N/A | Consumes Unit 2's auth (`auth.uid()`) unchanged; manages no credentials itself. |
| SECURITY-13 (Data integrity) | N/A | No table, no persisted row this unit creates or mutates (the lobby's ownership check reads `broadcast_identities`, an existing immutable table it does not write to). |
| SECURITY-14 (Alerting/monitoring) | N/A | Same standing project-wide Backlog item as every prior unit — no alerting infrastructure exists yet. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant | An RLS rejection fails closed (the rejected caller simply receives nothing, never an error revealing why); the Q1 fallback (if a channel-count limit is found) fails toward immediate cleanup, not toward leaving a viewer's channel open past its need. |

## PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | N/A for new properties | `SignalingMessage`/`SignalingCodec`'s existing round-trip/invariant properties (Unit 3) are unaffected — this unit changes routing, not message shape. No new pure-Dart property to identify (NFR Requirements Q6). |
| PBT-02 (Round-trip) | N/A | No new codec; existing `SignalingCodec` round-trip stands unchanged. |
| PBT-03 (Invariant) | N/A for pure-Dart PBT | The channel-isolation invariant is exactly Q4's real-backend integration test's job — not a generated-input space (there's no meaningful "generate random inputs" angle to a fixed RLS yes/no). |
| PBT-04 (Idempotence) | N/A | No pure-function idempotence claim in this unit's domain. |
| PBT-05 (Oracle) | N/A | No reference/brute-force implementation to compare against. |
| PBT-06 (Stateful) | N/A for in-process PBT | Covered by the Q4 integration test against the real stack, not an in-memory stateful model. |
| PBT-07 (Generator quality) | N/A | No new generator needed — `peerId` generation is a one-line UUID call, not something PBT-worthy to generate variations of. |
| PBT-08 (Shrinking/reproducibility) | N/A | No new PBT suite in this unit. |
| PBT-09 (Framework selection) | N/A | No new PBT suite; existing framework (`packages/zip_core/test/helpers/pbt.dart`) untouched. |
| PBT-10 (Complementary testing) | Compliant (planned) | The Q4 integration test is itself the complementary, example-based proof for this unit's one real property; no PBT suite needed alongside it. |
