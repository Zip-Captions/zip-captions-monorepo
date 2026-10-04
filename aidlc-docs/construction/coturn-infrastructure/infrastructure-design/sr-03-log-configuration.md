# SR-03: Coturn Log Configuration Review

**Stories**: S-12 (Coturn Infrastructure) | **Blocks**: Unit 4 Code Generation
**Area**: Infrastructure logging configuration for a service that relays live WebRTC
media/data traffic (AGENTS.md: logging configuration touching in-transit user
content — pre-approval required)
**FR/NFR**: SR-03 (payload-free logging), NFR Requirements Security Q6 (metrics
exposure)

This document is the human-approval gate required by AGENTS.md before Coturn's logging
configuration ships. It records the configuration Spike 2.3 validated and this unit's
Infrastructure Design finalizes.

## 1. The Risk Being Reviewed

Coturn relays WebRTC media/data channel traffic between peers (broadcaster and viewers)
as part of this project's NAT-traversal story. A TURN server that logs at too high a
verbosity can capture the *content* of relayed packets — caption text, in this project's
case — which must never end up in a log file. This review exists specifically to confirm
the shipped configuration cannot do that, independent of the broader credential/RLS
security reviews already covered by SR-01/SR-02.

## 2. Configuration Under Review

```
log-file=/var/log/turnserver/turnserver.log
no-stdout-log
simple-log
```

No `-v` (verbose) or `-V` (Verbose) flag is set anywhere in the shipped config or the
`command:` override in `docker-compose.yml`. Per Coturn's own logging implementation,
verbosity level is what gates whether per-packet/per-message content is ever written to
the log — the default/`simple-log` level only emits connection lifecycle events
(allocate, refresh, channel-bind, session start/end) and server startup/error messages,
never the relayed payload bytes themselves.

## 3. Verification (Spike 2.3, 2026-10-02)

This is not an assertion taken on faith — it was checked directly, repeatedly, across
every test run in Spike 2.3's harness:

- Every allocate/refresh/channel-bind/relay test (including the full symmetric-NAT
  relay-through-NAT proof — 20/20 messages sent and received) was run against this exact
  logging configuration.
- The resulting `turnserver.log` content, inspected after each run, contained only
  `INFO`/`DEBUG`/`WARNING` lines about server startup, relay-address discovery, and
  session lifecycle — never the content of any relayed message, STUN/TURN credential
  value, or peer address payload.
- The one piece of genuinely sensitive data this unit's design touches — the TURN
  REST shared secret (`app.settings.turn_shared_secret`, Infrastructure Design Q2) — is
  never passed through Coturn's own logging path at all; it's consumed directly by
  Coturn's authentication code to validate a credential, not logged as part of request
  handling at any verbosity level this config enables.

## 4. Metrics Exposure (restated from NFR Requirements Q6)

The Prometheus metrics endpoint (`prometheus` config directive) is internal-only — not
published to the host, matching this project's existing `127.0.0.1`-only posture for
anything without a current external consumer. Metrics themselves (allocation counts,
port utilization, session counts) carry no payload content and are a separate exposure
surface from the log file reviewed above; noted here for completeness since both are
part of "what Coturn makes observable."

## 5. Scope Boundary

This review covers *logging* specifically, per this unit's definition
(`phase2-unit-of-work.md`: "Infrastructure Design produces the SR-03 log configuration
document"). The credential-issuing mechanism's own security properties (shared-secret
handling, TTL, least-privilege function design) are covered by this unit's NFR
Requirements (Q4, Q5) and NFR Design, not re-litigated here. The private-range relay
denial rules are Spike 2.3's own validated finding, carried forward unchanged.

## 6. Approval

- [x] **Approved** — this logging configuration may proceed to Code Generation for Unit
      4.

Approved by: James Petersen  Date: 2026-10-03
