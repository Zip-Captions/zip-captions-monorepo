/// The STUN/TURN server URLs to configure WebRTC peer connections with,
/// overridable at build time via `--dart-define=ICE_SERVER_URLS=...`
/// (comma-separated).
///
/// Defaults to the local Coturn dev stack's well-known port
/// (`packages/zip_supabase/docker-compose.yml`'s `coturn` service).
///
/// Deliberately a client-side, build-time constant — mirroring
/// `supabaseUrl`'s `--dart-define` pattern in `supabase_config.dart` —
/// rather than returned by `get_turn_credentials()`. The server has no way
/// to know which hostname a given client can actually reach it at (e.g. an
/// Android emulator must reach the host loopback via `10.0.2.2`, not
/// `localhost`); that's a client-environment concern, the same reason
/// `supabaseUrl` is resolved the same way instead of being returned by any
/// RPC call.
const iceServerUrls = String.fromEnvironment(
  'ICE_SERVER_URLS',
  defaultValue: 'turn:localhost:3478,stun:localhost:3478',
);
