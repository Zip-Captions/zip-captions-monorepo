// Step H2: the language-pack contract (Amendment 04 section 3).
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/zip_core.dart';

import '../../helpers/fake_language_pack_service.dart';

void main() {
  group('LanguagePackStatus', () {
    test('has exactly the five statuses of Amendment 04', () {
      expect(LanguagePackStatus.values.map((s) => s.name), [
        'installed',
        'downloading',
        'downloadable',
        'unsupported',
        'unknown',
      ]);
    });
  });

  group('LanguagePackInfo', () {
    test('has value equality over status and display name', () {
      const a = LanguagePackInfo(
        status: LanguagePackStatus.installed,
        displayName: 'English',
      );
      const b = LanguagePackInfo(
        status: LanguagePackStatus.installed,
        displayName: 'English',
      );
      const c = LanguagePackInfo(
        status: LanguagePackStatus.unknown,
        displayName: 'English',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('LanguagePackEvent', () {
    test('switches exhaustively over progress, done and failed', () {
      String describe(LanguagePackEvent e) => switch (e) {
        LanguagePackProgress(:final localeId, :final percent) =>
          'progress $localeId $percent',
        LanguagePackScheduled(:final localeId) => 'scheduled $localeId',
        LanguagePackDone(:final localeId) => 'done $localeId',
        LanguagePackFailed(:final localeId, :final code) =>
          'failed $localeId $code',
      };

      expect(
        describe(const LanguagePackProgress('en-US', percent: 40)),
        'progress en-US 40',
      );
      expect(
        describe(const LanguagePackProgress('en-US')),
        'progress en-US null',
      );
      expect(
        describe(const LanguagePackScheduled('en-US')),
        'scheduled en-US',
      );
      expect(describe(const LanguagePackDone('en-US')), 'done en-US');
      expect(
        describe(const LanguagePackFailed('en-US', code: 7)),
        'failed en-US 7',
      );
      expect(
        describe(const LanguagePackFailed('en-US')),
        'failed en-US null',
      );
    });
  });

  group('FakeLanguagePackService', () {
    test('records calls, answers scripted status and relays events', () async {
      final fake = FakeLanguagePackService()
        ..setStatus('en-US', LanguagePackStatus.downloadable);
      addTearDown(fake.close);
      final seen = <LanguagePackEvent>[];
      fake.events.listen(seen.add);

      final info = await fake.status('en-US');
      await fake.download('en-US');
      fake.send(const LanguagePackDone('en-US'));
      await Future<void>.delayed(Duration.zero);

      expect(info.status, LanguagePackStatus.downloadable);
      expect(fake.statusCalls, ['en-US']);
      expect(fake.downloadCalls, ['en-US']);
      expect(seen, [isA<LanguagePackDone>()]);
    });
  });
}
