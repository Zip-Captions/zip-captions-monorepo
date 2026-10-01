# Logical Components — Broadcast Identity + Signaling (Unit 3)

## Package Placement

`zip_supabase` is TypeScript/Deno + SQL only (per `AGENTS.md`) — not a Dart package.
Mirroring Unit 2's `SupabaseAuthService` precedent exactly: all Dart types and
implementations live in `zip_core`; `zip_supabase` gets only the migration.

| Component | Package | Kind | Responsibility |
|---|---|---|---|
| Migration: `broadcast_identities` table, RLS policies, `resolve_broadcast_id`, `get_or_create_my_broadcast_id` | `zip_supabase` | SQL migration | No Dart code — schema, RLS, and the two SQL functions per SR-02. |
| `BroadcastId` | `zip_core` | value object | Validated Crockford-Base32 6-char code (SR-02 §3). |
| `BroadcastLink` | `zip_core` | parsing utility | Boundary between free-form input and a validated `BroadcastId`. |
| `BroadcastResolution` | `zip_core` | sealed model | `NotFound \| Offline \| Live \| RateLimited \| ResolutionFailed` (extended at this stage — Q2). |
| `PresenceSnapshot` / `BroadcastStatus` | `zip_core` | value models | Presence-derived viewer count / live-offline signal. |
| `BroadcastIdentityRepository` | `zip_core` | interface | `getOrCreateMine()`. |
| `SupabaseBroadcastIdentityRepository` | `zip_core` | impl (Adapter) | Calls `get_or_create_my_broadcast_id` via `supabaseClientProvider`; maps RLS rejections to `BroadcastAuthorizationException` (Q1). |
| `BroadcastResolver` | `zip_core` | interface | `resolve(BroadcastId)`. |
| its implementation | `zip_core` | impl | Two-step resolution (SR-02 §2): `resolve_broadcast_id` RPC, then a `status:{broadcast_id}` presence read; step-2 failure → `ResolutionFailed`, not `Offline`. |
| `SignalingService` | `zip_core` | interface | Factory for `StatusChannel`/`SessionSignalingChannel`. |
| `SupabaseSignalingService` | `zip_core` | impl (Adapter) | Creates `private: true` Realtime channels; maps RLS rejections to `BroadcastAuthorizationException`. |
| `StatusChannel`, `SessionSignalingChannel` | `zip_core` | impl | Returned by `SupabaseSignalingService`. |
| `SignalingMessage` (sealed) / `SignalingCodec` | `zip_core` | pure Dart model + codec | Zero Supabase coupling — shared protocol shape Unit 5/7 also depend on. Never-throws `decode` (Rule 4). |
| `BroadcastAuthorizationException` | `zip_core` | exception type | New this stage (Q1) — wraps any RLS/permission-denied rejection. |

## Integration Points

- `SupabaseBroadcastIdentityRepository`/`SupabaseSignalingService` → `supabaseClientProvider` (Unit 2's provider, reused as-is — no change to it).
- `BroadcastResolver`'s implementation → both `SupabaseBroadcastIdentityRepository`'s client access (for the RPC call) and a `StatusChannel` (for the presence read) — composing two of this unit's own components, not a new external dependency.
- `SignalingCodec` has no dependency on anything else in this unit — the one deliberately platform-agnostic piece, since Unit 5 and Unit 7 both need to decode/encode the same wire shape without depending on Supabase-specific types.

## Dependency Direction

```
zip_supabase (migration: table, RLS, 2 SQL functions — no Dart, schema/policy contract only)
        ▲
        │ (assumed schema — verified via integration tests, not a code dependency)
        │
zip_core:
  BroadcastIdentityRepository ─▶ SupabaseBroadcastIdentityRepository ─▶ supabaseClientProvider
  BroadcastResolver ─▶ (SupabaseBroadcastIdentityRepository's client, StatusChannel)
  SignalingService ─▶ SupabaseSignalingService ─▶ supabaseClientProvider
  SignalingMessage / SignalingCodec ─▶ (nothing — pure Dart)
  BroadcastAuthorizationException ─▶ (nothing — plain exception type)
```

Not yet wired (explicitly out of this unit): Unit 5's message-type authorization
enforcement, Unit 5's `ViewerAdmission` capacity logic, Unit 6/7's consumption of
`BroadcastResolution.ResolutionFailed` in their own UI.
