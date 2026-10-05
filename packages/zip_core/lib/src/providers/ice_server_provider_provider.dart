import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/constants/turn_config.dart';
import 'package:zip_core/src/providers/turn_credential_service_provider.dart';
import 'package:zip_core/src/services/webrtc/ice_server_provider.dart';
import 'package:zip_core/src/services/webrtc/supabase_ice_server_provider.dart';

part 'ice_server_provider_provider.g.dart';

/// Provides the app's [IceServerProvider].
///
/// No app-startup override needed — the real implementation needs only
/// [turnCredentialServiceProvider] and [iceServerUrls] (the
/// `--dart-define`-overridable STUN/TURN URL list, matching
/// `supabaseUrl`'s pattern).
@Riverpod(keepAlive: true)
IceServerProvider iceServerProvider(Ref ref) {
  return SupabaseIceServerProvider(
    turnCredentialService: ref.watch(turnCredentialServiceProvider),
    urls: iceServerUrls.split(',').map((url) => url.trim()).toList(),
  );
}
