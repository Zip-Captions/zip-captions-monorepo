# Spike 2.1 Report: Broadcaster Fan-Out and Signaling Load

**Date**: 2026-09-27 (paused — macOS N=25/50 only; see Status)
**Status**: PAUSED by user decision 2026-09-27. Harness built, debugged, and validated end-to-end on macOS at N=25 and N=50. Root-caused the join-success-rate degradation down to the SCTP/DCEP layer on the broadcaster side (STUN ruled out via direct local-STUN-server test); full confirmation and fix not reached. N=100/150/200, the Windows-or-Linux leg, and the web leg were not run. The Realtime load test was attempted but blocked by an unresolved JWT signature issue, after fixing 7 unrelated pre-existing bugs in the local Supabase stack along the way (see Signaling/Presence Load Measurements). **Interim, explicitly-revisable values are recorded to unblock Units 3/5**: `BroadcastLimits.maxViewers = 50`, `presenceTimeout = 60s`, `reconnectWindow = 120s`, NFR-1.3 join-to-first-caption ≤3s, NFR-1.3 reconnection ≤5s — none of these are backed by this spike's measurements; see Recommendations for the actual basis of each.
**Scope**: (1) Broadcaster fan-out — CPU, memory, and caption latency with N concurrent WebRTC data channels from one broadcaster process, stepped up to 200, covering macOS, at least one of Windows or Linux, and a web broadcaster. (2) Self-hosted Supabase Realtime signaling and presence load with 200 viewers joining a session.

---

## Executive Summary

Harness built and validated end-to-end on macOS. Two real, debugged issues were found and fixed along the way (not measurement findings, but real bugs a human running this would also hit): the macOS Runner's default entitlements lack `com.apple.security.network.client` (outbound sockets blocked) and block filesystem writes outside the sandboxed container (results file couldn't be written); both fixed by adding the client entitlement and disabling the sandbox for this throwaway harness.

**Finding**: join success rate degrades as concurrent viewer count increases — N=10: 10/10 (100%), N=25: 24/25 (96%), N=50: 37–39/50 (74–78%, two runs) — while the broadcaster's own log reports **100% of data channels reaching the local "open" state** at every N tested. The initial hypothesis (public STUN server contention) was tested directly with a local coturn STUN server (`stun:127.0.0.1:3478` via Docker) and **ruled out**: N=50 against local STUN produced the same failure rate (37–39/50) as against `stun.l.google.com`. Per-viewer connection-state instrumentation (added to `viewer_swarm/swarm.js`: `onStateChange`/`onIceStateChange`/`onSignalingStateChange`/`onGatheringStateChange`) then showed that **every failed viewer reaches `ice: completed` and `pc: connected` within ~60ms** — identical to succeeded viewers. ICE/DTLS transport establishment is not the bottleneck at all. The actual failure is downstream, at the SCTP/DCEP (data channel establishment protocol) layer: the data channel's local "open" event can fire on the *creating* side (the broadcaster, which calls `createDataChannel`) once its local SCTP stream is ready, without the DCEP handshake having actually completed with the remote peer — so the broadcaster logging "100% channels open" does not mean 100% of channels are usable. This points at the **broadcaster's own SCTP/DCEP handling under concurrent channel creation** as the likely bottleneck — squarely inside what this spike is meant to measure (broadcaster fan-out capacity), not a testing artifact.

**Pacing experiment (inconclusive)**: added an opt-in serialization queue to the broadcaster (`CHANNEL_CREATION_PACING_MS`) so `createPeerConnection`/`createOffer` calls happen one at a time with a configurable delay, instead of racing concurrently as each `viewer-joined` event arrives (the original, default behavior). Results at N=50: unpaced 74–78% (two runs), 50ms pacing 84% (42/50), 150ms pacing 78% (39/50) — no monotonic trend, and with only ~50 trials per configuration this is plausibly within normal run-to-run noise rather than a confirmed causal fix. **Root cause is narrowed to the SCTP/DCEP layer but not fully confirmed or resolved.** Closing it out needs either repeated trials per pacing value (for statistical confidence) or direct libwebrtc/flutter_webrtc-side logging of the DCEP handshake — see Next Steps.

**Interim decision (2026-09-27)**: rather than block Units 3/5 on fully closing out this investigation, the user accepted a tentative `BroadcastLimits.maxViewers = 50` as a project constant, explicitly named as revisable — not a value this spike demonstrated as safe. Worth being precise about what the data actually shows: even at N=50 itself, the synthetic harness never saw 100% success (best run was 42/50, 84%); "50" is a conservative round-number placeholder chosen for the interim, not a proven-reliable capacity. Unit 3/5 should treat it as a `const`/configuration value, not a hardcoded literal, so it can move without a design change once real beta data exists (per Unit 9's real-world capacity work, or a resumed Spike 2.1). This resolves the *`maxViewers`* half of the "cap is recommended" exit criterion on an interim basis; `presenceTimeout`, `reconnectWindow`, and the NFR-1.3 timings remain fully open — see Recommendations.

Desktop `flutter_webrtc` risk (NFR-8.3): no crashes or dropped channels observed on macOS through N=50; too early to tier. Not resolved, not escalated — deferred along with the rest of this paused spike.

---

## Methodology

Full harness and runbook: `spikes/phase2/README.md`. Summary:

- **Fan-out**: a throwaway Flutter broadcaster app (`spikes/phase2/fanout/broadcaster_app/`) opens one WebRTC data channel per connecting synthetic viewer, through a throwaway WebSocket signaling relay (`spikes/phase2/fanout/signaling_server/`) — not the real `SignalingService`, which doesn't exist yet (Unit 3 depends on this spike). A Node.js synthetic viewer swarm (`spikes/phase2/fanout/viewer_swarm/`) joins N viewers at a time, ramped 100ms apart to avoid a connection-storm artifact. The broadcaster sends a realistic caption-sized payload once per second to every open channel, matching real captioning cadence. Memory is self-reported by the broadcaster (`ProcessInfo.currentRss`); CPU is sampled externally per-platform (Activity Monitor / Task Manager / `top`) since in-process CPU measurement is unreliable.
- **Signaling/presence load**: a Node.js script (`spikes/phase2/realtime_load/`) opens N concurrent Supabase Realtime channel subscriptions with presence tracking against the local Supabase stack, measuring channel-join time and presence-sync time. Realtime container resource usage is sampled via `docker stats` during each run.
- **Platform coverage**: macOS (required), one of Windows or Linux (required), web (required for the broadcaster; the spec doesn't require a web viewer swarm, since `wrtc`-based synthetic viewers already exercise data-channel behavior independent of the browser they'd run in).

---

## Fan-Out Measurements

### macOS

| N | Memory (MB) | CPU (%) | Latency ms (min / p50 / p95 / max) | Join success rate | Notes |
|---|---|---|---|---|---|
| 25 | not captured¹ | not captured¹ | min 16 / p50 292 / p95 788 / max 800 | 24/25 (96%) | 1 timeout; broadcaster reported 25/25 channels "open" |
| 50 | not captured¹ | 2.6% (post-hoc snapshot, not peak) | min 5 / p50 463 / p95 973 / max 986 | 37/50 (74%), public STUN | broadcaster reported 50/50 channels "open"; ICE completes for all, SCTP/DCEP handshake stalls for the failed subset (see Executive Summary) |
| 50 | not captured¹ | not captured | min 6 / p50 316 / p95 1002 / max 1005 | 39/50 (78%), local STUN | rerun with local coturn STUN — confirms STUN is not the cause (same failure rate) |
| 50 | not captured¹ | not captured | min 35 / p50 445 / p95 835 / max 960 | 42/50 (84%), 50ms channel-creation pacing | experiment: serialized + paced broadcaster-side channel creation |
| 50 | not captured¹ | not captured | min 51 / p50 360 / p95 864 / max 865 | 39/50 (78%), 150ms channel-creation pacing | same experiment, larger pacing — no improvement over 50ms or unpaced; result is inconclusive (see Executive Summary) |
| 100 | TBD | TBD | TBD | TBD | Not yet run — see Executive Summary |
| 150 | TBD | TBD | TBD | TBD | Not yet run |
| 200 | TBD | TBD | TBD | TBD | Not yet run |

¹ The viewer swarm closes each viewer's connection immediately after it resolves (success or timeout), so by the time an external CPU/memory sample could be taken, most connections had already torn down — the harness measures connection-churn behavior, not sustained peak-N load. **Methodology fix needed before further runs**: add a `--dwellMs` option to `viewer_swarm/swarm.js` that holds successful connections open for a fixed window after connecting, so CPU/memory can be sampled at true steady-state for each N.

### Windows / Linux (circle whichever was run: ______)

| N | Memory (MB) | CPU (%) | Latency ms (min / p50 / p95 / max) | Join success rate | Notes |
|---|---|---|---|---|---|
| 25 | TBD | TBD | TBD | TBD | |
| 50 | TBD | TBD | TBD | TBD | |
| 100 | TBD | TBD | TBD | TBD | |
| 150 | TBD | TBD | TBD | TBD | |
| 200 | TBD | TBD | TBD | TBD | |

### Web (broadcaster)

| N | Memory (MB, Chrome Task Manager) | CPU (%) | Latency ms (min / p50 / p95 / max) | Join success rate | Notes |
|---|---|---|---|---|---|
| 25 | TBD | TBD | TBD | TBD | |
| 50 | TBD | TBD | TBD | TBD | |
| 100 | TBD | TBD | TBD | TBD | |
| 150 | TBD | TBD | TBD | TBD | |
| 200 | TBD | TBD | TBD | TBD | |

### `flutter_webrtc` desktop maturity assessment (NFR-8.3)

*TBD — record crashes, dropped channels, memory leaks across the run, or any platform-specific quirks observed on the desktop platform(s). State a platform tiering recommendation (e.g. "macOS: full support; Windows: full support; Linux: degraded/experimental — reason").*

---

## Signaling/Presence Load Measurements (Supabase Realtime)

**No measurements obtained** — the local Supabase stack had never been fully brought up end-to-end before; getting it running surfaced 7 real, previously-latent bugs, all now fixed in tracked files (`packages/zip_supabase/docker-compose.yml`, `volumes/api/kong.yml`, `migrations/20260326000000_initial.sql`), independent of this spike:

1. `db` service's `./migrations:/docker-entrypoint-initdb.d` mount replaced the base `supabase/postgres` image's own bootstrap directory entirely (`migrate.sh`, `init-scripts/`, `migrations/`), silently skipping all base schema/role setup. Fixed by mounting the single migration file individually instead.
2. The base image's bootstrap never sets passwords for `authenticator`, `supabase_auth_admin`, or `supabase_storage_admin` (only `supabase_admin`) — needed for `PGRST_DB_URI`/`GOTRUE_DB_DATABASE_URL`/`DATABASE_URL` to authenticate. Added `ALTER ROLE ... WITH PASSWORD` statements to the project's migration.
3. `realtime` service's `DB_AFTER_CONNECT_QUERY` referenced schema `_realtime` (underscore); the actual schema created by the base image is `realtime`.
4. `rest` (PostgREST) healthcheck used `curl`, not present in that image; switched to a `bash /dev/tcp` check.
5. `meta` (postgres-meta) healthcheck used `wget`, also not present; switched to a `node -e` HTTP check (node is present).
6. `storage` healthcheck used `http://localhost:5000/...`; `localhost` resolves to `::1` first in that container, but the server only binds IPv4. Changed to `127.0.0.1`.
7. `kong.yml`'s realtime upstream (`http://realtime-dev.supabase-realtime:4000/socket/`) doesn't match the compose service name (`realtime`) — Realtime resolves its tenant from the request's Host header, so both a resolvable DNS name and that exact header value are needed. Fixed by adding `realtime-dev.supabase-realtime` as a network alias on the `realtime` service (keeping `kong.yml`'s original hostname).

With all 7 fixed, the stack starts cleanly through Kong except for one remaining issue: the auto-seeded Realtime tenant's `jwt_secret` (correctly sourced from `API_JWT_SECRET`, which matches the project's shared `JWT_SECRET`) still fails signature validation against the standard local-dev anon key (`{:error, :signature_error}` in `RealtimeWeb.UserSocket.connect/3`), even after a clean reseed. This is a real, unresolved issue in Realtime v2.76.5's JWT verification internals (compiled release, no accessible source for the verification path) — not something further guessing could responsibly resolve. Per user decision, this investigation stops here; `presenceTimeout`/`reconnectWindow`/NFR-1.3 are set from documented protocol behavior and engineering judgment instead (see Recommendations), not measurement.

| N | Join time ms (min / p50 / p95 / max) | Presence sync ms (min / p50 / p95 / max) | Total time to all-synced (ms) | Realtime container CPU/mem | Notes |
|---|---|---|---|---|---|
| 25 | Not obtained | Not obtained | Not obtained | Not obtained | Blocked by the JWT signature issue above |
| 50 | Not obtained | Not obtained | Not obtained | Not obtained | Not attempted |
| 100 | Not obtained | Not obtained | Not obtained | Not obtained | Not attempted |
| 150 | Not obtained | Not obtained | Not obtained | Not obtained | Not attempted |
| 200 | Not obtained | Not obtained | Not obtained | Not obtained | Not attempted |

---

## Recommendations

| Value | Recommendation | Evidence |
|---|---|---|
| `BroadcastLimits.maxViewers` | **50 (interim/tentative — user decision 2026-09-27)** | Not evidence-backed as "safe." Chosen as a conservative round-number placeholder while the SCTP/DCEP root cause remains unconfirmed and this spike is paused. The harness itself never demonstrated 100% success at N=50 (best run: 42/50, 84%). Implement as a project constant so it can be raised without a design change once real beta data or a resumed spike provides real evidence. Revisit after Unit 9's real-world capacity work or a resumed Spike 2.1 |
| `presenceTimeout` | **60 seconds (interim/tentative — 2026-09-27)** | Not measured — the local Realtime load test could not be completed (see below). Derived from documented protocol behavior instead: Supabase Realtime's presence is built on Phoenix Channels, whose client heartbeat interval defaults to 30s; using 2x that (60s) as the staleness threshold is the standard convention for tolerating one missed heartbeat before declaring a peer gone, avoiding false "not currently broadcasting" transitions on a brief hiccup. Revisit with real measurement |
| `reconnectWindow` | **120 seconds (interim/tentative — 2026-09-27)** | Not measured — this is a product/UX judgment call, not purely technical: long enough to cover a typical mobile network handoff (e.g. wifi→cellular, per M-S2.2's scenario) without user action, short enough that a truly-gone viewer doesn't hold a capacity slot indefinitely against the tentative 50-viewer cap. No spike evidence backs this number |
| NFR-1.3 join-to-first-caption | **≤3 seconds (interim target, not measured)** | Aspirational target based on standard real-time-app UX thresholds (comparable to typical video-call connect-to-first-frame targets), not derived from this spike's data. Unit 5 should design toward this and validate it once real fan-out measurement resumes |
| NFR-1.3 reconnection | **≤5 seconds (interim target, not measured)** | Same basis as above — a target to design toward, not a measured result |

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| `wrtc` (Node) prebuilt binaries unavailable for local Node version | Low | **Confirmed hit.** Fixed by switching to `node-datachannel`, a maintained alternative with prebuilt binaries; API is callback-based rather than Promise/browser-shaped, `swarm.js` rewritten accordingly |
| macOS default entitlements block outbound sockets and non-sandbox file writes | Medium | **Confirmed hit.** Fixed: added `com.apple.security.network.client`; disabled `com.apple.security.app-sandbox` (acceptable for throwaway, never-distributed harness code) |
| Join success rate degrades with concurrent viewer count (N=50: 74-84% across 4 runs) while broadcaster reports 100% channels open | **High — narrowed, not yet confirmed or fixed** | STUN contention ruled out (local coturn, same failure rate). ICE/DTLS confirmed non-bottleneck via per-viewer state instrumentation (100% reach `ice: completed`). Failure is at the SCTP/DCEP layer. Pacing experiment (50ms vs 150ms vs unpaced) showed no monotonic trend — inconclusive with this sample size. Needs either repeated trials per config or direct libwebrtc-side DCEP logging |
| `node-datachannel`'s cleanup() segfaults on process exit | Low | **Confirmed hit.** Results are written before cleanup runs, so no data loss; worked around by skipping `cleanup()` and relying on `process.exit(0)` |
| Connection-storm artifact from simultaneous joins skewing latency | Medium | Partially mitigated — 250ms ramp reduced but did not eliminate the success-rate issue above; the two may be the same root cause |
| CPU/memory captured only as connection-churn snapshots, not sustained peak-N | Medium | Needs the `--dwellMs` methodology fix noted in the Fan-Out Measurements table footnote |
| `flutter_webrtc` desktop maturity unknown beyond N=50 | TBD | No crashes/dropped channels observed macOS N≤50; assessment incomplete |

---

## Exit Criteria Assessment

| Criterion | Status |
|-----------|--------|
| A cap is recommended with evidence | **INTERIM ONLY** — `maxViewers = 50` accepted as a tentative, explicitly-revisable placeholder (2026-09-27), not backed by evidence of safety at that scale. Root cause (broadcaster-side SCTP/DCEP handling under concurrent channel creation; STUN ruled out) narrowed but not confirmed. Spike paused before reaching a real evidence-based recommendation |
| TBD values (`presenceTimeout`, `reconnectWindow`, NFR-1.3 timings) are filled in | **INTERIM ONLY** — filled from documented Realtime/Phoenix protocol behavior and engineering judgment (2026-09-27), not measurement. The local Realtime load test itself remains blocked on an unresolved JWT signature issue (see Signaling/Presence Load Measurements) despite fixing 7 unrelated local-stack bugs along the way |
| Desktop `flutter_webrtc` risk is resolved or escalated | NOT MET — no crashes/dropped channels through N=50 on macOS, but neither resolved nor escalated; Windows/Linux and web legs not run; spike paused |

---

## Next Steps

**Paused 2026-09-27** — Units 3 and 5 proceed now using the interim `maxViewers = 50` placeholder above. Resume this list when real beta-testing data (per Unit 9) makes it worth revisiting, or sooner if capacity becomes a live concern before beta.

1. **Get statistical confidence on the pacing experiment** before concluding anything from it: rerun each of unpaced / 50ms / 150ms pacing several times (e.g. 5x each at N=50) and compare distributions, not single runs — the current single-run-per-config results (74-84%) don't distinguish a real effect from noise.
2. **In parallel or instead of (1)**, add direct DCEP-layer visibility: enable libwebrtc verbose logging on the broadcaster side (`flutter_webrtc` exposes native logging hooks) to see whether the DCEP handshake is actually stalling, timing out, or being dropped for the failed subset, rather than inferring it indirectly from the viewer-side state trail. This is more likely to produce a confirmed root cause than further black-box parameter sweeps.
3. Add `--dwellMs` to `viewer_swarm/swarm.js` (hold connections open post-success for sustained CPU/memory sampling) — still needed regardless of (1)/(2).
4. Once the root cause is confirmed and (if needed) mitigated, run N=100/150/200 on macOS.
5. Run the same N steps on Windows or Linux, and the web broadcaster (Chrome).
6. Resolve the Realtime JWT signature issue before running `realtime_load/` — likely needs either a different Realtime image version, or tracing the `joken`/JWT verification path with debug logging enabled (`nodeDataChannel`-style compiled-release opacity made this unproductive to chase further in this session).
7. Fill in the Executive Summary, Recommendations, and remaining Exit Criteria once all of the above are in.

---

## Impact on Construction Units

- **Unit 3 (Identity + Signaling)**: blocked on this spike's `presenceTimeout` recommendation.
- **Unit 5 (WebRTC Transport + Remote Output + Capacity)**: blocked on this spike's `maxViewers`, `reconnectWindow`, and NFR-1.3 recommendations, plus the desktop `flutter_webrtc` platform tiering.
- **NFR-8.3 platform tiering**: informs which desktop platforms Unit 5 fully supports vs. treats as degraded/experimental.
