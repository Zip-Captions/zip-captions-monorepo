/// Reasons a broadcaster sign-in attempt can fail.
///
/// See `sr-01-oauth-approach.md` Section 7 for the full trigger-to-value
/// mapping. Every OAuth-flow exception resolves to exactly one of these —
/// none is ever left unmapped (Rule 9 of `business-rules.md`).
enum AuthFailure {
  /// The user declined or backed out of the provider's consent screen
  /// (Google's OAuth callback carries `error=access_denied`).
  cancelled,

  /// The provider or GoTrue rejected the flow at the configuration level
  /// (e.g. provider disabled, domain not allowlisted) — distinct from the
  /// user declining.
  denied,

  /// A connectivity failure opening the browser, resolving the callback, or
  /// completing the token exchange.
  network,

  /// Any other outcome, including unrecognized provider error codes and any
  /// unexpected exception. The underlying exception's type and stack trace
  /// (never its message) are logged at the point it is folded into this
  /// value, so a real bug is not indistinguishable from a legitimate
  /// provider rejection during triage.
  providerError,

  /// A background token refresh failed because the refresh token itself is
  /// invalid or expired. This value is reserved for a user-initiated action
  /// that synchronously discovers the session is already gone — a passive
  /// background failure routes straight to signed-out instead (see
  /// `AuthState.signedOut`, `business-rules.md` Rule 3).
  sessionExpired,
}
