import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/providers/broadcast_identity_repository_provider.dart';
import 'package:zip_core/src/providers/supabase_client_provider.dart';
import 'package:zip_core/src/services/broadcast/supabase_broadcast_identity_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test(
    'broadcastIdentityRepositoryProvider wires the overridden '
    'supabaseClientProvider into a SupabaseBroadcastIdentityRepository',
    () {
      final client = _MockSupabaseClient();
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final repository = container.read(broadcastIdentityRepositoryProvider);

      expect(repository, isA<SupabaseBroadcastIdentityRepository>());
    },
  );

  test('throws when supabaseClientProvider is not overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(broadcastIdentityRepositoryProvider),
      throwsUnimplementedError,
    );
  });
}
