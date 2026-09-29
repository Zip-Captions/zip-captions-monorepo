# Unit 2 (Broadcaster Auth) — Code Generation Summary

## Files Created

**zip_core**
- `lib/src/models/auth_state.dart`, `auth_failure.dart`, `auth_provider_option.dart`
- `lib/src/services/auth/auth_service.dart`, `secure_desktop_local_storage.dart`, `supabase_auth_service.dart`, `auth.dart` (aggregator)
- `lib/src/providers/supabase_client_provider.dart`, `auth_service_provider.dart`, `auth_notifier.dart`
- `lib/src/constants/supabase_config.dart`
- `test/models/auth_state_test.dart`, `auth_failure_test.dart`, `auth_provider_option_test.dart`
- `test/services/auth/secure_desktop_local_storage_test.dart`, `supabase_auth_service_test.dart`
- `test/providers/auth_notifier_test.dart`
- `test/pbt/auth_state_machine_properties_test.dart`, `auth_failure_mapping_properties_test.dart`
- `test/helpers/fake_auth_service.dart`

**zip_broadcast**
- `lib/src/auth/auth_provider_config.dart`
- `lib/src/screens/account_section.dart`
- `test/widgets/account_section_test.dart`

## Files Modified

- `packages/zip_core/lib/zip_core.dart` aggregators: `models.dart`, `providers.dart`, `services.dart`
- `packages/zip_core/test/helpers/generators.dart` (added `AuthCommand` + generator)
- `packages/{zip_core,zip_broadcast,zip_captions}/pubspec.yaml` (new dependencies)
- `packages/{zip_broadcast,zip_captions}/lib/main.dart` (`Supabase.initialize`, provider overrides)
- `packages/zip_broadcast/l10n/arb/app_en.arb` (sign-in copy strings)
- `packages/zip_broadcast/macos/Runner/Info.plist`, `windows/runner/main.cpp` (OAuth redirect scheme)

## Test Coverage

All four packages analyze clean (`dart analyze --fatal-infos`, zero warnings/infos) and all test suites pass:

| Package | Tests |
|---|---|
| zip_core | 361 (incl. the two new auth PBT suites) |
| zip_broadcast | 100 |
| zip_captions | 71 |

## Deviations From the Plan (all logged in `audit.md` and the plan file itself as they occurred)

1. **Two design corrections found during Code Generation's own API verification** (before any Qwen delegation): `app_links` is not a new dependency needing manual wiring for the *successful* OAuth path (it ships inside `supabase_flutter` already) — but `SupabaseAuthService` does need its own parallel `app_links` subscription for *failure* visibility, since `supabase_flutter`'s internal handler swallows OAuth failures without a public stream. See `sr-01-oauth-approach.md` §3 Corrections 1–2.
2. **`AuthState` implemented as a plain sealed class**, not `freezed`, matching the existing `RecordingState` state-machine convention rather than `freezed`'s value-object convention.
3. **A real production bug found and fixed while writing `SupabaseAuthService`'s own tests**: `authStateChanges`'s original `async*` implementation had a subscribe race (a fresh listener could miss a state change immediately after subscribing). Fixed with `Stream.multi`. Full `zip_core` suite re-run clean afterward.
4. **`signInWithOAuth` cannot be mocked directly** (it's a static extension method) — tests stub the real underlying `getOAuthSignInUrl` instead.
5. **Delegation to Qwen for the sign-in UI (Steps 15–17) failed twice** with an identical internal backend error before producing any output; escalated per the delegation protocol and implemented directly. See `~/Documents/qwen-orchestrator/runs/zip-captions/broadcaster-auth/delegation-log.md` (not tracked in this repo).
6. **Platform redirect registration is incomplete** (Step 20): macOS is done and Windows has the plugin-documented `main.cpp` integration point, but the actual Windows registry key registration and the Linux GTK runner patch are not implemented — both require a real build on that platform to do safely, which isn't available here. Flagged as human follow-up, not silently skipped.

## Backlog Items Carried Forward (already recorded in `aidlc-state.md`)

- Sign-out must be unreachable while `BroadcastSessionState` is non-idle — a Unit 6 responsibility (Rule 9).
- Crash-reporting SDK adoption — a project-wide decision, not this unit's.
- Windows registry / Linux GTK OAuth redirect registration (this unit, flagged above) — needs completion on-platform.
