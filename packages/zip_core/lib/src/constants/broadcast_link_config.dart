/// The base URL broadcast links are generated under, overridable at build
/// time via `--dart-define=BROADCAST_BASE_URL=...`.
///
/// Follows the same `String.fromEnvironment` pattern as
/// `supabase_config.dart`'s `supabaseUrl` and `turn_config.dart`'s
/// `iceServerUrls`. The default preserves the shipped v1 apex (and therefore
/// localization/local-dev behaviour) byte-for-byte; release builds supply
/// the v2 subdomain via configuration, so the v2 host name appears nowhere
/// in source (`business-rules.md` Rule 11, Q9 guardrail 3).
const broadcastBaseUrl = String.fromEnvironment(
  'BROADCAST_BASE_URL',
  defaultValue: 'https://zipcaptions.app/b/',
);
