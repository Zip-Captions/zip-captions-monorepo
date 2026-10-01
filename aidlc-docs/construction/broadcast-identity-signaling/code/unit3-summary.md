# Unit 3 (Broadcast Identity + Signaling) — Code Generation Summary

## Files Created

**zip_supabase**
- `migrations/20261001000000_broadcast_identity_signaling.sql` — `broadcast_identities` table + RLS, `resolve_broadcast_id`, `get_or_create_my_broadcast_id`, Realtime authorization policies on `realtime.messages`
- `migrations/20261001000001_fix_jwt_secret_mismatch.sql` — corrective migration, unrelated to this unit's own feature (see Deviations)

**zip_core**
- `lib/src/models/broadcast_id.dart`, `broadcast_link.dart`, `broadcast_resolution.dart`, `broadcast_status.dart`, `presence_snapshot.dart`, `signaling_message.dart`, `signaling_codec.dart`
- `lib/src/services/broadcast/broadcast_authorization_exception.dart`, `broadcast_identity_repository.dart`, `supabase_broadcast_identity_repository.dart`, `broadcast_resolver.dart`, `supabase_broadcast_resolver.dart`, `broadcast.dart` (aggregator)
- `lib/src/services/signaling/signaling_service.dart`, `status_channel.dart`, `session_signaling_channel.dart`, `supabase_signaling_service.dart`, `supabase_status_channel.dart`, `supabase_session_signaling_channel.dart`, `signaling.dart` (aggregator)
- `lib/src/providers/broadcast_identity_repository_provider.dart`, `signaling_service_provider.dart`, `broadcast_resolver_provider.dart` (+ generated `.g.dart`)
- `test/pbt/broadcast_id_test.dart`, `broadcast_link_test.dart`, `signaling_codec_test.dart`
- `test/services/broadcast/supabase_broadcast_identity_repository_test.dart`, `supabase_broadcast_resolver_test.dart`
- `test/services/signaling/supabase_signaling_service_test.dart`, `supabase_status_channel_test.dart`, `supabase_session_signaling_channel_test.dart`
- `test/providers/broadcast_identity_repository_provider_test.dart`, `signaling_service_provider_test.dart`, `broadcast_resolver_provider_test.dart`
- `test/integration/broadcast_identity_supabase_test.dart` — real local-stack integration test (new category for this project, see Deviations)
- `dart_test.yaml` — new file, tags/skips the integration test by default

## Files Modified

- `packages/zip_supabase/volumes/api/kong.yml` — new `rest-v1-resolve-broadcast-id` rate-limited route
- `packages/zip_supabase/docker-compose.yml` — `KONG_PLUGINS` allowlist + Kong `entrypoint` env-substitution fix (see Deviations)
- `packages/zip_supabase/.env.example` — `JWT_SECRET` typo fix (see Deviations)
- `packages/zip_core/lib/src/models/models.dart`, `services/services.dart`, `providers/providers.dart` (aggregators)
- `packages/zip_core/test/helpers/generators.dart` (new "Broadcast identity + signaling domain generators" section)
- `packages/zip_core/pubspec.yaml` (`meta` added as a direct dependency)

## Test Coverage

`zip_core` analyzes clean (`dart analyze --fatal-infos`) and the full suite passes (matching the project's real CI invocation, `flutter test` from within the package):

| Suite | Result |
|---|---|
| Unit/PBT/provider tests | 397 passing |
| `test/integration/broadcast_identity_supabase_test.dart` (real local Supabase stack) | 1 suite skipped by default (new `integration-supabase` tag); manually run and confirmed 5/5 passing against a live stack |

## Deviations From the Plan (all logged in `audit.md` and the plan file itself as they occurred)

1. **Execution order**: Step 8 (signaling service layer) was built before Step 6 (resolution layer), since `BroadcastResolver`'s implementation composes a `StatusChannel` per `logical-components.md`'s own dependency graph — Step 6 could not have been built first as originally sequenced.
2. **One design clarification resolved before Step 2**, not previously written down: SR-02 §3 says broadcast IDs are stored/compared case-sensitively (uppercase alphabet) but displayed lowercase. Decided `BroadcastId.parse`/`tryParse` normalize to canonical uppercase so a viewer pasting the lowercase-displayed code actually resolves — display-casing stays presentation-only.
3. **A real production bug found and fixed while writing `SupabaseStatusChannel`'s own tests**: `watch()`'s initial status emission was routed through an internal broadcast `StreamController` before any listener existed on it, so the first emission was silently dropped (broadcast streams don't buffer for late listeners) — every subscriber would see only *later* updates, never the current status. Fixed by adding the initial value directly to the `Stream.multi` controller instead.
4. **A genuine design inconsistency found in the already-approved SR-02**, flagged to and resolved by the user before Step 8: §4's RLS table restricted `status:{broadcast_id}` presence `SELECT` to the broadcaster only, directly contradicting §2's own described anonymous-resolution mechanism (which reads that same presence state for any caller). Corrected to `anon, authenticated` for `SELECT` (matching the channel's own `broadcast`-extension `SELECT` row); `INSERT` (tracking) stays broadcaster-only. SR-02 and the migration both updated with an inline note.
5. **`client.rpc<T>()`'s success path required a `Fake`-based `PostgrestFilterBuilder<T>` stand-in** (overriding only `then`) to unit-test without a real HTTP backend — the generic builder-chain return type can't be constructed directly, the same category of problem Unit 2 hit with `signInWithOAuth`.
6. **The repository/resolver layers' "unit tests" deliberately don't duplicate database-level correctness** (idempotence, uniqueness, RLS) already covered by Step 1's manual `psql` verification and Step 12's real integration test — they test only the Dart-side exception-mapping and composition logic, per `testable-properties.md`'s own split between pure-Dart PBT and stateful/integration-level properties.
7. **The Kong rate-limit (HTTP 429) detection heuristic in `SupabaseBroadcastResolver` is a best-effort guess**, not verified against a real 429 response (neither SR-02 nor Infrastructure Design pinned down the exact client-side detection mechanism, and Step 12's integration test didn't exercise this path). Fails safe to `resolutionFailed` if wrong. Flagged in `aidlc-state.md`'s Backlog.
8. **Found and fixed three pre-existing, unrelated bugs in Unit 4's shared local Supabase stack infrastructure** while making Step 12's integration test actually runnable (none caused by this unit's own deliverables, though the first was only surfaced by this unit adding a new Kong plugin reference):
   - Kong's `KONG_PLUGINS` allowlist in `docker-compose.yml` never included `rate-limiting`.
   - Kong's `kong.yml` `${ANON_KEY}`/`${SERVICE_ROLE_KEY}` placeholders were never actually substituted by Kong itself — fixed with a `sed`-based render step in the `kong` service's `entrypoint`.
   - A one-word typo in `.env.example`'s `JWT_SECRET` (missing the `your-` prefix from Supabase's actual canonical default) meant the bundled demo `ANON_KEY`/`SERVICE_ROLE_KEY` JWTs never verified against it — every JWT-checking call has silently failed since Unit 4 shipped. Fixed via a new corrective migration (forward-only convention) and the `.env.example` correction.

9. **CodeRabbit review on PR #24 found 4 real issues, all fixed** (2026-10-01): (a) the Kong rate-limit detection heuristic (Deviation 7) was wrong in exactly the way flagged as unverified — `postgrest` actually passes a 429 through as `PostgrestException.code == '429'`, not `null`; now matches both. (b) `SupabaseStatusChannel._ensureSubscribed()` permanently cached a transient subscribe failure forever, never recovering even after the channel's own automatic rejoin — fixed to track channel-start state separately from the per-attempt wait. (c) `watch()` could read presence before the first sync arrived (a separate protocol message, not bundled with the `subscribed` callback), misreading an already-live topic as offline — fixed to wait for the first sync. (d) **Major security finding**: the signaling-session presence `SELECT` RLS policy never actually checked ownership, contradicting its own name and `SessionSignalingChannel.presence`'s documented contract. The textbook fix (a persisted session-owner table) contradicts FR-2.6; flagged to the user, who chose to open the policy honestly instead and correct every place that claimed a false RLS guarantee, deferring enforcement to Unit 5's transport layer.

## Backlog Items Carried Forward (already recorded in `aidlc-state.md`)

- `BroadcastResolution.ResolutionFailed` needs a Unit 7 UI-rendering decision (from NFR Design).
- The Kong rate-limit-detection heuristic (Deviation 7 above) needs confirming against a real 429 response before Unit 3 is considered fully shipped.
- An intermittent 502 Bad Gateway from Kong→PostgREST under rapid sequential requests was observed during Step 12's manual integration-test runs (reproduced via `curl` too, affects the pre-existing catch-all REST route as well — not caused by this unit's own code). Not chased further; flagged for awareness.
