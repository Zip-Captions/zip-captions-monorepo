// Z25: no caption text reaches any log or telemetry sink on a pop-out path
// (BR-PIP-11, §8.8 item 18).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/output/overlay/pop_out_caption_target.dart';
import 'package:zip_captions/src/providers/pop_out_providers.dart';
import 'package:zip_captions/src/shell/zc_app_shell.dart';
import 'package:zip_captions/src/widgets/pop_out_controls.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

import '../helpers/fake_pop_out_controller.dart';
import '../helpers/fake_recording_state_notifier.dart';

/// A caption string distinctive enough that any log carrying it is a leak.
const _secret = 'SECRET-CAPTION-TEXT-9F3A';

const _strings = ZcStrings.fromMap({
  'popOutEnter': 'enter',
  'popOutExit': 'exit',
  'popOutHint': 'hint',
  'popOutReturn': 'return',
  'popOutUnavailableNoSession': 'no-session',
  'popOutUnavailableNoEngine': 'no-engine',
  'popOutOpenFailed': 'open-failed',
  'navJoinBroadcast': 'Join Broadcast',
});

class _Window implements DesktopWindowService {
  final List<String> calls = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    return 7;
  }

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async =>
      calls.add('invokeMethod');

  @override
  Future<void> setFrame(int windowId, Rect frame) async =>
      calls.add('setFrame');

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

class _Handler {
  OverlayMethodHandler? handler;

  // Named as a method, matching this project's `_FakeAuthNotifier.setState`
  // precedent, not a setter.
  // ignore: use_setters_to_change_properties
  void install(OverlayMethodHandler? next) => handler = next;
}

/// The caption surface the pop-out's in-surface toggle lives in.
///
/// A stand-in for `RecordingScreen`, which pulls in a router, a recording
/// notifier and the history invalidation: the audit needs the toggle and the
/// banner, and nothing else.
class _Surface extends StatelessWidget {
  const _Surface();

  @override
  Widget build(BuildContext context) {
    final popOut = PopOutScope.of(context);
    return Scaffold(
      body: Column(
        children: [
          if (popOut?.enabled ?? false)
            PopOutBanner(onReturn: popOut!.onToggle),
          if (popOut != null)
            PopOutInSurfaceToggle(
              isPoppedOut: popOut.enabled,
              onToggle: popOut.onToggle,
            ),
        ],
      ),
    );
  }
}

/// A shell with no routes beyond the caption surface, so the chrome exists.
GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ZcAppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const _Surface(),
            ),
          ],
        ),
      ],
    );

void main() {
  late List<LogRecord> records;
  late StreamSubscription<LogRecord> subscription;

  setUp(() {
    records = <LogRecord>[];
    hierarchicalLoggingEnabled = true;
    Logger.root.level = Level.ALL;
    subscription = Logger.root.onRecord.listen(records.add);
  });

  tearDown(() async {
    await subscription.cancel();
    Logger.root.level = Level.OFF;
  });

  test('the target logs nothing, even for a snapshot carrying text', () async {
    final window = _Window();
    final handler = _Handler();
    final controller = OverlayWindowController(
      windowService: window,
      enumerator: EmptyDisplayEnumerator(),
      handlerInstaller: handler.install,
      log: Logger('test.redaction'),
      mode: const PopOutMode(),
    );
    final bus = CaptionBus();
    final registry = CaptionOutputTargetRegistry(bus);
    final screen = OnScreenCaptionTarget(targetId: 'on_screen');
    final target = PopOutCaptionTarget(
      controller: controller,
      registry: registry,
      displaySettings: DisplaySettings.defaults,
    );

    registry
      ..add(screen)
      ..add(target);
    unawaited(target.show(const OverlayConfig(mode: PopOutMode())));
    await Future<void>.delayed(Duration.zero);
    await handler.handler!('overlayReady', 7);
    await Future<void>.delayed(Duration.zero);

    bus
      ..publish(
        const SessionStateEvent(RecordingState.recording(sessionId: 's')),
      )
      ..publish(
        SttResultEvent(
          SttResult(
            text: _secret,
            isFinal: true,
            confidence: 1,
            timestamp: DateTime.utc(2026),
            sourceId: 'default',
          ),
        ),
      );
    // The on-screen target debounces at 50 ms and the pop-out coalesces at
    // 16 ms, so the frame leaves the target after two short waits.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await Future<void>.delayed(
      const Duration(milliseconds: 20),
    );

    // The text did travel: the target pushed a frame to the window.
    expect(window.calls, contains('invokeMethod'));
    // Every record is clean. A record's `error` is checked as text too, since
    // an exception message would carry it just as effectively.
    for (final record in records) {
      expect(record.message, isNot(contains(_secret)));
      expect('${record.error}', isNot(contains(_secret)));
    }
  });

  testWidgets('toggling in the app logs no caption text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          transcriptWriterTargetProvider.overrideWith((_) {}),
          recordingStateNotifierProvider.overrideWith(
            () => FakeRecordingStateNotifier(
              const RecordingState.recording(sessionId: 's'),
            ),
          ),
          onScreenCaptionTargetProvider.overrideWith(
            (ref) => Stream<List<CaptionDisplayEntry>>.value([
              CaptionDisplayEntry(
                entryId: 'e1',
                sessionId: 's',
                sourceId: 'default',
                text: _secret,
                isFinal: true,
                timestamp: DateTime.utc(2026),
              ),
            ]),
          ),
          zcStringsProvider.overrideWith((ref) async => _strings),
          sttEngineProvider.overrideWithValue(FakeSttEngine()),
          popOutWindowControllerProvider.overrideWithValue(
            fakePopOutController(),
          ),
          displayListProvider.overrideWith(
            (ref) => Stream<List<DisplayInfo>>.value(const <DisplayInfo>[]),
          ),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popOutReturn')));
    await tester.pumpAndSettle();

    for (final record in records) {
      expect(record.message, isNot(contains(_secret)));
      expect('${record.error}', isNot(contains(_secret)));
    }
  });
}
