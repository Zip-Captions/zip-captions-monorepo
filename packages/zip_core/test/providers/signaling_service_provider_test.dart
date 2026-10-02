import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/providers/supabase_client_provider.dart';
import 'package:zip_core/src/services/signaling/supabase_signaling_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test(
    'signalingServiceProvider wires the overridden supabaseClientProvider '
    'into a SupabaseSignalingService',
    () {
      final client = _MockSupabaseClient();
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final service = container.read(signalingServiceProvider);

      expect(service, isA<SupabaseSignalingService>());
    },
  );

  test('throws when supabaseClientProvider is not overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(signalingServiceProvider),
      throwsUnimplementedError,
    );
  });
}
