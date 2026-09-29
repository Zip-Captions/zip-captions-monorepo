# NFR Requirements — Broadcaster Auth (Unit 2)

**Prior stage**: Functional Design + SR-01, approved 2026-09-28. Most NFRs here formalize
decisions already made there rather than introduce new ones — see
`broadcaster-auth-nfr-requirements-plan.md` for the open questions this stage resolved
(Q1–Q4, all answered).

## Scalability

Not applicable in any meaningful sense: this unit is a single-user client-side auth flow
(one broadcaster, one device, one sign-in at a time — Rule 1). There is no fan-out, no
per-request capacity concern, and no shared server-side component this unit owns (GoTrue's
own scalability is Supabase's concern, out of this unit's scope).

## Performance

**Q4 (A)**: No numeric latency target for the OAuth flow itself — it's dominated by the
external browser and the provider's consent screen, neither under this app's control, so a
budget here wouldn't be meaningful the way caption latency is (NFR-1.1). The only concrete
requirement: `AuthNotifier` transitions to `SigningIn(providerId)` within one UI frame of
the tap (standard responsiveness, not a new measured NFR) — Proto-10's spinner treatment
depends on this being immediate, not on the OAuth round trip itself.

Session restore at app start (F-BA-2) must not block on a network round trip — this was
already a Functional Design decision, restated here as a hard NFR: cold start must not
stall waiting for GoTrue's session-refresh call.

## Availability / Reliability (NFR-4.1)

- Every auth-flow failure surfaces a specific, user-understandable state (the `AuthFailure`
  table, SR-01 Section 7) — never a crash, never a silent hang. This satisfies NFR-4.1 for
  the auth slice specifically.
- No auto-retry on failure: OAuth requires user interaction regardless (the consent screen),
  so an automatic retry can't succeed without the user anyway — Proto-10's manual retry
  button is sufficient and matches Rule 1 (single in-flight sign-in).
- Sign-out succeeds locally even if the network is down (Rule 2) — availability of the
  *sign-out* path does not depend on Supabase being reachable.

## Testability (NFR-7.1–7.3)

- **NFR-7.1** (80%+ coverage): applies to `AuthService`, `SupabaseAuthService`,
  `AuthNotifier`, and the sign-in view, same as every other `zip_core`/`zip_broadcast`
  component.
- **NFR-7.2** (PBT per extension): see PBT Compliance below; framework is the existing
  in-repo shim, not a new dependency (Q-equivalent resolved during research, no open
  question needed — see Tech Stack Decisions).
- **NFR-7.3** (testable with fakes, no network) — **Q2 (A)**: `mocktail` for
  interaction-style assertions (e.g. "`signIn` was called with `providerId`"), plus a
  small hand-written fake `AuthService` that can be driven through an explicit sequence of
  `authStateChanges` emissions, needed for the stateful PBT in `testable-properties.md`
  (a `mocktail` mock alone can't hold and emit state across a sequence the way a fake can).

## Platform Support (NFR-8.1)

macOS, Windows, Linux, and web — already the scope fixed by SR-01's per-platform flow
table (Section 2). No platform is deferred or partially supported within this unit.

## Error Reporting Scope (Q3)

**Q3 (A)**: The `providerError` catch-all (SR-01 Section 7, `business-rules.md` Rule 9)
logs via the existing `logging` package (`Logger`, already used in `zip_broadcast/lib/main.dart`)
only — device/console-scoped, no aggregation. A project-wide crash-reporting SDK (e.g.
Sentry) is explicitly out of scope for this unit and recorded as a Backlog item in
`aidlc-state.md`, to be decided once, project-wide, not unit-by-unit.

## Security

Full SR-01 approach stands unchanged (Section on OAuth flow, redirect, storage, refresh,
sign-out, failure handling, config-only provider addition). This section adds the
Security Baseline compliance pass now that the extension is loaded for this unit.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | Compliant | Session tokens encrypted at rest via `flutter_secure_storage` on desktop (SR-01 §4); all Supabase traffic is HTTPS/TLS by the SDK's default, no unencrypted transport introduced. |
| SECURITY-02 (Access logging on network intermediaries) | N/A | This unit has no load balancer, API gateway, or CDN of its own — it's a client calling Supabase's own infra (owned by `zip_supabase` units, SR-02/SR-03). |
| SECURITY-03 (Application-level logging) | Compliant | `logging` package configured (existing `zip_broadcast/lib/main.dart` setup, Q3); no tokens/credentials/PII in log output (Rule 4, Rule 9). |
| SECURITY-04 (HTTP security headers) | N/A | No HTML-serving endpoint exists in this unit — Zip Broadcast's web build's headers are a deployment/hosting concern outside this unit's scope. |
| SECURITY-05 (Input validation on API params) | N/A | This unit calls the Supabase SDK; it does not expose an API endpoint of its own. `providerId` is validated implicitly by lookup against the static `AuthProviderConfig` list (Rule 5) — an unknown id fails the lookup rather than reaching the SDK unvalidated. |
| SECURITY-06 (Least-privilege access policies) | N/A | No IAM/role policy is defined by this unit — GoTrue/RLS policy is SR-02's (Unit 3) concern. |
| SECURITY-07 (Restrictive network configuration) | N/A | No firewall/network resource is defined by this unit. |
| SECURITY-08 (Application-level access control) | N/A | This unit doesn't serve resources by ID or enforce object-level authorization — it is the identity-establishing layer other units' authorization checks (Unit 3's RLS, per SR-02) depend on, not a consumer of such checks itself. |
| SECURITY-09 (Hardening / misconfiguration) | Compliant | No default credentials; Supabase URL/anon key come from build-time config, not hardcoded source; error states shown to users are generic (SR-01 §7), no stack traces surfaced in the UI. |
| SECURITY-10 (Software supply chain) | Compliant | **Revised 2026-09-28 (twice, same day)**: `app_links` ends up as a direct dependency after all (`^7.0.0`) — not because it's needed to receive the OAuth callback (that's `supabase_flutter`'s own internal, transitive use), but because `SupabaseAuthService` runs its own parallel subscription to observe OAuth failures the SDK doesn't surface (`sr-01-oauth-approach.md` §3, Correction 2). It was already present transitively either way. `supabase_flutter` itself is pre-approved (Section 6). `flutter_secure_storage` matches the existing `^9.2.2` pin already used in `zip_broadcast` (no version drift within the app); pub.dev (trusted registry) throughout. |
| SECURITY-11 (Secure design principles) | Compliant | Auth logic is isolated in `AuthService`/`SupabaseAuthService`/`AuthNotifier`, not scattered across the app (Rule 5); misuse cases considered — cancelled/denied OAuth, revoked tokens, concurrent sign-in attempts (Rule 1), sign-out during a broadcast (Rule 9). Rate limiting (SR-11's public-endpoint clause) is N/A — this unit exposes no public endpoint. |
| SECURITY-12 (Auth and credential management) | Compliant | Session expiration and refresh handled by the SDK; secure storage on desktop (SR-01 §4); sign-out invalidates the session both locally and server-side (global scope, SR-01 §6); no hardcoded credentials. Password policy/MFA/brute-force clauses are N/A — this unit delegates authentication entirely to the OAuth provider and GoTrue, it has no password of its own to manage. |
| SECURITY-13 (Software/data integrity) | N/A | No deserialization of untrusted data occurs in this unit (the OAuth callback URL is parsed by the SDK/`app_links`, not custom-deserialized here); no CI/CD pipeline change; no CDN-loaded script. |
| SECURITY-14 (Alerting and monitoring) | N/A (see Backlog) | No alerting infrastructure exists for a client-side Flutter app; a crash-reporting SDK would be how this unit could eventually satisfy the spirit of this rule, explicitly deferred (Q3, Backlog entry in `aidlc-state.md`) rather than adopted unit-by-unit. |
| SECURITY-15 (Exception handling / fail-safe defaults) | Compliant | Every OAuth-flow exception is caught and mapped to an `AuthFailure` (Rule 9's "never unmapped" invariant, also `testable-properties.md` row 1); failures fail closed to `SignedOut`/`AuthFailed`, never a silent signed-in default; user-facing errors are generic (Proto-10's alert card). |

## PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | Compliant | `testable-properties.md` (Functional Design addendum) identifies 4 properties across Invariant, Idempotence, and Stateful categories; Round-trip/Oracle/Commutativity/Induction marked N/A with rationale. |
| PBT-02 (Round-trip) | N/A | No serialization/deserialization exists in this unit. |
| PBT-03 (Invariant) | Compliant | Failure-mapping totality and provider-button-list rendering, both carried from `testable-properties.md`. |
| PBT-04 (Idempotence) | Compliant | `signOut()` idempotence, carried from `testable-properties.md`. |
| PBT-05 (Oracle) | N/A | No reference/brute-force implementation exists to compare against. |
| PBT-06 (Stateful) | Compliant | `AuthNotifier`'s state machine against a simplified reference model, carried from `testable-properties.md`; the fake `AuthService` (Q2-A) is the vehicle for this. |
| PBT-07 (Generator quality) | Compliant (planned) | Command generator for the stateful PBT must weight realistic sequences over uniform-random enum picks, per `testable-properties.md`'s "Carried to Code Generation" note — enforced at Code Generation review, not yet written. |
| PBT-08 (Shrinking / reproducibility) | Compliant (framework-provided) | The existing in-repo PBT shim (`packages/zip_core/test/helpers/pbt.dart`) runs 100 seeded trials per property with reproducible `Random` seeds — see Tech Stack Decisions. |
| PBT-09 (Framework selection) | Compliant | Reuses the existing shim rather than adding a new dependency — see Tech Stack Decisions for why real `glados` isn't used. |
| PBT-10 (Complementary testing) | Compliant (planned) | Example-based tests pin each named `AuthFailure` scenario from S-15's acceptance criteria explicitly; PBT covers the general state-machine and mapping-totality properties on top, not instead. Enforced at Code Generation. |
