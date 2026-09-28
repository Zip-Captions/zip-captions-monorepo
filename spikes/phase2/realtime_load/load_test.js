// Spike 2.1 — throwaway Supabase Realtime signaling/presence load test. Measures channel-join time
// and presence-sync time for N concurrent viewers against the local Supabase stack.
//
// Usage:
//   node load_test.js --url http://localhost:54321 --anonKey <local-anon-key> --channel spike-2.1-realtime --count 50
//
// While this runs, sample the Realtime container's resource usage in another terminal:
//   docker stats supabase-realtime --no-stream

const { createClient } = require('@supabase/supabase-js');

function parseArgs() {
  const args = {
    url: 'http://localhost:54321',
    anonKey: '',
    channel: 'spike-2.1-realtime',
    count: 25,
    rampMs: 50,
  };
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    const value = argv[i + 1];
    if (key === 'count' || key === 'rampMs') args[key] = Number(value);
    else args[key] = value;
  }
  return args;
}

function joinViewer(url, anonKey, channelName, viewerId) {
  return new Promise((resolve) => {
    const client = createClient(url, anonKey);
    const startedAt = Date.now();
    const result = { viewerId, joinMs: null, presenceSyncMs: null, error: null };

    const channel = client.channel(channelName, {
      config: { presence: { key: viewerId } },
    });

    const timeout = setTimeout(() => {
      result.error = result.error || 'timeout waiting for subscribe/presence sync';
      resolve(result);
    }, 20000);

    channel
      .on('presence', { event: 'sync' }, () => {
        if (result.presenceSyncMs === null) {
          result.presenceSyncMs = Date.now() - startedAt;
          clearTimeout(timeout);
          resolve(result);
        }
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          result.joinMs = Date.now() - startedAt;
          await channel.track({ viewerId, joinedAt: new Date().toISOString() });
        } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          result.error = status;
          clearTimeout(timeout);
          resolve(result);
        }
      });
  });
}

function percentile(sorted, p) {
  if (sorted.length === 0) return null;
  const idx = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[idx];
}

function summarize(label, values) {
  const sorted = values.filter((v) => v !== null).sort((a, b) => a - b);
  return {
    min: sorted[0] ?? null,
    p50: percentile(sorted, 50),
    p95: percentile(sorted, 95),
    max: sorted[sorted.length - 1] ?? null,
    label,
  };
}

async function main() {
  const { url, anonKey, channel, count, rampMs } = parseArgs();
  if (!anonKey) {
    console.error('Missing --anonKey. Get it from the local Supabase stack (see docs/TEST_SETUP.md).');
    process.exit(1);
  }

  console.log(`[realtime-load] joining ${count} viewers to "${channel}" on ${url}, ramp ${rampMs}ms`);
  const allStartedAt = Date.now();

  const promises = [];
  for (let i = 0; i < count; i++) {
    promises.push(joinViewer(url, anonKey, channel, `viewer-${i}`));
    // eslint-disable-next-line no-await-in-loop
    await new Promise((r) => setTimeout(r, rampMs));
  }

  const results = await Promise.all(promises);
  const totalMs = Date.now() - allStartedAt;
  const failed = results.filter((r) => r.error);

  const summary = {
    requested: count,
    succeeded: count - failed.length,
    failed: failed.length,
    failureReasons: [...new Set(failed.map((r) => r.error))],
    totalTimeAllJoinedMs: totalMs,
    joinTimeMs: summarize('join', results.map((r) => r.joinMs)),
    presenceSyncTimeMs: summarize('presenceSync', results.map((r) => r.presenceSyncMs)),
  };

  console.log('[realtime-load] summary:', JSON.stringify(summary, null, 2));

  const fs = require('fs');
  fs.writeFileSync(`results-${count}.json`, JSON.stringify({ ...summary, raw: results }, null, 2));
  console.log(`[realtime-load] wrote results-${count}.json`);

  process.exit(0);
}

main().catch((err) => {
  console.error('[realtime-load] fatal error:', err);
  process.exit(1);
});
