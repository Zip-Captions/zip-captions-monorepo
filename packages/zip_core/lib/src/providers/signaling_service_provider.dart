import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/supabase_client_provider.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/supabase_signaling_service.dart';

part 'signaling_service_provider.g.dart';

/// Provides the app's [SignalingService].
///
/// No app-startup override needed — the real implementation needs only
/// [supabaseClientProvider].
@Riverpod(keepAlive: true)
SignalingService signalingService(Ref ref) {
  return SupabaseSignalingService(client: ref.watch(supabaseClientProvider));
}
