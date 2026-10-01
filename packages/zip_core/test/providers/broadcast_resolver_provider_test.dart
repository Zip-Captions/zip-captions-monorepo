import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/providers/broadcast_resolver_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/providers/supabase_client_provider.dart';
import 'package:zip_core/src/services/broadcast/supabase_broadcast_resolver.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSignalingService extends Mock implements SignalingService {}

void main() {
  test(
    'broadcastResolverProvider composes supabaseClientProvider and '
    'signalingServiceProvider into a SupabaseBroadcastResolver',
    () {
      final client = _MockSupabaseClient();
      final signalingService = _MockSignalingService();
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          signalingServiceProvider.overrideWithValue(signalingService),
        ],
      );
      addTearDown(container.dispose);

      final resolver = container.read(broadcastResolverProvider);

      expect(resolver, isA<SupabaseBroadcastResolver>());
    },
  );

  test('throws when supabaseClientProvider is not overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(broadcastResolverProvider),
      throwsUnimplementedError,
    );
  });
}
