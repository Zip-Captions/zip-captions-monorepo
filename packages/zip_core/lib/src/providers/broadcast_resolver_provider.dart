import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/providers/supabase_client_provider.dart';
import 'package:zip_core/src/services/broadcast/broadcast_resolver.dart';
import 'package:zip_core/src/services/broadcast/supabase_broadcast_resolver.dart';

part 'broadcast_resolver_provider.g.dart';

/// Provides the app's [BroadcastResolver].
///
/// No app-startup override needed — the real implementation needs only
/// [supabaseClientProvider] and [signalingServiceProvider].
@Riverpod(keepAlive: true)
BroadcastResolver broadcastResolver(Ref ref) {
  return SupabaseBroadcastResolver(
    client: ref.watch(supabaseClientProvider),
    signalingService: ref.watch(signalingServiceProvider),
  );
}
