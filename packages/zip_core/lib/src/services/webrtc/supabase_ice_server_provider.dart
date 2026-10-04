import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/services/webrtc/ice_server_provider.dart';
import 'package:zip_core/src/services/webrtc/turn_credential_service.dart';

/// [IceServerProvider] that composes a fetched [TurnCredentialService]
/// result with this stack's known STUN/TURN URLs.
///
/// The URLs are a construction-time configuration value (matching how
/// `supabaseClientProvider`'s URL is provided), not discovered at runtime
/// — this stack has exactly one Coturn deployment.
class SupabaseIceServerProvider implements IceServerProvider {
  /// Creates a [SupabaseIceServerProvider] backed by [turnCredentialService].
  const SupabaseIceServerProvider({
    required TurnCredentialService turnCredentialService,
  }) : _turnCredentialService = turnCredentialService;

  final TurnCredentialService _turnCredentialService;

  @override
  Future<List<IceServer>> iceServersFor(String sessionId) async {
    final credentials = await _turnCredentialService.fetch(sessionId);
    return [
      for (final url in credentials.urls)
        if (url.startsWith('stun:'))
          IceServer(urls: [url])
        else
          IceServer(
            urls: [url],
            username: credentials.username,
            credential: credentials.credential,
          ),
    ];
  }
}
