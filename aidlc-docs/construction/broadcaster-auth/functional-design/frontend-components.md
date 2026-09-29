# Frontend Components — Broadcaster Auth

**Screen**: the sign-in view (`AccountSection` per `phase2-components.md`), Zip Broadcast
only, per Proto-10 (`zip-broadcast-sign-in.html`, already approved). Per the plan's Q7,
Proto-10's states and copy carry through as-is; the one addition below (a busy treatment for
`SigningIn`) fills a gap Proto-10's state switcher didn't enumerate, without introducing a
new screen or contradicting the approved mockup.

## State → UI Mapping

| `AuthState` | Proto-10 state | Rendering |
|---|---|---|
| `SignedOut` | `state-signed-out` | Card with provider buttons (one per `AuthProviderConfig.providers` entry — Phase 2 renders exactly one: Google), icon, title, copy, as mocked. |
| `SigningIn(providerId)` | *(not in Proto-10's switcher)* | Same card as `SignedOut`, with the button matching `providerId` showing a spinner in place of its label and all provider buttons disabled — a minimal addition, not a new card, so it doesn't diverge from the approved visual design. |
| `SignedIn(userId)` | `state-signed-in` | Account row + sign-out button, as mocked. Display name/email/avatar shown by the account row are read directly from the SDK's current session object by the widget, not carried on `AuthState` (see `domain-entities.md`). The sign-out button itself is owned by this view in Unit 2; whether it is enabled at all while a broadcast is live is a Unit 6 (`ZbAppShell`) composition concern (see `business-logic-model.md` F-BA-3), not decided here. |
| `AuthFailed(providerId, reason)` | `state-auth-failure` | Alert card + retry button, as mocked. The alert copy is the same generic, non-technical message for every `AuthFailure` value (Q6) — no per-reason copy branching in the widget. |

## Props / State

- The sign-in view watches `authNotifierProvider` (Riverpod `watch`, read-only reactive
  binding — the *notifier's own* internal calls to `AuthService` are explicit per the
  project convention; only the UI's read of the resulting state is a `watch`).
- `onProviderTap(providerId)` → `ref.read(authNotifierProvider.notifier).signIn(providerId)`.
- `onSignOutTap()` → `ref.read(authNotifierProvider.notifier).signOut()`.
- `onRetryTap()` → re-invokes `signIn(providerId)` reading `providerId` directly off the
  current `AuthFailed(providerId, reason)` state — no view-local bookkeeping needed.

## Integration Points

- Reads `authProviderConfigProvider` (static, per SR-01 Section 8) to render the provider
  button list — zero conditional logic in the widget beyond iterating the list.
- Does not call `supabaseClientProvider` or any Supabase type directly.

