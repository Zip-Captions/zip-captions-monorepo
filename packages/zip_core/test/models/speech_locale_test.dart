import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/speech_locale.dart';

void main() {
  group('SpeechLocale', () {
    group('languageCode', () {
      test('extracts language before hyphen', () {
        const locale = SpeechLocale(
          localeId: 'en-US',
          displayName: 'English (US)',
        );
        expect(locale.languageCode, 'en');
      });

      test('extracts language before underscore', () {
        const locale = SpeechLocale(
          localeId: 'en_US',
          displayName: 'English (US)',
        );
        expect(locale.languageCode, 'en');
      });

      test('returns full localeId when no separator', () {
        const locale = SpeechLocale(
          localeId: 'fr',
          displayName: 'French',
        );
        expect(locale.languageCode, 'fr');
      });

      test('returns lowercase', () {
        const locale = SpeechLocale(
          localeId: 'EN-US',
          displayName: 'English (US)',
        );
        expect(locale.languageCode, 'en');
      });
    });

    group('equality (case-insensitive on localeId)', () {
      test('same localeId different case are equal', () {
        const a = SpeechLocale(localeId: 'en-US', displayName: 'English');
        const b = SpeechLocale(localeId: 'EN-us', displayName: 'English');
        expect(a, equals(b));
      });

      test('different localeId are not equal', () {
        const a = SpeechLocale(localeId: 'en-US', displayName: 'English');
        const b = SpeechLocale(localeId: 'en-GB', displayName: 'English');
        expect(a, isNot(equals(b)));
      });

      test('same localeId different displayName are equal', () {
        const a = SpeechLocale(localeId: 'fr', displayName: 'French');
        const b = SpeechLocale(localeId: 'fr', displayName: 'Francais');
        expect(a, equals(b));
      });

      test('hashCode is consistent with equality', () {
        const a = SpeechLocale(localeId: 'en-US', displayName: 'English');
        const b = SpeechLocale(localeId: 'EN-us', displayName: 'English');
        expect(a.hashCode, equals(b.hashCode));
      });
    });
  });
}
