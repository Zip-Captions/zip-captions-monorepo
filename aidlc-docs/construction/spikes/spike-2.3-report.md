# Spike 2.3 Report: Coturn Alongside Supabase

**Date**: 2026-10-02
**Status**: COMPLETE. All three exit criteria met: TURN relay shown working through a symmetric-NAT simulation, a credential-issuing mechanism is recommended, and the log configuration has been checked for payload-free output.
**Scope**: Coturn deployed next to the Supabase stack — resource usage, configuration (payload-free logging, private-range relay denial), the ephemeral TURN credential mechanism, TURN relay through symmetric NAT, and TURN load at a smoke-test scale.

---

## Executive Summary

**Recommended mechanism confirmed working end-to-end**: the TURN REST shared-secret scheme (Coturn's `use-auth-secret` mode) correctly issues and validates time-limited `{username, credential}` pairs matching `TurnCredentialService`'s fixed shape from Application Design (`username`, `credential`, `expiresAt`, `urls`) — no database or admin API needed, just an HMAC-SHA1 of a timestamp against a shared secret.

**TURN relay through symmetric NAT: proven, not just asserted.** A client was placed behind a deliberately hostile, simulated symmetric NAT (nftables `masquerade random,fully-random` — a new, unpredictable external port per destination, the exact behavior that defeats STUN-based P2P hole punching). A full TURN session from that client — allocate, refresh, four channel binds, and sustained data relay — completed with **zero packet loss** (20/20 messages sent and received). This is the core justification for needing TURN at all, and it held up.

**Private-range relay denial confirmed working, twice, independently**: Coturn correctly rejected both a `CreatePermission` and (separately, against the NAT'd client) a `ChannelBind` targeting a private-range peer with `403 Forbidden IP` in both cases — the recommended config's `denied-peer-ip` rules do what they're supposed to.

**Payload-free logging**: confirmed by construction, not by inspecting logged packet content — `simple-log` + no `-v`/`-V` verbosity means Coturn's log level never descends to per-packet detail. No payload bytes were ever written to `turnserver.log` in any test run (the log file's actual content, across every run in this spike, contains only startup/INFO/DEBUG lines — see `spikes/phase2/coturn/logs/` history during this investigation, not preserved as an artifact since it's throwaway).

**Resource usage at smoke scale**: idle Coturn ≈ 7 MiB RAM, negligible CPU. Under a 10-concurrent-client burst (each opening ~5 relay allocations via `turnutils_uclient -y`), ≈ 12 MiB RAM, CPU still under 0.2%. **Not a full 200-viewer-scale load test** (see Recommendations) — time was spent on the symmetric-NAT proof and a real environment-specific blocker instead, judged the higher-value use of this spike's effort.

**One real bug found and fixed in the spike harness itself** (not a measurement finding, but something anyone reproducing this would also hit): on Docker Desktop for Mac, `network_mode: host` binds a container into the LinuxKit VM's own network namespace, which is **not** reachable from regular bridge-networked containers via `host.docker.internal`/`192.168.65.254` — that address path routes specifically to the real macOS host, not to other processes sharing the VM. This caused TURN requests to leave correctly and simply never get a response, with no error on either side — confirmed via `tcpdump` showing zero reply packets, reproduced with no NAT simulation in the path at all. Fixed by giving Coturn a normal bridge-network address for this local harness. **This is a macOS-Docker-Desktop-only quirk**, not relevant to the real Linux deployment target, where `network_mode: host` binds directly to the host's actual network stack.

**One real config bug found under load**: the spike's `min-port=49152 / max-port=49252` relay-port range (100 ports) was exhausted by just 10 concurrent clients × ~5 allocations each, producing `create_relay_ioa_sockets: no available ports` in Coturn's log. This is a sizing bug in the spike's own test config, not a Coturn limitation — see Recommendations for the real range to use.

---

## Methodology

Full harness: `spikes/phase2/coturn/` (throwaway, never merged — see its `README.md` for exact run steps).

- **Coturn**: `coturn/coturn:4.6.2`, configured via `turnserver.conf` (the recommended config — TURN REST shared-secret auth, payload-free logging, private-range denial, Prometheus metrics) and a second `turnserver.test.conf` variant (denial rules removed) used only to validate relay/NAT behavior against peers that are necessarily private addresses in this local harness — the denial behavior itself was validated separately, against the real config, and holds regardless of which variant relay/NAT testing used.
- **Symmetric-NAT simulation**: a `nat-gateway` container (nftables, `NET_ADMIN`) sits between `nat-client` and everything else, applying `masquerade random,fully-random` — nftables' documented mechanism for endpoint-dependent (symmetric) port mapping, as opposed to trying to preserve the client's original source port. `nat-client` has no route out except through this gateway.
- **Relay/credential testing**: Coturn's own bundled `turnutils_uclient` (via the Debian `coturn` package, which also ships `turnutils_peer`/`turnutils_natdiscovery`/`turnutils_stunclient`), run from inside `nat-client` — i.e., genuinely from behind the simulated NAT, not just asserted.
- **Credential generation**: a short Python script implementing the TURN REST shared-secret scheme directly (HMAC-SHA1 of a unix-timestamp-as-expiry against Coturn's `static-auth-secret`), matching exactly what a real `TurnCredentialService` implementation would do server-side.

### What was *not* covered, and why

- **Full 200-client load test** (matching Spike 2.1's fan-out scale): not attempted. Given limited spike time, priority went to proving the harder, more novel, more load-bearing claim (TURN actually works through a hostile NAT) and to resolving the Docker Desktop host-networking blocker that would have silently invalidated *any* further measurement if left undiagnosed. A real load test at target scale is a reasonable Unit 4/Unit 9 follow-up (see Recommendations).
- **NAT type formally classified via RFC 5780** (`turnutils_natdiscovery`'s behavior-discovery mode): attempted, but requires Coturn configured with a second alternate listening address/port to report `OTHER-ADDRESS`, which wasn't set up here. Not pursued further since the simulated NAT's actual *behavior* (endpoint-dependent port mapping via `random,fully-random`) is independently well-documented and directly matches the symmetric classification by construction, not just by inference — formally classifying it added no new information worth the setup cost.
- **TLS (`tls-listening-port=5349`)**: configured but not exercised in any test — all testing used plain UDP/TCP STUN/TURN.
- **Collision, filtering, and mapping-lifetime NAT behaviors**: only mapping behavior (the symmetric case) was simulated. The other `turnutils_natdiscovery` dimensions weren't explored, since the mapping-behavior case is the one that actually determines whether TURN relay (vs. direct P2P) is needed at all.

---

## Recommended Coturn Configuration

See `spikes/phase2/coturn/turnserver.conf` in full — the key decisions, each already validated above:

| Setting | Value | Rationale |
|---|---|---|
| Credential mechanism | `use-auth-secret` + `static-auth-secret` (TURN REST shared-secret) | No database/admin API; matches `TurnCredentialService`'s fixed shape exactly; validated end-to-end including through NAT. |
| Logging | `simple-log`, no `-v`/`-V` | Payload-free by construction — the log level never reaches per-packet detail. |
| Relay target denial | `denied-peer-ip` covering all RFC 1918 + loopback + link-local + CGNAT + documentation/benchmark ranges | Confirmed working (two independent `403 Forbidden IP` rejections) — prevents Coturn being used to relay into internal networks (SSRF-adjacent risk). |
| Metrics | `prometheus` | Built-in exporter, no extra sidecar needed. |
| Relay port range | **Needs widening from this spike's `49152–49252` (100 ports)** | See Recommendations — 100 ports was exhausted by a 10-client smoke test. |

---

## Recommendations for Unit 4 Infrastructure Design (SR-03)

1. **Credential mechanism**: adopt the TURN REST shared-secret scheme as validated here. The shared secret itself needs a real secrets-management decision (not a literal config-file string, unlike this throwaway spike) — Unit 4's own job, informed by whatever pattern `packages/zip_supabase`'s other secrets (`JWT_SECRET`, etc.) already use.
2. **Relay port range**: widen significantly from this spike's accidentally-narrow 100-port range. Coturn's own documentation and common deployments use the full ephemeral range (`49152–65535`, ~16K ports) precisely because each client relay allocation consumes one port for the session's lifetime — Unit 4 should size this against the real expected concurrent-viewer target (Spike 2.1's interim `maxViewers=50`, revisable), with meaningful headroom.
3. **Networking mode for the real deployment**: use `network_mode: host` (or equivalent) on the actual Linux deployment target, as originally intended — this spike's bridge-network workaround was a Docker-Desktop-for-Mac-only necessity, not a deployment recommendation. Confirm host networking behaves as expected in whatever the actual target environment is (a VM, bare metal, or a container platform like ECS/Kubernetes — each has different host-networking semantics worth a quick sanity check before relying on it).
4. **Private-range denial**: adopt the `denied-peer-ip` list as validated here verbatim; it's a standard, well-tested range list, not something to hand-roll per deployment.
5. **A real load test at target scale** (50–200 concurrent viewers, matching Spike 2.1's cap) is still open — this spike only smoke-tested at N=10. If Unit 4 or Unit 9 has NAT-traversal-at-scale concerns, the harness here (`spikes/phase2/coturn/`) is reusable as a starting point, per this project's "NAT simulation method... reusable in Unit 9" deliverable.
6. **`TurnCredentialService`'s issuing endpoint location** ("zip_supabase or stack, per Spike 2.3" — `phase2-components.md`): this spike validated the *mechanism* (HMAC-SHA1 shared-secret) but not *where* it should live. Given the shared secret must never reach the client, and `zip_supabase` already has an established pattern for backend-only secrets, a Postgres function (`SECURITY DEFINER`, mirroring `resolve_broadcast_id`'s precedent from Unit 3) or a Supabase Edge Function are both plausible — Unit 4's own Infrastructure Design should decide, informed by whichever pattern keeps the shared secret furthest from any client-reachable surface.

---

## Artifacts

- Harness: `spikes/phase2/coturn/` (branch `spike/2.3-coturn-alongside-supabase`, never merged — thrown away per this project's spike convention; kept on its own branch at `origin` for reference/reproducibility only).
- This report: the only durable output, merged to `develop` via its own docs-only PR.
