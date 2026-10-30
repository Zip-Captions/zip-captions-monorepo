# Phase 2 Build and Test Record

**Status:** written during Unit 9 (Integration Milestones), 2026-10-30.
**Scope:** what Phase 2's construction actually demonstrated, what it did not,
and what was deliberately left unproven.

This file exists because Phase 1's five build-and-test documents describe Phase
1. Without this one, everything Phase 2 proved lived only in a gitignored
working ledger and a session log, and would not survive the merge.

Read the verdict column strictly:

- **verified** — a command was run and its observed result is recorded below.
- **inspection only** — read from source or configuration, not executed.
- **not verified** — believed true, not demonstrated. Track B work.
- **deferred** — consciously out of scope, with a reason.
- **blocked** — waits on something outside engineering control.

A phase record that only lists the first column is how a phase gets remembered
as more finished than it was.

---

## 1. Gate results at the end of Unit 9

All run on the developer machine, Flutter 3.41.7 (see §6 for the CI skew that
matters).

| Gate | Command | Result |
|---|---|---|
| Analysis, shared library | `flutter analyze --fatal-infos` in `packages/zip_core` | no issues |
| Analysis, viewer app | same, `packages/zip_captions` | no issues |
| Analysis, broadcaster app | same, `packages/zip_broadcast` | no issues |
| Tests, shared library | `flutter test` | 968 passed, 5 skipped (973 run) |
| Tests, viewer app | `flutter test` | 195 passed, 0 skipped |
| Tests, broadcaster app | `flutter test` | 195 passed, 0 skipped |
| Coverage suite | `melos run test:coverage --no-select` | `zip_core`, `zip_captions`, `zip_broadcast` green; `lcov.info` produced for each. `zip_supabase` has no Dart tests and is skipped by the `dirExists: test` filter |
| Live-stack credential suite | `flutter test --tags integration-supabase --run-skipped test/integration/broadcast_turn_credentials_supabase_test.dart` | 9 passed |

The 5 skips are the `integration-supabase`-tagged suites, which skip by default
because they require the local stack. They are not failures.

---

## 2. What Phase 2 integrated, and how strongly

### 2.1 Anonymous viewer relay credentials (D2, B2) — verified

The claim under test: an anonymous viewer can obtain a TURN credential and use
it, without signing in.

| Step | Verdict | Evidence |
|---|---|---|
| Function reachable by `anon` for a real broadcast | verified | through Kong, `200` with `username`, `credential`, `ttl`, `urls` |
| Unknown broadcast id rejected | verified | `401`, `42501 get_broadcast_turn_credentials: unknown broadcast` |
| Null / empty / whitespace / lowercase id rejected | verified | each `401 42501` (paced to clear Kong's 2/s limit); asserted by name in the live-stack suite |
| Credential is genuine TURN REST auth | verified | HMAC-SHA1 recomputed independently from the shared secret; **MATCH** |
| Coturn accepts the credential | verified | `turnutils_uclient` against 127.0.0.1:3478: ALLOCATE success twice, relay address received, refresh success |
| Coturn rejects a tampered credential | verified | same username, fabricated credential: `Cannot complete Allocation` |
| Broadcaster's existing path unchanged | verified | `anon` on `get_turn_credentials()` still `401 42501` |
| TTL | verified | 1 hour, matching the broadcaster's function |
| Kong rate limiting applies to the new route | verified | 30/min, 2/s per IP; unpaced runs trip `429` |
| A viewer actually relays captions through TURN in the app | **not verified** | needs Track B with the relay-only switch |

The username is `<epoch-expiry>:<broadcast_id>`. Coturn treats the username as
opaque and only re-derives the HMAC over it, so this costs nothing and makes
each issued credential attributable to one broadcast in TURN session logs,
without recording anything about the viewer.

**Deliberately no per-broadcast quota.** A quota would need per-broadcast state
that this schema has no place for (see the note in
`20261001000000_broadcast_identity_signaling.sql` about FR-2.6 ruling out
persisted session rows). The guard is broadcast existence only. The risk this
accepts: anyone who knows a broadcast id that has ever been issued can obtain
relay credentials for it, limited by Kong's per-IP rate and by Coturn's own
allocation limits. Those per-IP limits are the only ceiling.

"Ever been issued" rather than "live": the guard tests existence in
`broadcast_identities`, which has no liveness column and no deletion path in
Phase 2, so a dormant broadcaster's id still mints a credential. That is no
worse in practice - no media is flowing for a dormant broadcast - but the set is
monotonic and should be described as what it is. Enumeration stays infeasible:
the id is 6 Crockford-Base32 characters (about 1.07 billion), and Kong caps one
IP at 1,800 attempts an hour.

**The grant is not the control.** `has_function_privilege('anon', …)` returns
`true` for both credential functions regardless of their `GRANT` statements,
because this image's `public` default ACL re-applies on `CREATE OR REPLACE`.
Both functions therefore guard in the body. This is now recorded as a rule in
`docs/04-technical-specification.md` §9.

### 2.2 macOS network entitlement (D1, B1) — verified to the signed bundle

The claim: the sandboxed macOS builds can open network connections at all.
Without `com.apple.security.network.client`, a sandboxed app cannot reach the
network, so this gated every other Phase 2 feature on that platform.

| Step | Verdict | Evidence |
|---|---|---|
| Key present in all four source entitlement files | verified | parsed with `plistlib` |
| Key survives into the signed Debug bundle (`zip_broadcast`) | verified | `codesign -d --entitlements` → `True` |
| Key survives into the signed Release bundle (`zip_broadcast`) | verified | same → `True` |
| Key survives into the signed Debug bundle (`zip_captions`) | verified | same → `True` |
| Networking actually works at runtime | **not verified** | needs Track B |

Checking the signed bundle rather than the source file matters: a plist can be
correct while the product is not. CI builds macOS but never inspects
entitlements, so this check is stronger than anything CI would give.

### 2.3 Connection-route reporting (D4, B3/B4) — verified in unit tests

The claim: the viewer list reports the route the connection actually took,
instead of always claiming a direct path.

| Step | Verdict | Evidence |
|---|---|---|
| Route derived from the selected ICE candidate pair | verified | `getStats()` → `classifyStatsReports` → `classifyCandidatePairRoute`, unit-tested including the `StatsReport` adapter |
| Either leg relayed is reported relayed | verified | classifier reads `remoteCandidateId` as well as `localCandidateId`; a host-local / relay-remote pair reports `turnRelayed`, so a relay-only broadcaster is not shown to viewers as direct |
| `relay` candidate → `turnRelayed` | verified | classifier tests |
| `host`/`srflx`/`prflx` → `p2pDirect` | verified | classifier tests |
| Unanswerable/malformed stats → `disconnected`, never a guessed direct path | verified | classifier + transport tests |
| A stats failure never produces `Failed` or `Interrupted` | verified | transport tests, both sides: the viewer test and a broadcaster test that throws from `selectedCandidateRoute()` |
| Relay-only switch cannot be reached in release builds | inspection only | `const bool relayOnlyIceEnabled = kDebugMode && bool.fromEnvironment(...)`; a compile-time constant, so the guarantee is structural. Not observed in a built release artefact |
| A real connection reports its real route in the app | **not verified** | needs Track B |

The relay-only switch (`--dart-define=ZIP_CAPTIONS_RELAY_ONLY_ICE=true`) exists
solely so the TURN fallback can be proven on demand, since a direct path
succeeds on most networks. It is a compile-time constant guarded by
`kDebugMode`, not a call-site option, so it cannot be passed in a release
build.

### 2.4 Google OAuth for the local stack (D3, B5) — blocked

| Step | Verdict | Evidence |
|---|---|---|
| Provider configurable through environment variables only | verified | four `GOTRUE_EXTERNAL_GOOGLE_*` entries reading from `.env`; no secret in a tracked file |
| Provider disabled when unconfigured | verified | `/auth/v1/settings` reports `"google": false` |
| Redirect URL configured | verified | `ADDITIONAL_REDIRECT_URLS` set |
| Sign-in with Google works end to end | **blocked** | no client id/secret; the owner declined to supply them at this time |

Placeholders only, provider off. This is recorded as blocked rather than
skipped so it does not read as done.

---

## 3. Deferred, with reasons

| Item | Verdict | Reason |
|---|---|---|
| EC5 "other viewers unaffected" when one viewer's connection fails | deferred | requires a real-protocol swarm test; D5 decision was not to build one |
| M3, 50 concurrent viewers | deferred | same |
| Anonymous viewer claim, phone form (M-S3.6 clause 1) | out of scope | belongs to Unit 13; recorded as gap G6 |
| `maxViewers = 50` behaviour under real load | deferred | no swarm harness; the constant and its admission unit tests are unchanged |

The 50-viewer limit is still 50. What is missing is any observation of the
system under that load — the admission logic is unit-tested, the capacity
behaviour is not demonstrated.

---

## 4. Not verified at the time of writing

These are the rows that keep this document honest. Each is believed correct and
none is demonstrated.

1. A viewer joining from a browser (or another app instance) sees captions from
   a desktop broadcaster.
2. TURN relay actually carries captions when direct connectivity fails.
3. The macOS network entitlement works at runtime, not just in the signature.
4. Google sign-in, if credentials were supplied.
5. ~~Any CI workflow against this branch~~ — resolved: nine checks green
   on PR #45.
6. Multi-monitor popping-out behaviour (noted as a Unit 9 platform check by the
   pop-out design).

Items 1-3 and 6 are Track B work and require a person at the keyboard.

---

## 5. Defects found and not fixed

Recorded because they were found by this unit's work and should not be lost
with it.

### 5.1 Coturn cannot write its configured log file

`turnserver.conf` sets `log-file=/var/log/turnserver/turnserver.log` and
`docker-compose.yml` mounts a volume there. The container runs as
`nobody:nogroup` (the image hard-sets it), while the mounted directory is
`root:root 755`. Coturn logs, on every start:

```
ERROR: Cannot open log file for writing: /var/log/turnserver/turnserver.log
INFO: log file opened: /var/tmp/turn_1_<date>.log
```

Effect: the named log volume is always empty and the configured path is dead.
Not a privacy defect — the fallback file is still payload-free (`simple-log`,
`verbose` off, so only connection/session metadata) — but a diagnosability
defect: the log you would reach for during a TURN incident does not exist where
the config says it does.

Not fixed in Unit 9: it is a compose/ownership change outside this unit's
scope. Recommended fix, when taken: drop the volume and the
`log-file=`/`no-stdout-log` pair and log to stdout, which is the image's own
default. `docker logs` then becomes the interface. That distinction (stdout for
local, a real sink for deployment) belongs in the compose comment.

### 5.2 `test:coverage` was an undefined melos script

CI called `melos run test:coverage`, which worked only because `melos run`
falls back to executing an unknown name as a raw command. Fixed in Unit 9:
the script now exists in `melos.yaml`, with the same `dirExists: test` filter
as `test`.

### 5.3 Local TURN shared secret is the documented placeholder

The local stack runs with `TURN_SHARED_SECRET` set to the
`.env.example` placeholder value. Correct for local development; worth stating
because Unit 9's TURN verification used it, so "verified with the TURN secret"
must not be read as "verified with a real secret". The HMAC path exercised is
identical either way.

### 5.4 macOS builds warn about an onnxruntime version mismatch

Every macOS build emits:

```
ld: warning: building for macOS-11.0, but linking with dylib
'@rpath/libonnxruntime.1.23.2.dylib' which was built for newer version 13.4
```

Pre-existing, unrelated to Phase 2, not fixed. It means the shipped binary
claims a lower deployment target than one of its dependencies supports.

---

## 6. Environment facts that affect these results

- **Flutter skew.** The developer machine runs 3.41.7; both CI workflows pin
  3.38.7. Everything above was verified on 3.41.7. A newer local SDK can be
  more permissive than CI's, so "no issues" locally does not guarantee the same
  in CI. Nothing in D1-D4 depends on post-3.38.7 APIs, so the risk is low, but
  it is unverified.
- **CI ran green on this branch.** Flutter is pinned at 3.38.7 in both
  workflows. When the branch was pushed and PR #45 opened, all nine checks
  passed: Analyze & Test, Android APK (debug), iOS (no codesign), and Linux,
  Windows and macOS for each of the two apps. That is the first and only
  evidence that removing `zip_broadcast/{android,ios}` broke nothing: no local
  gate covers those platform builds. An earlier revision of this document said
  no CI run existed, which was true when written and false within the hour;
  corrected here rather than left to rot. A later revision said "ten jobs";
  `gh pr checks` lists nine, and this now matches it.
- **The live stack holds real data** (31 broadcast identities and 84 auth
  users at the time of writing). Verification used it read-mostly; the one
  schema change (the D2 migration) is additive. `supabase db reset` was never
  run, and there is no `supabase_migrations.schema_migrations` table in this
  stack, so migrations are applied by hand against the volume.
- **Web is a deferred target, not a gap.** Neither app has a `web/` directory;
  `flutter build web` fails in both. ADR-001 keeps web as the Fallback platform
  for a later phase. For Phase 2, "browser viewer" means a browser opening the
  stable broadcast URL against a desktop broadcaster, not a Flutter web build.

---

## 7. What Phase 2 does not claim

Stated plainly so this document cannot be cited for more than it says:

- Phase 2 is not verified end to end in a real app on all platforms. Only the
  macOS signed bundles and the local backend stack were exercised.
- The 50-viewer capacity target is unobserved.
- CI validated the build matrix (nine checks, PR #45), but CI runs no
  `integration-supabase` suite, so it says nothing about the live-stack
  behaviour above. Local runs are the only evidence for D2.
- Translation is Phase 8 and nothing here depends on it.
