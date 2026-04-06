import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;

import '../helpers/generators.dart';

void main() {
  group('WakeLockSettings PBT', () {
    Glados(arbitraryWakeLockSettings).test(
      'copyWith with no changes produces equal instance',
      (settings) {
        final copy = settings.copyWith();
        expect(copy, equals(settings));
      },
    );

    Glados(arbitraryWakeLockSettings).test(
      'enabled field is always a valid bool',
      (settings) {
        expect(settings.enabled, isA<bool>());
        expect(settings.releaseOnPause, isA<bool>());
      },
    );
  });
}
