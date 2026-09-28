# Spike 2.1 — Broadcaster Fan-Out and Signaling Load

Throwaway harness. Nothing here is merged into any package (per `phase2-unit-of-work.md`, Q5:A). Results go into `aidlc-docs/construction/spikes/spike-2.1-report.md`.

## What this measures

1. **Broadcaster fan-out** (`fanout/`): CPU, memory, and join-to-first-message latency on a single broadcaster process holding N concurrent WebRTC data channels, N stepped through 25 / 50 / 100 / 150 / 200.
2. **Supabase Realtime signaling/presence load** (`realtime_load/`): join time and presence-sync time against the local Supabase stack with N viewers joining a channel concurrently, same N steps.

Both use ad hoc harness code, not the real `SignalingService`/`SessionSignalingChannel` — those don't exist yet (Unit 3 depends on this spike). The signaling relay here (`fanout/signaling_server/`) is a minimal throwaway WebSocket relay, not a design proposal.

## Prerequisites

- Node.js 18+ (for the signaling server, viewer swarm, and Realtime load test)
- Flutter SDK with desktop support enabled for macOS, and at least one of Windows or Linux (per the spike's platform coverage requirement)
- A Chromium-based browser for the web broadcaster run
- Local Supabase stack running (`packages/zip_supabase` docker-compose) for the Realtime load test
- `npm install` inside `fanout/viewer_swarm/` and `realtime_load/` before first run

## Part 1 — Broadcaster fan-out

### 1. Start the signaling relay

```
cd spikes/phase2/fanout/signaling_server
npm install
node server.js
```

Defaults to `ws://localhost:8090`. Override with `PORT=<port>`.

### 2. Start the broadcaster app

Run on each platform under test (repeat the whole procedure per platform):

```
cd spikes/phase2/fanout/broadcaster_app
flutter pub get
flutter run -d macos         # or: -d windows / -d linux / -d chrome
```

Enter the signaling relay's URL and broadcast ID (`spike-2.1` by default) in the app, tap **Connect**. The app self-reports:
- Resident memory (`ProcessInfo.currentRss`, sampled every 2s) — desktop only, not available on web
- Per-viewer join-to-first-message latency (measured from data channel `onOpen` to the first echoed message the viewer sends back)
- Active data channel count

**CPU is not self-measured** (unreliable from inside the Flutter process) — sample it externally during each run:
- macOS: Activity Monitor, or `top -pid $(pgrep -f broadcaster_app)`
- Windows: Task Manager → Details tab
- Linux: `top -p $(pgrep -f broadcaster_app)`
- Web: Chrome Task Manager (Shift+Esc)

**Known risk**: the `viewer_swarm`'s `wrtc` dependency ships prebuilt binaries that can lag behind current Node versions. If `npm install` can't fetch a prebuilt binary for your platform, swap in `node-datachannel` (similar API) rather than spending spike time debugging `wrtc`'s build — this harness is throwaway.

### 3. Run the viewer swarm at each N

```
cd spikes/phase2/fanout/viewer_swarm
npm install
node swarm.js --relay ws://localhost:8090 --broadcastId spike-2.1 --count 25 --rampMs 100
```

Repeat with `--count 50`, `100`, `150`, `200`. `--rampMs` staggers viewer joins to avoid a connection-storm artifact skewing latency; 100ms between joins is the default.

The swarm prints a summary (join success rate, and latency min/p50/p95/max) and writes `results-<count>.json` in the same directory. Record the broadcaster's self-reported memory and your externally-sampled CPU alongside each run in the report.

### 4. Record results

For each platform × N combination, fill in the corresponding row in `spike-2.1-report.md`'s measurement tables.

## Part 2 — Supabase Realtime signaling/presence load

```
cd spikes/phase2/realtime_load
npm install
node load_test.js --url http://localhost:54321 --anonKey <local-anon-key> --channel spike-2.1-realtime --count 25
```

Get `<local-anon-key>` from `packages/zip_supabase`'s local dev credentials (see `docs/TEST_SETUP.md`). Repeat at `count` 50/100/150/200. While it runs, sample the Realtime container's resource usage:

```
docker stats supabase-realtime --no-stream
```

The script reports per-viewer channel-join time and presence-sync time (min/p50/p95/max), and total time for all N to reach synced presence.

## Deliverables checklist (from `phase2-unit-of-work.md`)

- [ ] Measurements per platform for N = 25, 50, 100, 150, 200 (fan-out + Realtime)
- [ ] Recommended `BroadcastLimits.maxViewers`, `presenceTimeout`, `reconnectWindow`, and NFR-1.3 timings (join-to-first-caption, reconnection) — derived from the above
- [ ] `flutter_webrtc` data-channel maturity assessment on Windows or Linux desktop, with a platform tiering recommendation (NFR-8.3) — qualitative notes during the desktop run (crashes, dropped channels, platform-specific quirks)
- [ ] Fill in `aidlc-docs/construction/spikes/spike-2.1-report.md`
