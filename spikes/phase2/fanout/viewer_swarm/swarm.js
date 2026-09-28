// Spike 2.1 — throwaway synthetic viewer swarm. Spins up N WebRTC peer connections against the
// broadcaster_app harness through the throwaway signaling relay, and measures join-to-first-message
// latency (time from data channel open to receiving the broadcaster's first synthetic caption).
//
// Usage:
//   node swarm.js --relay ws://localhost:8090 --broadcastId spike-2.1 --count 50 --rampMs 100
//
// Uses `node-datachannel` (libdatachannel bindings), not `wrtc` — `wrtc` needs `node-pre-gyp` to
// fetch its prebuilt binary, which this environment doesn't have. `node-datachannel` ships prebuilt
// binaries per-platform as optionalDependencies and installed cleanly. Its API is callback-based
// (onLocalDescription/onLocalCandidate/onDataChannel), not the Promise-based browser RTCPeerConnection
// shape — see the createViewer() below.

const WebSocket = require('ws');
const nodeDataChannel = require('node-datachannel');

function parseArgs() {
  const args = {
    relay: 'ws://localhost:8090',
    broadcastId: 'spike-2.1',
    count: 25,
    rampMs: 100,
    timeoutMs: 20000,
    stun: 'stun:stun.l.google.com:19302',
  };
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    const value = argv[i + 1];
    if (key === 'count' || key === 'rampMs' || key === 'timeoutMs') args[key] = Number(value);
    else args[key] = value;
  }
  return args;
}

function createViewer(relayUrl, broadcastId, viewerId, timeoutMs, stunUrl) {
  return new Promise((resolve) => {
    const ws = new WebSocket(relayUrl);
    const pc = new nodeDataChannel.PeerConnection(viewerId, {
      iceServers: [stunUrl],
    });

    const result = {
      viewerId,
      connected: false,
      channelOpenedAt: null,
      firstMessageLatencyMs: null,
      error: null,
      // Diagnostic trail for root-causing timeouts — see spike-2.1-report.md's STUN-contention
      // finding, which this instrumentation was added to actually pin down.
      stateLog: [],
    };

    const startedAt = Date.now();
    const logState = (label, state) => result.stateLog.push({ tMs: Date.now() - startedAt, label, state });
    let finished = false;
    const finish = () => {
      if (finished) return;
      finished = true;
      pc.close();
      ws.close();
      resolve(result);
    };
    const connectTimeout = setTimeout(() => {
      result.error = result.error || 'timeout waiting for connection';
      finish();
    }, timeoutMs);

    pc.onStateChange((state) => logState('pc', state));
    pc.onIceStateChange((state) => logState('ice', state));
    pc.onSignalingStateChange((state) => logState('signaling', state));
    pc.onGatheringStateChange((state) => logState('gathering', state));

    pc.onLocalDescription((sdp, type) => {
      logState('localDescription', type);
      ws.send(JSON.stringify({ type, viewerId, sdp: { sdp, type } }));
    });
    pc.onLocalCandidate((candidate, mid) => {
      ws.send(JSON.stringify({ type: 'ice', viewerId, candidate: { candidate, sdpMid: mid } }));
    });
    pc.onDataChannel((dc) => {
      dc.onOpen(() => {
        result.connected = true;
        result.channelOpenedAt = Date.now() - startedAt;
      });
      dc.onMessage(() => {
        if (result.firstMessageLatencyMs === null && result.channelOpenedAt !== null) {
          result.firstMessageLatencyMs = Date.now() - startedAt - result.channelOpenedAt;
          clearTimeout(connectTimeout);
          finish();
        }
      });
    });

    ws.on('open', () => {
      ws.send(JSON.stringify({ type: 'viewer-hello', broadcastId, viewerId }));
    });

    ws.on('message', (raw) => {
      const msg = JSON.parse(raw.toString());
      if (msg.type === 'error') {
        result.error = msg.reason;
        clearTimeout(connectTimeout);
        finish();
        return;
      }
      if (msg.type === 'offer' && msg.from === 'broadcaster') {
        pc.setRemoteDescription(msg.sdp.sdp, msg.sdp.type);
      } else if (msg.type === 'ice' && msg.from === 'broadcaster') {
        try {
          pc.addRemoteCandidate(msg.candidate.candidate, msg.candidate.sdpMid);
        } catch {
          // Ignore late/duplicate candidates — not significant for this load test's measurements.
        }
      }
    });

    ws.on('error', (err) => {
      result.error = result.error || `ws error: ${err.message}`;
    });
  });
}

function percentile(sorted, p) {
  if (sorted.length === 0) return null;
  const idx = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[idx];
}

async function main() {
  const { relay, broadcastId, count, rampMs, timeoutMs, stun } = parseArgs();
  console.log(`[swarm] spawning ${count} viewers against ${relay} (broadcastId="${broadcastId}"), ramp ${rampMs}ms, timeout ${timeoutMs}ms, stun ${stun}`);

  const viewerPromises = [];
  for (let i = 0; i < count; i++) {
    viewerPromises.push(createViewer(relay, broadcastId, `swarm-viewer-${i}`, timeoutMs, stun));
    // eslint-disable-next-line no-await-in-loop
    await new Promise((r) => setTimeout(r, rampMs));
  }

  const results = await Promise.all(viewerPromises);
  const succeeded = results.filter((r) => r.firstMessageLatencyMs !== null);
  const failed = results.filter((r) => r.firstMessageLatencyMs === null);
  const latencies = succeeded.map((r) => r.firstMessageLatencyMs).sort((a, b) => a - b);

  const summary = {
    requested: count,
    succeeded: succeeded.length,
    failed: failed.length,
    failureReasons: [...new Set(failed.map((r) => r.error || 'unknown'))],
    latencyMs: {
      min: latencies[0] ?? null,
      p50: percentile(latencies, 50),
      p95: percentile(latencies, 95),
      max: latencies[latencies.length - 1] ?? null,
    },
  };

  console.log('[swarm] summary:', JSON.stringify(summary, null, 2));

  const fs = require('fs');
  fs.writeFileSync(
    `results-${count}.json`,
    JSON.stringify({ ...summary, raw: results }, null, 2),
  );
  console.log(`[swarm] wrote results-${count}.json`);

  // Note: nodeDataChannel.cleanup() segfaults on process exit in this environment (native addon
  // teardown issue, not a data-correctness problem — results are already written above). Skipping
  // it and relying on process.exit(0) to tear down the process is the pragmatic fix for throwaway
  // harness code; not worth debugging the native addon's shutdown path for a spike.
  process.exit(0);
}

main().catch((err) => {
  console.error('[swarm] fatal error:', err);
  process.exit(1);
});
