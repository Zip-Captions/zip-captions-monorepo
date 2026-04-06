import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:zip_core/src/models/speech_locale.dart';

import '../helpers/generators.dart';

void main() {
  group('SpeechLocale properties PBT', () {
    Glados(arbitraryLocaleId).test(
      'languageCode is non-empty and lowercase',
      (localeId) {
        final locale = SpeechLocale(
          localeId: localeId,
          displayName: 'Test',
        );
        expect(locale.languageCode, isNotEmpty);
        expect(
          locale.languageCode,
          locale.languageCode.toLowerCase(),
        );
      },
    );

    Glados(arbitraryLocaleId).test(
      'equality is case-insensitive on localeId',
      (localeId) {
        final lower = SpeechLocale(
          localeId: localeId.toLowerCase(),
          displayName: 'A',
        );
        final upper = SpeechLocale(
          localeId: localeId.toUpperCase(),
          displayName: 'B',
        );
        expect(lower, equals(upper));
        expect(lower.hashCode, upper.hashCode);
      },
    );

    Glados(arbitraryLocaleId).test(
      'equality is reflexive',
      (localeId) {
        final locale = SpeechLocale(
          localeId: localeId,
          displayName: 'Test',
        );
        expect(locale, equals(locale));
      },
    );
  });
}
