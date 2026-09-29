# Testable Properties — Broadcaster Auth (PBT-01)

Added as a Functional Design addendum: the Security Baseline and Property-Based Testing
extensions first apply to this unit starting at NFR Requirements (per
`aidlc-state.md`'s Extension Configuration note and `session-protocol.md` Rule 2), after
Functional Design was already approved. PBT-01 requires property identification to live in
the Functional Design artifacts regardless of which stage loaded the rule, so this
addendum supplements the approved design without reopening any of its decisions.

| Component / Behavior | Property | Category |
|---|---|---|
| `AuthService`/`AuthNotifier` failure mapping (SR-01 Section 7) | For any exception the OAuth flow can raise, mapping it always yields exactly one `AuthFailure` value — no exception ever escapes `AuthNotifier` uncaught, and no failure is left unmapped. | Invariant |
| `AuthNotifier.signOut()` | Calling `signOut()` from any `AuthState`, once or twice in a row, always leaves the notifier in `SignedOut` (Rule 8) — `signOut ∘ signOut = signOut` in effect. | Idempotence |
| `AuthNotifier` state machine | Across arbitrary sequences of `signIn(providerId)` (resolving success / cancelled / denied / network / providerError), `signOut()`, and a simulated passive session loss, the resulting state always matches a simplified reference model: `AuthFailed` is reached only immediately after a `SigningIn` that failed for the *same* `providerId` (never after a passive loss — Rule 3), and `SignedOut` is always reachable and terminal-safe (Rule 8's idempotence holds from it). | Stateful (PBT-06) |
| Sign-in view provider button list | For any non-empty generated `AuthProviderConfig.providers` list, the view renders exactly one button per entry, each wired to `signIn` with that entry's `id` — never fewer, more, or mismatched. | Invariant |

## Marked N/A

- **Round-trip**: no serialization/deserialization exists in this unit (`AuthProviderConfig` is a static in-memory list, not parsed from a wire format) — that begins in Unit 5's `CaptionWireCodec`.
- **Oracle**: no reference/brute-force implementation exists to compare against; the SDK's OAuth flow is not something this unit reimplements.
- **Commutativity**: sign-in and sign-out are inherently order-dependent (not interchangeable), so this category doesn't apply.
- **Induction**: no recursive or tree-shaped structures exist in this unit's domain model.

## Carried to Code Generation

The stateful property (row 3) needs a fake `AuthService` (per NFR-7.3's "testable with fakes" requirement) that can be driven to emit each `authStateChanges` outcome on command, and a simplified reference-model state machine to assert against, per PBT-06. Generator quality (PBT-07) requires the command generator to produce realistic sequences — not just uniformly random enum picks — e.g. weighting toward the sequences a real user would actually produce (sign-in-then-succeed, sign-in-then-retry-after-failure, sign-in-then-sign-out) while still covering the adversarial orderings (sign-out immediately after a pending sign-in, back-to-back sign-ins).
