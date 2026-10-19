// Tests for S-19: Zip Captions Viewer, `ZcStrings` — the only reader of the
// ARB (Unit 7, Design Q6).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';

void main() {
  group('ZcStrings', () {
    test('AC: every getter reads its ARB key, not an inline literal', () {
      const strings = ZcStrings.fromMap({
        'joinBroadcastFieldLabel': 'map-field',
        'viewerStateTitleLive': 'map-live',
        'viewerTryAgain': 'map-retry',
      });

      expect(strings.joinBroadcastFieldLabel, 'map-field');
      expect(strings.stateTitleLive, 'map-live');
      expect(strings.tryAgain, 'map-retry');
    });

    test('AC: placeholder keys are formatted', () {
      const strings = ZcStrings.fromMap({
        'viewerStateJoining': 'Joining {sessionName}',
        'viewerNotBroadcastingBodyNamed': '{sessionName} is waiting',
        'viewerEndedBodyNamed': '{sessionName} ended',
      });

      expect(strings.joining('My Stream'), 'Joining My Stream');
      expect(
        strings.notBroadcastingBodyNamed('My Stream'),
        'My Stream is waiting',
      );
      expect(strings.endedBodyNamed('My Stream'), 'My Stream ended');
    });

    test('AC: a missing key yields the key itself (never a crash)', () {
      const strings = ZcStrings.fromMap({});

      expect(strings.tryAgain, 'viewerTryAgain');
    });

    test('AC: the real ARB parses and every viewer key is present', () {
      // Parsing the shipped file here proves the asset is well-formed JSON
      // and that the keys this class reads exist; `ZcStrings.load` reads the
      // same bytes through `rootBundle` in the app.
      final raw = File('l10n/arb/app_en.arb').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final strings = ZcStrings.fromMap(map.cast<String, String>());

      expect(strings.joinBroadcastSubmit, 'Join');
      expect(strings.viewerLeave, 'Leave');
      expect(strings.confirmLeaveCancel, 'Stay');
      expect(
        strings.captionsPausedNotice,
        'Captions paused by the broadcaster',
      );
      expect(strings.stateTitleLive, 'Live');
      expect(strings.stateTitleEnded, 'Broadcast ended');
      expect(strings.stateTitleFull, 'Broadcast full');
      expect(strings.stateTitleCannotConnect, "Can't connect");
      expect(strings.joining('Ada'), 'Joining Ada');
      expect(
        strings.cannotConnectRateLimitedBody,
        contains('Too many attempts'),
      );
      expect(
        strings.cannotConnectResolutionFailedBody,
        contains('Try again'),
      );
    });
  });
}
