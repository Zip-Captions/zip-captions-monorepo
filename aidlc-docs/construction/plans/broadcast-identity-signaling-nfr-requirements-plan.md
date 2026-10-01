# NFR Requirements Plan: Broadcast Identity + Signaling (Unit 3)

**Unit**: broadcast-identity-signaling | **Prior stage**: Functional Design + SR-02, approved 2026-09-30

Unlike Unit 2, this unit owns real server-side infrastructure (a Postgres table, two
SQL functions, Realtime RLS policies) — more Security Baseline rules are directly
applicable here than they were for Unit 2's client-only scope.

## Planned Steps

- [x] Map requirements against NFR-1 (Performance), NFR-3.4/3.5 (already satisfied by SR-02), NFR-4.1 (Reliability), NFR-7 (Testability)
- [x] Run the Security Baseline compliance pass — expect more `Compliant` rows than Unit 2 had, since this unit owns actual data/network infrastructure
- [x] Run the PBT compliance pass, confirming PBT-09 (reuse the existing shim, per Unit 2 precedent — no new question needed)
- [x] Generate `aidlc-docs/construction/broadcast-identity-signaling/nfr-requirements/nfr-requirements.md`
- [x] Generate `aidlc-docs/construction/broadcast-identity-signaling/nfr-requirements/tech-stack-decisions.md`
- [x] Generate `aidlc-docs/construction/broadcast-identity-signaling/nfr-requirements/handoff-summary.md`

## Open Questions

### Q1: Kong rate-limit threshold for `resolve_broadcast_id`?
SR-02 fixed *that* rate limiting happens at Kong, deferring the exact number to
Infrastructure Design — but NFR Requirements should still set a concrete target for
Infrastructure Design to implement against, rather than leaving it fully open until then.

- A. 30 requests/minute per IP, with a short burst allowance (e.g. 10 in the first 5 seconds) — generous enough for a legitimate viewer retrying a mistyped code a few times, restrictive enough that a brute-force sweep of the ~1.07 billion-code space would take centuries at this rate. **(recommended — a concrete, reviewable number beats leaving Infrastructure Design to invent one from scratch; easy to tighten later since it's Kong config, not application code)**
- B. A stricter 10 requests/minute per IP
- C. Defer the exact number entirely to Infrastructure Design (no NFR target set here)
- D. Other (write in)

[Answer]: A

### Q2: `get_or_create_my_broadcast_id` allocation latency / retry-count NFR?
The handoff summary flagged this as open. Collision probability at N existing broadcasters
against a ~1.07 billion-code space is negligible until N is enormous, so this is more a
"bound the worst case" question than an expected-case performance concern.

- A. Bound retries at 10 attempts, no explicit latency NFR beyond "single round-trip in the overwhelmingly common zero-collision case" — if 10 consecutive random collisions ever occur, that's a strong signal of a bug (e.g. a broken random source) rather than expected behavior, so the function should raise an error at that point rather than retry indefinitely (SR-02's function design already does this). **(recommended — this is a correctness/fail-safe bound, not a performance target worth measuring; a formal latency NFR would be measuring noise)**
- B. Set an explicit P99 latency target (e.g. "under 100ms") for `getOrCreateMine()`
- C. Other (write in)

[Answer]: A

## Security Baseline — Preliminary Pass (for your awareness, not a question)

More rules apply here than for Unit 2's client-only scope:
- **SECURITY-01** (encryption at rest/transit): inherited from the existing Supabase stack's TLS/Postgres config, not something this unit configures itself — `N/A` for this unit specifically, already governed at the platform level.
- **SECURITY-05** (input validation): `resolve_broadcast_id(text)`'s single parameter is validated by Postgres's own type system (it's `text`, not user-constructed SQL) plus the function's `exists()` check naturally handles any string, including malformed ones, without special-casing — `Compliant`.
- **SECURITY-06** (least privilege): `get_or_create_my_broadcast_id` is deliberately `SECURITY INVOKER`, not `DEFINER` (SR-02 §3) — the one function that *is* `SECURITY DEFINER` (`resolve_broadcast_id`) is scoped to return only a boolean, the minimum needed — `Compliant`.
- **SECURITY-07** (network config): Kong/firewall config is Unit 4/5's owned infrastructure, not this unit's — `N/A`.
- **SECURITY-08** (application-level access control): this unit's entire design *is* object-level authorization (RLS scoped to `owner_id = auth.uid()`) — `Compliant`.
- **SECURITY-11** (secure design, rate limiting): rate limiting on the one public-facing RPC is explicitly designed in (SR-02 §2, Q1 above) — `Compliant` once Q1's threshold is set.
- **SECURITY-13** (data integrity / auditability): `broadcast_identities` rows are immutable once created in Phase 2 (no `UPDATE` policy) — there's nothing to audit-trail beyond `created_at`, which already exists — `Compliant`.
- Full table with every rule goes in `nfr-requirements.md`.
