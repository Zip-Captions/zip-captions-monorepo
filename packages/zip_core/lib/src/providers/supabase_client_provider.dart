import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_client_provider.g.dart';

/// Provides the app's [SupabaseClient].
///
/// The concrete client is registered at app startup via provider overrides,
/// after `Supabase.initialize` (see each app's `main.dart`). This provider
/// throws by default if no override is supplied.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  throw UnimplementedError(
    'supabaseClientProvider must be overridden at app startup with the '
    'client from Supabase.initialize.',
  );
}
