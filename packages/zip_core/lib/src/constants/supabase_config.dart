/// The Supabase project URL, overridable at build time via
/// `--dart-define=SUPABASE_URL=...`.
///
/// Defaults to the local Supabase stack's well-known port
/// (`packages/zip_supabase/.env.example`'s `SUPABASE_PUBLIC_URL`). A real
/// deployment target must be supplied via `--dart-define` before release —
/// this default is local-dev-only.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://localhost:54321',
);

/// The Supabase anonymous (public) API key, overridable at build time via
/// `--dart-define=SUPABASE_ANON_KEY=...`.
///
/// Defaults to the local Supabase stack's published demo anon key
/// (`packages/zip_supabase/.env.example`'s `ANON_KEY`) — explicitly
/// documented there as safe for local development only, never a real
/// secret. A real deployment target must supply its own anon key via
/// `--dart-define` before release.
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCi'
      'AgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.'
      'dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
);
