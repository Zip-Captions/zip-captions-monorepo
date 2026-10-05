import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/services/webrtc/ice_server_provider.dart';
import 'package:zip_core/src/services/webrtc/turn_credential_service.dart';

/// [IceServerProvider] that composes a fetched [TurnCredentialService]
/// result with this stack's known STUN/TURN URLs.
///
/// The URLs are a construction-time configuration value (matching how
/// `supabaseClientProvider`'s URL is provided), not discovered at runtime,
/// and deliberately **not** read from `TurnCredentials.urls`
/// (CodeRabbit, PR #27): the server has no way to know which hostname a
/// given client can actually reach it at (e.g. an Android emulator must
/// reach the host loopback via `10.0.2.2`, not `localhost`) — that's a
/// client-environment concern, resolved the same way `supabaseUrl` is
/// (`--dart-define`, see `iceServerUrls` in `constants/turn_config.dart`),
/// not something the server can decide on the client's behalf.
class SupabaseIceServerProvider implements IceServerProvider {
  /// Creates a [SupabaseIceServerProvider] backed by [turnCredentialService],
  /// composing credentials with the given [urls].
  const SupabaseIceServerProvider({
    required TurnCredentialService turnCredentialService,
    required List<String> urls,
  })  : _turnCredentialService = turnCredentialService,
        _urls = urls;

  final TurnCredentialService _turnCredentialService;
  final List<String> _urls;

  @override
  Future<List<IceServer>> iceServersFor(String sessionId) async {
    final credentials = await _turnCredentialService.fetch(sessionId);
    return [
      for (final url in _urls)
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
