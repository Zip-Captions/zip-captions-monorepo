// The OS version the panel decides on (TP-28 input).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/providers/language_pack_providers.dart';

void main() {
  group('iosMajorVersion', () {
    int? parse(String version, {TargetPlatform? platform, bool web = false}) =>
        iosMajorVersion(
          isWeb: web,
          platform: platform ?? TargetPlatform.iOS,
          operatingSystemVersion: version,
        );

    test('reads the major version from the iOS version string', () {
      expect(parse('Version 26.0 (Build 23A344)'), 26);
      expect(parse('Version 18.6.2 (Build 22G100)'), 18);
      expect(parse('Version 13.0'), 13);
    });

    test('an unparseable string is null', () {
      expect(parse(''), isNull);
      expect(parse('unknown'), isNull);
    });

    test('off iOS and on the web it is null', () {
      expect(parse('Version 26.0', platform: TargetPlatform.android), isNull);
      expect(parse('Version 26.0', platform: TargetPlatform.macOS), isNull);
      expect(parse('Version 26.0', web: true), isNull);
    });
  });
}
