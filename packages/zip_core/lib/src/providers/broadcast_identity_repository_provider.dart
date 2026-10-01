import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/supabase_client_provider.dart';
import 'package:zip_core/src/services/broadcast/broadcast_identity_repository.dart';
import 'package:zip_core/src/services/broadcast/supabase_broadcast_identity_repository.dart';

part 'broadcast_identity_repository_provider.g.dart';

/// Provides the app's [BroadcastIdentityRepository].
///
/// Unlike `authServiceProvider`/`audioDeviceServiceProvider`, this doesn't
/// need an app-startup override — the real implementation needs only
/// [supabaseClientProvider], already resolvable here.
@Riverpod(keepAlive: true)
BroadcastIdentityRepository broadcastIdentityRepository(Ref ref) {
  return SupabaseBroadcastIdentityRepository(
    client: ref.watch(supabaseClientProvider),
  );
}
