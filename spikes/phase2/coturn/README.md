# Spike 2.3: Coturn Alongside Supabase — Runbook

Throwaway harness. Never merged into `packages/zip_supabase` — see
`aidlc-docs/construction/spikes/spike-2.3-report.md` for the findings this
produced; that's the only durable output.

## Layout

- `turnserver.conf` — the **recommended** Coturn config (TURN REST
  shared-secret auth, payload-free logging, private-range relay denial,
  Prometheus metrics). This is the one to actually base Unit 4's
  Infrastructure Design on.
- `turnserver.test.conf` — identical, minus the `denied-peer-ip` rules.
  **Test-only.** All reachable peers in this local harness are private
  addresses, which the recommended config correctly rejects as relay
  targets — this variant exists purely to validate relay/NAT-traversal
  behavior in isolation from that (separately verified) denial behavior.
  Never use it as a real config.
- `docker-compose.yml` — Coturn + a two-container NAT simulation
  (`nat-gateway`, `nat-client`) that puts `nat-client` behind a simulated
  *symmetric* NAT (nftables `masquerade random,fully-random` — a new,
  effectively unpredictable external port per destination, the NAT
  behavior that breaks STUN-based P2P hole punching and is the reason TURN
  relay exists at all).
- `nat_sim/` — the two Dockerfiles + the gateway's NAT-setup entrypoint.

## Running it

```sh
cd spikes/phase2/coturn
docker compose up -d
```

**Required manual step** (Docker can't express this declaratively): give
`nat-client` a default route through `nat-gateway`, since the gateway
isn't Docker's own network gateway:

```sh
docker exec spike-nat-client ip route del default
docker exec spike-nat-client ip route add default via 10.200.1.2
```

Generate a TURN REST credential (matches `TurnCredentialService`'s fixed
`{username, credential, expiresAt, urls}` shape from Application Design):

```sh
python3 - <<'EOF'
import hmac, hashlib, base64, time
secret = "spike-2-3-throwaway-shared-secret-do-not-reuse"  # must match turnserver.conf's static-auth-secret
username = str(int(time.time()) + 3600)  # unix timestamp = expiry
credential = base64.b64encode(hmac.new(secret.encode(), username.encode(), hashlib.sha1).digest()).decode()
print(f"username={username}")
print(f"credential={credential}")
EOF
```

Run a full relay session from the NAT'd client:

```sh
docker exec spike-nat-client turnutils_uclient -v -y -m 2 \
  -u <username> -w <credential> 172.28.0.100
```

`-y` makes `turnutils_uclient` allocate, refresh, channel-bind, and
exchange test traffic with itself through the relay — the full TURN
lifecycle a WebRTC peer would exercise.

## Known environment-specific gotcha (Docker Desktop for Mac)

Coturn **cannot** use `network_mode: host` and still be reachable from
other containers on this platform. Found while debugging the relay test
hanging silently at "allocate sent" with no response, and no error on
either side: `network_mode: host` on Docker Desktop binds into the
LinuxKit VM's own network namespace — reachable via `127.0.0.1` from
*other host-networked containers* (same namespace), but **not** via
`host.docker.internal`/`192.168.65.254` from regular bridge-networked
containers, since that address path specifically routes to the real macOS
host, not to other processes inside the same VM. Confirmed via `tcpdump`
on the path with zero response packets ever arriving, reproduced
identically with no NAT simulation involved at all (a container on the
bridge network talking directly to the host-networked coturn container).
**Fixed here** by giving coturn a normal, fixed bridge-network address
instead. This is a macOS-dev-environment-only quirk — a real Linux Docker
host (the actual deployment target) doesn't have this VM layer, and
`network_mode: host` there binds directly to the host's real network
stack, reachable normally from any other container. Unit 4 Infrastructure
Design should use host networking (or a sufficiently wide host port range)
on the real deployment target; this spike's bridge-network workaround is
purely a local-reproduction convenience, not a deployment recommendation.

## Cleanup

```sh
docker compose down
rm -f logs/*.log
```
