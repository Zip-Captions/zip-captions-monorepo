import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/services/auth/secure_desktop_local_storage.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('SecureDesktopLocalStorage', () {
    late _MockFlutterSecureStorage mockStorage;
    late SecureDesktopLocalStorage storage;

    setUp(() {
      mockStorage = _MockFlutterSecureStorage();
      storage = SecureDesktopLocalStorage(storage: mockStorage);
    });

    test(
        'persistSession writes to secure storage under a stable key',
        () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await storage.persistSession('session-json');

      final captured = verify(
        () => mockStorage.write(
          key: captureAny(named: 'key'),
          value: captureAny(named: 'value'),
        ),
      ).captured;
      expect(captured[0], isA<String>());
      expect(captured[1], 'session-json');
    });

    test('accessToken reads from secure storage under the same key used to '
        'persist', () async {
      String? writtenKey;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        writtenKey = invocation.namedArguments[#key] as String;
      });
      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => 'session-json');

      await storage.persistSession('session-json');
      final result = await storage.accessToken();

      expect(result, 'session-json');
      verify(() => mockStorage.read(key: writtenKey!)).called(1);
    });

    test('accessToken returns null when nothing is persisted', () async {
      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);

      expect(await storage.accessToken(), isNull);
    });

    test('hasAccessToken delegates to containsKey', () async {
      when(
        () => mockStorage.containsKey(key: any(named: 'key')),
      ).thenAnswer((_) async => true);

      expect(await storage.hasAccessToken(), isTrue);
      verify(() => mockStorage.containsKey(key: any(named: 'key')))
          .called(1);
    });

    test('removePersistedSession deletes from secure storage', () async {
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await storage.removePersistedSession();

      verify(() => mockStorage.delete(key: any(named: 'key'))).called(1);
    });

    test('initialize completes without touching secure storage', () async {
      await storage.initialize();
      verifyZeroInteractions(mockStorage);
    });
  });
}
