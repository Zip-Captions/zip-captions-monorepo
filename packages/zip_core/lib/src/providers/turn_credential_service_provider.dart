import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/supabase_client_provider.dart';
import 'package:zip_core/src/services/webrtc/supabase_turn_credential_service.dart';
import 'package:zip_core/src/services/webrtc/turn_credential_service.dart';

part 'turn_credential_service_provider.g.dart';

/// Provides the app's [TurnCredentialService].
///
/// No app-startup override needed — the real implementation needs only
/// [supabaseClientProvider].
@Riverpod(keepAlive: true)
TurnCredentialService turnCredentialService(Ref ref) {
  return SupabaseTurnCredentialService(
    client: ref.watch(supabaseClientProvider),
  );
}
