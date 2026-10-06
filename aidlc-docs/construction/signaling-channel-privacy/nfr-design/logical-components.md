# Logical Components — Signaling Channel Privacy (Unit 3.1)

## Package Placement

`zip_supabase` gets only the new migration (RLS policy changes — no new SQL function,
per this unit's own "no `SECURITY DEFINER` needed" NFR Requirements finding). All Dart
types/implementations live in `zip_core`, in the **same directory** Unit 3 already
uses (`lib/src/services/signaling/`) — no new directory for this unit.

## Component List

| Component | Package | Kind | Responsibility |
|---|---|---|---|
| New migration | `zip_supabase` | SQL (RLS only) | Drops the superseded `signaling:{session_id}` broadcast/presence policies; adds the lobby (ownership-checked SELECT, open INSERT) and per-viewer (symmetric, open) policies per SR-04 §3. |
| `LobbyChannel` | `zip_core` | interface | `open()`, `sendJoinRequest()` (viewer-facing), `joinRequests` stream (broadcaster-facing only), `close()`. |
| `SupabaseLobbyChannel` | `zip_core` | impl | Realtime-backed, keyed by `broadcast_id`. **Corrected during Code Generation**: one concrete class, not a broadcaster/viewer split — a viewer-constructed instance that listens to `joinRequests` simply receives nothing, because RLS's ownership check drops it server-side. The enforcement is RLS, not an interface-level restriction. |
| `SessionSignalingChannel` (revised) | `zip_core` | interface | Same shape as Unit 3's, minus `presence`; now opened per `(sessionId, peerId)` instead of per `(sessionId, role)`. |
| `SupabaseSessionSignalingChannel` (revised) | `zip_core` | impl | Drops the `track()`/`onPresenceSync` wiring entirely (Q5/Rule 6 — presence never reintroduced). |
| `SignalingService` (revised) | `zip_core` | interface | Gains `lobbyChannel(BroadcastId)`; `sessionChannel` signature changes to `(String sessionId, String peerId)`. |
| `SupabaseSignalingService` (revised) | `zip_core` | impl | Constructs the two revised channel types above; `statusChannel` unchanged. |
| `peerId` generation | `zip_core` | utility function | A single function generating a 128-bit-entropy random `String` — not a validated value-object class (domain-entities.md: no canonical format to enforce beyond entropy). |

## Integration Points

- `SupabaseLobbyChannel`/`SupabaseSessionSignalingChannel` → `supabaseClientProvider`
  (Unit 2's provider, reused as-is — no change).
- Unit 5's `WebRtcBroadcastTransport`/`WebRtcViewerTransport` → this unit's revised
  `SignalingService` (replacing the pre-pause assumption of the old single-channel
  shape — Unit 5's own `BroadcastTransportContext`/`ViewerTransportContext` will be
  revisited against this unit's actual shipped interfaces once Unit 5 resumes).
- Unit 6's dashboard (not yet designed) → `BroadcastTransport.viewers` (Unit 5) for the
  viewer count, **not** anything from this unit — flagged in this unit's own Functional
  Design (Q5) for Unit 6 to pick up.

## Dependency Direction

```
zip_supabase (migration — RLS only, no function; no Dart)
        ▲ (schema/channel-pattern contract only, no code dependency)
        │
zip_core:
  SignalingService ─▶ SupabaseSignalingService ─▶ (SupabaseLobbyChannel,
                                                     SupabaseSessionSignalingChannel)
  LobbyChannel ─▶ SupabaseLobbyChannel ─▶ supabaseClientProvider
  SessionSignalingChannel ─▶ SupabaseSessionSignalingChannel ─▶ supabaseClientProvider
  peerId generation ─▶ (nothing — pure Dart utility)
```

Not yet wired (explicitly out of this unit, per its own blocking relationship): Unit 5's
transport layer consuming these revised interfaces — that's the resumption work once
this unit ships, not something this unit does itself.
