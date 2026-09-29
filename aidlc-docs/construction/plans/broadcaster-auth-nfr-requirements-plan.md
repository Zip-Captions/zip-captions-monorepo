# NFR Requirements Plan: Broadcaster Auth (Unit 2)

**Unit**: broadcaster-auth | **Prior stage**: Functional Design + SR-01, approved 2026-09-28

Most of this unit's NFRs are already substantively decided by the approved SR-01 document
(security) and Functional Design (reliability, testability). This stage formalizes them
into `nfr-requirements.md`/`tech-stack-decisions.md`, runs the Security Baseline and PBT
compliance passes, and resolves the few genuinely open items below.

## Planned Steps

- [x] Map this unit's requirements against NFR-1 (Performance), NFR-3.8 (already satisfied by SR-01), NFR-4.1 (Reliability), NFR-7 (Testability), NFR-8.1 (Platform Support)
- [x] Run the Security Baseline (SECURITY-01..15) compliance pass against the approved design
- [x] Run the PBT (PBT-01..10) compliance pass, confirming PBT-09 framework selection
- [x] Generate `aidlc-docs/construction/broadcaster-auth/nfr-requirements/nfr-requirements.md`
- [x] Generate `aidlc-docs/construction/broadcaster-auth/nfr-requirements/tech-stack-decisions.md`
- [x] Generate `aidlc-docs/construction/broadcaster-auth/nfr-requirements/handoff-summary.md`

## Security Baseline — Preliminary Pass (for your awareness, not a question)

Most SECURITY rules are **N/A** for this unit — it's a Flutter client consuming Supabase's
own GoTrue/RLS server, which is where rules like SECURITY-02 (network intermediary access
logging), SECURITY-04 (HTTP headers), SECURITY-06/07 (IAM/network policies), SECURITY-08
(server-side authorization enforcement), SECURITY-13 (CI/CD pipeline integrity), and
SECURITY-14 (alerting infra) actually live — those belong to `zip_supabase` infra units
(SR-02/SR-03, Units 3–4), not here. Applicable here: SECURITY-01 (token storage encryption
— satisfied by `flutter_secure_storage` on desktop), SECURITY-03 (app logging — satisfied
by Rule 4/9's no-credentials rule), SECURITY-09 (no hardcoded credentials — Supabase URL/
anon key come from build config, not source), SECURITY-10 (dependency pinning — Q1 below),
SECURITY-11 (secure design — auth logic is already isolated in `AuthService`/
`SupabaseAuthService`, not scattered), SECURITY-12 (credential management — session
expiration/secure storage/no hardcoded secrets, satisfied), SECURITY-15 (fail-safe
defaults — every `AuthFailure` path fails closed to `SignedOut`/`AuthFailed`, never a
silent signed-in default). Full compliance table goes in `nfr-requirements.md`.

## Open Questions

### Q1: Dependency version pins for `app_links` (new) and `flutter_secure_storage` (already approved, not yet in `zip_broadcast`'s direct auth path)?
`flutter_secure_storage` is already pinned at `^9.2.2` in `zip_broadcast`'s `pubspec.yaml`
(used elsewhere). Current `app_links` latest is `7.1.1` (verify against pub.dev at the
actual PR, since this plan is time-of-writing).

- A. `flutter_secure_storage: ^9.2.2` (match the existing pin exactly, no version drift within the app) and `app_links: ^7.1.1` **(recommended)**
- B. Pin exact versions (no caret) for both, per SECURITY-10's stricter reading
- C. Other (write in)

[Answer]: A

### Q2: Test double strategy for `AuthService` in unit tests?
NFR-7.3 requires this be testable with fakes, without a network.

- A. `mocktail`-based mock for interaction-style tests (e.g. "signIn was called with X"), plus a small hand-written fake `AuthService` (stream-driven, per `testable-properties.md`'s stateful property) for the PBT state-machine test — **(recommended — mocktail is the project's established mocking convention; a fake, not a mock, is needed for the stateful PBT since it must actually hold and emit state over a sequence)**
- B. `mocktail` only, no separate fake
- C. Other (write in)

[Answer]: A

### Q3: Crash/error reporting integration for the `providerError` catch-all logging (Rule 6)?
SR-01/Rule 9 established that unmapped exceptions get their type and stack trace logged,
never their message. This unit doesn't currently have a crash-reporting SDK to route that
to — is one in scope here?

- A. Log via the existing `logging` package (`Logger`, already used per `packages/zip_broadcast/lib/main.dart`) only — no new crash-reporting service in Phase 2 **(recommended — no crash-reporting dependency exists anywhere in the project yet; adding one is a bigger decision than this unit's scope)**
- B. Add a crash-reporting SDK (e.g. Sentry) now, scoped to this unit
- C. Other (write in)

[Answer]: A

### Q4: Sign-in flow performance target?
NFR-1.1/1.2 are about caption latency, not auth — S-15 has no explicit timing AC (unlike
NFR-1.3's join-to-first-caption target from Spike 2.1). OAuth sign-in latency is dominated
by the external browser and the provider's own consent screen, outside this app's control.

- A. No numeric performance target for sign-in itself — only require that `SigningIn` state renders within one frame of the tap (standard UI responsiveness, not a new NFR) **(recommended — an external, user-paced OAuth flow isn't meaningfully budgetable the way caption latency is)**
- B. Set an explicit target anyway (state a number)

[Answer]: A
