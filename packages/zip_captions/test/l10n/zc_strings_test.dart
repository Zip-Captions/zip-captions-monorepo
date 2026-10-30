// Tests for S-19: Zip Captions Viewer, `ZcStrings` — the only reader of the
// ARB (Unit 7, Design Q6).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';

/// An [AssetBundle] serving one in-memory ARB document.
class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.text);

  final String text;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async => text;
}

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

    test('AC: load drops ARB @-metadata and non-String values', () async {
      // The decoded ARB also carries `@key` description objects and
      // `@@locale`. A whole-map `cast<String, String>()` only defers the
      // throw, so any later full-map read (serialization, a key sweep)
      // would fail; the loader must filter instead.
      final strings = await ZcStrings.load(
        _StringBundle(
          jsonEncode({
            '@@locale': 'en',
            'viewerLeave': 'Leave',
            '@viewerLeave': {'description': 'metadata'},
            'viewerAge': 3,
          }),
        ),
      );

      // Walking every value must not throw: that is exactly what a lazy
      // `cast` would do on the metadata object.
      expect(() => strings.values.values.toList(), returnsNormally);
      expect(strings.viewerLeave, 'Leave');
      expect(strings.tryAgain, 'viewerTryAgain');

      // Filtered entries are absent, not merely unread.
      expect(strings.containsKey('@viewerLeave'), isFalse);
      expect(strings.containsKey('@@locale'), isFalse);
      expect(strings.containsKey('viewerAge'), isFalse);
      expect(strings.values, {'viewerLeave': 'Leave'});
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

  // Unit 10, Amendment 04 section 5: the missing-language copy. British
  // English; `{language}` and `{percent}` are filled by small methods.
  group('Unit 10 language-pack copy (Amendment 04)', () {
    ZcStrings shipped() {
      final raw = File('l10n/arb/app_en.arb').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ZcStrings.fromMap({
        for (final entry in decoded.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.key: entry.value as String,
      });
    }

    test('AC: the shipped wording is the approved wording', () {
      final strings = shipped();

      expect(strings.languagePackDownload('French'), 'Download French');
      expect(
        strings.languagePackDownloadingPercent('French', 42),
        'Downloading French… 42%',
      );
      expect(strings.languagePackDownloading('French'), 'Downloading French…');
      expect(
        strings.languagePackScheduled('French'),
        "French will download later, for example when you're on Wi-Fi. "
        'Tap Try again once it has downloaded.',
      );
      expect(
        strings.languagePackReady('French'),
        'French is ready. Tap Try again to start captioning.',
      );
      expect(
        strings.languagePackFailed('French'),
        "Couldn't download French. Check your connection and try again.",
      );
      expect(
        strings.languagePackIosInstructions('French'),
        'To caption in French, turn on Dictation and add a French keyboard: '
        'open Settings, then General, then Keyboard. Turn on Enable '
        'Dictation, then tap Keyboards and Add New Keyboard.',
      );
    });

    test('AC: the methods read their ARB keys, not inline literals', () {
      const strings = ZcStrings.fromMap({
        'languagePackDownload': 'dl {language}',
        'languagePackDownloadingPercent': 'dling {language} {percent}',
        'languagePackDownloading': 'dling {language}',
        'languagePackScheduled': 'sched {language}',
        'languagePackReady': 'ready {language}',
        'languagePackFailed': 'failed {language}',
        'languagePackIosInstructions': 'ios {language} / {language}',
      });

      expect(strings.languagePackScheduled('X'), 'sched X');

      expect(strings.languagePackDownload('X'), 'dl X');
      expect(strings.languagePackDownloadingPercent('X', 7), 'dling X 7');
      expect(strings.languagePackDownloading('X'), 'dling X');
      expect(strings.languagePackReady('X'), 'ready X');
      expect(strings.languagePackFailed('X'), 'failed X');
      expect(strings.languagePackIosInstructions('X'), 'ios X / X');
    });

    test('AC: a language name that looks like a placeholder stays literal', () {
      const strings = ZcStrings.fromMap({
        'languagePackDownloadingPercent': 'dling {language} {percent}',
      });

      expect(
        strings.languagePackDownloadingPercent('{percent}', 5),
        'dling {percent} 5',
      );
    });
  });

  // Unit 10, Amendment 02 sections 6.2 and 6.3: the iOS explainer and the
  // failure text. British English; "Your audio was not sent anywhere" is
  // deliberately absent because the plugin's missing `return` could make it
  // untrue (Amendment 02 section 6.3).
  group('Unit 10 disclosure and failure copy', () {
    const requiredKeys = [
      'speechExplainerTitle',
      'speechExplainerBody',
      'speechExplainerContinue',
      'speechExplainerNotNow',
      'onDeviceUnavailableTitle',
      'onDeviceUnavailableBody',
      'failureMicDeniedTitle',
      'failureMicDeniedBody',
      'failureMicPermanentlyDeniedTitle',
      'failureMicPermanentlyDeniedBody',
      'failureEngineInitFailedTitle',
      'failureEngineInitFailedBody',
      'failureEngineStartFailedTitle',
      'failureEngineStartFailedBody',
      'failureOtherTitle',
      'failureOtherBody',
      'failureTryAgain',
      'failureOpenSettings',
      'failureBack',
    ];

    test('AC: every Unit 10 key is present in the shipped ARB', () {
      final raw = File('l10n/arb/app_en.arb').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final strings = ZcStrings.fromMap({
        for (final entry in decoded.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.key: entry.value as String,
      });

      for (final key in requiredKeys) {
        expect(
          strings.containsKey(key),
          isTrue,
          reason: 'missing ARB key: $key',
        );
        expect(strings.values[key]!.trim(), isNotEmpty, reason: key);
      }
    });

    test('AC: the getters read the ARB values', () {
      const strings = ZcStrings.fromMap({
        'speechExplainerTitle': 'explainer-title',
        'speechExplainerBody': 'explainer-body',
        'speechExplainerContinue': 'explainer-continue',
        'speechExplainerNotNow': 'explainer-not-now',
        'onDeviceUnavailableTitle': 'od-title',
        'onDeviceUnavailableBody': 'od-body',
        'failureMicDeniedTitle': 'md-title',
        'failureMicDeniedBody': 'md-body',
        'failureMicPermanentlyDeniedTitle': 'mpd-title',
        'failureMicPermanentlyDeniedBody': 'mpd-body',
        'failureEngineInitFailedTitle': 'eif-title',
        'failureEngineInitFailedBody': 'eif-body',
        'failureEngineStartFailedTitle': 'esf-title',
        'failureEngineStartFailedBody': 'esf-body',
        'failureOtherTitle': 'other-title',
        'failureOtherBody': 'other-body',
        'failureTryAgain': 'try-again',
        'failureOpenSettings': 'open-settings',
        'failureBack': 'back',
      });

      expect(strings.speechExplainerTitle, 'explainer-title');
      expect(strings.speechExplainerBody, 'explainer-body');
      expect(strings.speechExplainerContinue, 'explainer-continue');
      expect(strings.speechExplainerNotNow, 'explainer-not-now');
      expect(strings.onDeviceUnavailableTitle, 'od-title');
      expect(strings.onDeviceUnavailableBody, 'od-body');
      expect(strings.failureMicDeniedTitle, 'md-title');
      expect(strings.failureMicDeniedBody, 'md-body');
      expect(strings.failureMicPermanentlyDeniedTitle, 'mpd-title');
      expect(strings.failureMicPermanentlyDeniedBody, 'mpd-body');
      expect(strings.failureEngineInitFailedTitle, 'eif-title');
      expect(strings.failureEngineInitFailedBody, 'eif-body');
      expect(strings.failureEngineStartFailedTitle, 'esf-title');
      expect(strings.failureEngineStartFailedBody, 'esf-body');
      expect(strings.failureOtherTitle, 'other-title');
      expect(strings.failureOtherBody, 'other-body');
      expect(strings.failureTryAgain, 'try-again');
      expect(strings.failureOpenSettings, 'open-settings');
      expect(strings.failureBack, 'back');
    });

    test('AC: noTranscriptSavedNotice reads its ARB key and carries the '
        'approved wording', () {
      const strings = ZcStrings.fromMap({
        'noTranscriptSavedNotice': 'nts-notice',
      });
      expect(strings.noTranscriptSavedNotice, 'nts-notice');

      // And the real ARB carries the Amendment 03 section 7 sentence.
      final raw = File('l10n/arb/app_en.arb').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(
        decoded['noTranscriptSavedNotice'],
        'No speech was recognised, so no transcript was saved.',
      );
    });

    test('AC: inactivityStopNoticeFor fills the minutes, and the singular '
        'reads "1 minute" (BR-U10-53)', () {
      const strings = ZcStrings.fromMap({
        'inactivityStopNotice': 'Stopped after {minutes} minutes of quiet.',
      });
      expect(
        strings.inactivityStopNoticeFor(5),
        'Stopped after 5 minutes of quiet.',
      );
      expect(
        strings.inactivityStopNoticeFor(1),
        'Stopped after 1 minute of quiet.',
      );
      expect(
        strings.inactivityStopNoticeFor(10),
        'Stopped after 10 minutes of quiet.',
      );

      // And the real ARB carries the Amendment 05 sentence.
      final raw = File('l10n/arb/app_en.arb').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(
        decoded['inactivityStopNotice'],
        'Captioning stopped after {minutes} minutes without speech.',
      );
      final real = ZcStrings.fromMap({
        for (final entry in decoded.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.key: entry.value as String,
      });
      expect(
        real.inactivityStopNoticeFor(5),
        'Captioning stopped after 5 minutes without speech.',
      );
      expect(
        real.inactivityStopNoticeFor(1),
        'Captioning stopped after 1 minute without speech.',
      );
    });

    test('TP-44: the combined stop notices fill their templates, with the '
        'singular "1 minute" (Amendment 07, BR-U10-66)', () {
      const strings = ZcStrings.fromMap({
        'inactivityStopNotice': 'quiet {minutes} minutes.',
        'transcriptSaveFailedNotice': 'save-failed.',
        'inactivityStopNoTranscriptNotice': 'quiet-nts {minutes} minutes.',
        'inactivityStopSaveFailedNotice':
            '{inactivityNotice} + {saveFailedNotice}',
        'stopErrorWithSaveOutcomeNotice': '{errorTitle} + {saveOutcomeNotice}',
      });
      expect(
        strings.inactivityStopNoTranscriptNoticeFor(5),
        'quiet-nts 5 minutes.',
      );
      expect(
        strings.inactivityStopNoTranscriptNoticeFor(1),
        'quiet-nts 1 minute.',
      );
      expect(
        strings.inactivityStopSaveFailedNoticeFor(5),
        'quiet 5 minutes. + save-failed.',
      );
      expect(
        strings.inactivityStopSaveFailedNoticeFor(1),
        'quiet 1 minute. + save-failed.',
      );
      expect(
        strings.stopErrorWithSaveOutcomeNotice(
          errorTitle: 'err-title',
          saveOutcomeNotice: 'outcome.',
        ),
        'err-title + outcome.',
      );
    });

    test('TP-44: the real ARB carries the approved Amendment 07 text', () {
      final raw = File('l10n/arb/app_en.arb').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final real = ZcStrings.fromMap({
        for (final entry in decoded.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.key: entry.value as String,
      });
      expect(
        real.inactivityStopNoTranscriptNoticeFor(5),
        'Captioning stopped after 5 minutes without speech, so no transcript '
        'was saved.',
      );
      expect(
        real.inactivityStopNoTranscriptNoticeFor(1),
        'Captioning stopped after 1 minute without speech, so no transcript '
        'was saved.',
      );
      expect(
        real.inactivityStopSaveFailedNoticeFor(5),
        'Captioning stopped after 5 minutes without speech. The transcript '
        'could not be saved.',
      );
      expect(
        real.stopErrorWithSaveOutcomeNotice(
          errorTitle: real.failureEngineStartFailedTitle,
          saveOutcomeNotice: real.noTranscriptSavedNotice,
        ),
        "Captioning couldn't start. No speech was recognised, so no "
        'transcript was saved.',
      );
      expect(
        real.stopErrorWithSaveOutcomeNotice(
          errorTitle: real.failureEngineStartFailedTitle,
          saveOutcomeNotice: real.transcriptSaveFailedNotice,
        ),
        "Captioning couldn't start. The transcript could not be saved.",
      );
    });

    test('AC: the wording is the approved Amendment 02 text', () {
      final raw = File('l10n/arb/app_en.arb').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      // The real ARB carries `@key` metadata objects; the reader only takes
      // the String values, exactly as `ZcStrings.load` does.
      final strings = ZcStrings.fromMap({
        for (final entry in decoded.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.key: entry.value as String,
      });

      expect(
        strings.speechExplainerTitle,
        'Before your device asks for permission',
      );
      expect(
        strings.speechExplainerBody,
        contains('recognises speech on this device'),
      );
      expect(strings.speechExplainerContinue, 'Continue');
      expect(strings.speechExplainerNotNow, 'Not now');
      expect(
        strings.onDeviceUnavailableTitle,
        "On-device captions aren't available",
      );
      expect(
        strings.onDeviceUnavailableBody,
        "This device or language doesn't support on-device speech "
        "recognition, so Zip Captions didn't start.",
      );
      expect(strings.failureTryAgain, 'Try again');
      expect(strings.failureOpenSettings, 'Open settings');
      expect(strings.failureBack, 'Back');

      // The removed sentence must not come back.
      for (final value in strings.values.values) {
        expect(value.toLowerCase(), isNot(contains('not sent anywhere')));
      }
    });
  });
}
