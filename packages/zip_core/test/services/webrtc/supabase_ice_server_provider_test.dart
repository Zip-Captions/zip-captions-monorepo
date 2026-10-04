import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/turn_credentials.dart';
import 'package:zip_core/src/services/webrtc/supabase_ice_server_provider.dart';
import 'package:zip_core/src/services/webrtc/turn_credential_service.dart';

class _MockTurnCredentialService extends Mock
    implements TurnCredentialService {}

void main() {
  late _MockTurnCredentialService turnCredentialService;
  late SupabaseIceServerProvider provider;

  setUp(() {
    turnCredentialService = _MockTurnCredentialService();
    provider = SupabaseIceServerProvider(
      turnCredentialService: turnCredentialService,
      urls: const ['turn:localhost:3478', 'stun:localhost:3478'],
    );
  });

  group('SupabaseIceServerProvider.iceServersFor', () {
    test(
      'composes injected urls with a fetched TurnCredentials into one '
      'STUN-only IceServer (no username/credential) and one TURN IceServer '
      '(with them) — not from TurnCredentials.urls (CodeRabbit, PR #27: the '
      'server cannot know which hostname a given client can reach it at)',
      () async {
        when(() => turnCredentialService.fetch('session-1')).thenAnswer(
          (_) async => TurnCredentials(
            username: '1735689600',
            credential: 'abc123==',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
            urls: const ['turn:ignored-server-url:3478'],
          ),
        );

        final result = await provider.iceServersFor('session-1');

        expect(result, hasLength(2));
        expect(result[0].urls, ['turn:localhost:3478']);
        expect(result[0].username, '1735689600');
        expect(result[0].credential, 'abc123==');
        expect(result[1].urls, ['stun:localhost:3478']);
        expect(result[1].username, isNull);
        expect(result[1].credential, isNull);
      },
    );

    test(
      'propagates a TurnCredentialService failure uncaught (no retry, no '
      'STUN-only fallback — NFR Design Q1)',
      () async {
        when(() => turnCredentialService.fetch('session-1'))
            .thenThrow(StateError('network error'));

        await expectLater(
          provider.iceServersFor('session-1'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
