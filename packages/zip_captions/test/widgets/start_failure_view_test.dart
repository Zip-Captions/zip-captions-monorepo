// Tests for Unit 10, P9 / TP-8 (BR-U10-10, BR-U10-11): the start-failure
// view and its panel.
//
// The classification must be total and deterministic over every factory error
// and every platform, and "Open settings" must appear in exactly the two cases
// where app settings can fix the problem.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/widgets/start_failure_view.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/pbt.dart' as pbt;

/// Every factory error, labelled for the failure message.
final _factoryErrors = <String, RecordingError Function()>{
  'permissionDenied': RecordingErrorFactories.permissionDenied,
  'permissionPermanentlyDenied':
      RecordingErrorFactories.permissionPermanentlyDenied,
  'engineInitFailed': RecordingErrorFactories.engineInitFailed,
  'engineStartFailed': RecordingErrorFactories.engineStartFailed,
  'engineRequiresModelDownload':
      RecordingErrorFactories.engineRequiresModelDownload,
  'onDeviceRecognitionUnavailable':
      RecordingErrorFactories.onDeviceRecognitionUnavailable,
  'localeNotSupported(': () =>
      RecordingErrorFactories.localeNotSupported('en-GB'),
};

/// Every platform the app ships on, plus web.
const List<TargetPlatform> _platforms = TargetPlatform.values;

/// The strings the panel renders, substituted so a test can tell an ARB
/// value from an inline literal.
const _strings = ZcStrings.fromMap({
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
  'failureTryAgain': 'try-again-label',
  'failureOpenSettings': 'open-settings-label',
  'failureBack': 'back-label',
});

void main() {
  group('StartFailureView classification (TP-8)', () {
    test('AC: every factory error classifies to a known kind', () {
      for (final entry in _factoryErrors.entries) {
        for (final platform in _platforms) {
          for (final isWeb in [false, true]) {
            final view = StartFailureView.from(
              entry.value(),
              platform: platform,
              isWeb: isWeb,
            );
            expect(
              StartFailureKind.values,
              contains(view.kind),
              reason: '${entry.key} on $platform isWeb=$isWeb',
            );
          }
        }
      }
    });

    // Table-pinned: each factory maps to exactly this kind and this panel
    // copy, so a swapped title, body or kind fails one named row.
    final pinned =
        <
          String,
          ({
            RecordingError Function() factory,
            StartFailureKind kind,
            String title,
            String body,
          })
        >{
          'permissionDenied': (
            factory: RecordingErrorFactories.permissionDenied,
            kind: StartFailureKind.micDenied,
            title: 'md-title',
            body: 'md-body',
          ),
          'permissionPermanentlyDenied': (
            factory: RecordingErrorFactories.permissionPermanentlyDenied,
            kind: StartFailureKind.micPermanentlyDenied,
            title: 'mpd-title',
            body: 'mpd-body',
          ),
          'engineInitFailed': (
            factory: RecordingErrorFactories.engineInitFailed,
            kind: StartFailureKind.engineInitFailed,
            title: 'eif-title',
            body: 'eif-body',
          ),
          'engineStartFailed': (
            factory: RecordingErrorFactories.engineStartFailed,
            kind: StartFailureKind.engineStartFailed,
            title: 'esf-title',
            body: 'esf-body',
          ),
          'onDeviceRecognitionUnavailable': (
            factory: RecordingErrorFactories.onDeviceRecognitionUnavailable,
            kind: StartFailureKind.onDeviceUnavailable,
            title: 'od-title',
            body: 'od-body',
          ),
          // The two that fall through to `other` show their own message.
          'engineRequiresModelDownload': (
            factory: RecordingErrorFactories.engineRequiresModelDownload,
            kind: StartFailureKind.other,
            title: 'other-title',
            body: RecordingErrorFactories.engineRequiresModelDownload().message,
          ),
          'localeNotSupported': (
            factory: () => RecordingErrorFactories.localeNotSupported('en-GB'),
            kind: StartFailureKind.other,
            title: 'other-title',
            body: RecordingErrorFactories.localeNotSupported('en-GB').message,
          ),
        };

    test('every factory is pinned in the table', () {
      expect(
        pinned.keys.toSet(),
        _factoryErrors.keys.map((k) => k.replaceAll('(', '')).toSet(),
      );
    });

    for (final entry in pinned.entries) {
      test('${entry.key}: kind, title and body', () {
        final view = StartFailureView.from(
          entry.value.factory(),
          platform: TargetPlatform.android,
          isWeb: false,
        );

        expect(view.kind, entry.value.kind);
        expect(view.title(_strings), entry.value.title);
        expect(view.body(_strings), entry.value.body);
      });
    }

    test('AC: showOpenSettings is true exactly on iOS and Android for '
        'micPermanentlyDenied and engineInitFailed', () {
      for (final entry in _factoryErrors.entries) {
        for (final platform in _platforms) {
          for (final isWeb in [false, true]) {
            final view = StartFailureView.from(
              entry.value(),
              platform: platform,
              isWeb: isWeb,
            );
            final mobile =
                !isWeb &&
                (platform == TargetPlatform.iOS ||
                    platform == TargetPlatform.android);
            final expected =
                mobile &&
                (view.kind == StartFailureKind.micPermanentlyDenied ||
                    view.kind == StartFailureKind.engineInitFailed);

            expect(
              view.showOpenSettings,
              expected,
              reason:
                  '${entry.key} kind=${view.kind} '
                  'platform=$platform isWeb=$isWeb',
            );
          }
        }
      }
    });

    test('AC: on-device unavailability never offers Open settings', () {
      for (final platform in _platforms) {
        for (final isWeb in [false, true]) {
          final view = StartFailureView.from(
            RecordingErrorFactories.onDeviceRecognitionUnavailable(),
            platform: platform,
            isWeb: isWeb,
          );
          expect(view.kind, StartFailureKind.onDeviceUnavailable);
          expect(view.showOpenSettings, isFalse);
        }
      }
    });

    test('AC: "Try again" is offered for every kind', () {
      for (final platform in _platforms) {
        for (final entry in _factoryErrors.entries) {
          final view = StartFailureView.from(
            entry.value(),
            platform: platform,
            isWeb: false,
          );
          expect(view.showTryAgain, isTrue, reason: entry.key);
        }
      }
    });

    test(
      'AC: engineRequiresModelDownload is other, not onDeviceUnavailable',
      () {
        // That message means the engine needs its own model downloaded
        // (Sherpa-ONNX). Showing "this device cannot do on-device speech" for
        // it would be false, so it falls through to other with its own
        // message.
        final error = RecordingErrorFactories.engineRequiresModelDownload();
        for (final platform in _platforms) {
          for (final isWeb in [false, true]) {
            final view = StartFailureView.from(
              error,
              platform: platform,
              isWeb: isWeb,
            );
            expect(view.kind, StartFailureKind.other);
            expect(view.showOpenSettings, isFalse);
            expect(view.body(_strings), error.message);
          }
        }
      },
    );

    test('AC: localeNotSupported is other and shows its own message', () {
      final error = RecordingErrorFactories.localeNotSupported('en-GB');
      final view = StartFailureView.from(
        error,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(view.kind, StartFailureKind.other);
      expect(view.body(_strings), error.message);
    });

    test('AC: an unrecognised message falls back to other', () {
      final view = StartFailureView.from(
        RecordingError(
          message: 'something nobody classified',
          severity: RecordingErrorSeverity.fatal,
          timestamp: DateTime.now(),
        ),
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(view.kind, StartFailureKind.other);
      expect(view.showOpenSettings, isFalse);
      // Other shows the error's own message.
      expect(view.body(_strings), 'something nobody classified');
    });

    // PBT-10 / TP-8: total and deterministic. The same error and platform
    // always give the same classification, and no input throws.
    pbt.Glados<(int, int, bool)>(
      pbt.any.combine3(
        pbt.any.intInRange(0, _factoryErrors.length),
        pbt.any.intInRange(0, _platforms.length),
        pbt.any.boolGen,
        (errorIndex, platformIndex, isWeb) =>
            (errorIndex, platformIndex, isWeb),
      ),
    ).test('TP-8: classification is total and deterministic', (input) {
      final (errorIndex, platformIndex) = (input.$1, input.$2);
      final isWeb = input.$3;
      final errors = _factoryErrors.values.toList();
      final error = errors[errorIndex]();
      final platform = _platforms[platformIndex];

      final first = StartFailureView.from(
        error,
        platform: platform,
        isWeb: isWeb,
      );
      final second = StartFailureView.from(
        error,
        platform: platform,
        isWeb: isWeb,
      );

      expect(first.kind, second.kind);
      expect(first.showOpenSettings, second.showOpenSettings);
      expect(first.showTryAgain, second.showTryAgain);
    });
  });

  group('StartFailurePanel widget', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      StartFailureView view, {
      VoidCallback? onTryAgain,
      VoidCallback? onOpenSettings,
      VoidCallback? onBack,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartFailurePanel(
              view: view,
              strings: _strings,
              onTryAgain: onTryAgain ?? () {},
              onOpenSettings: onOpenSettings,
              onBack: onBack ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders the kind text from the strings, not literals', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingErrorFactories.onDeviceRecognitionUnavailable(),
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
      );

      expect(find.text('od-title'), findsOneWidget);
      expect(find.text('od-body'), findsOneWidget);
    });

    testWidgets('always offers Try again', (tester) async {
      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingErrorFactories.onDeviceRecognitionUnavailable(),
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
      );

      expect(find.text('try-again-label'), findsOneWidget);
    });

    testWidgets('"Try again" invokes its callback', (tester) async {
      var tries = 0;
      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingErrorFactories.engineStartFailed(),
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        onTryAgain: () => tries++,
      );

      await tester.tap(find.text('try-again-label'));
      await tester.pump();

      expect(tries, 1);
    });

    testWidgets('shows Open settings only when the view allows it', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingErrorFactories.permissionPermanentlyDenied(),
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        onOpenSettings: () {},
      );
      expect(find.text('open-settings-label'), findsOneWidget);

      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingErrorFactories.onDeviceRecognitionUnavailable(),
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        onOpenSettings: () {},
      );
      expect(find.text('open-settings-label'), findsNothing);
    });

    testWidgets('"Open settings" invokes its callback', (tester) async {
      var opened = 0;
      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingErrorFactories.engineInitFailed(),
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
        onOpenSettings: () => opened++,
      );

      await tester.tap(find.text('open-settings-label'));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('always offers Back, which invokes its callback', (
      tester,
    ) async {
      var backs = 0;
      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingErrorFactories.permissionDenied(),
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        onBack: () => backs++,
      );

      expect(find.text('back-label'), findsOneWidget);
      await tester.tap(find.text('back-label'));
      await tester.pump();

      expect(backs, 1);
    });

    testWidgets("the other kind shows the error's own message", (
      tester,
    ) async {
      await pumpPanel(
        tester,
        StartFailureView.from(
          RecordingError(
            message: 'unclassified',
            severity: RecordingErrorSeverity.fatal,
            timestamp: DateTime.now(),
          ),
          platform: TargetPlatform.macOS,
          isWeb: false,
        ),
      );

      expect(find.text('other-title'), findsOneWidget);
      expect(find.text('unclassified'), findsOneWidget);
      expect(find.text('other-body'), findsNothing);
    });
  });
}
