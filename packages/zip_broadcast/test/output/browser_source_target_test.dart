import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_server.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_target.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';

class _MockBrowserSourceServer extends Mock
    implements BrowserSourceServer {}

SttResultEvent _event({
  String text = 'hello',
  bool isFinal = true,
}) =>
    SttResultEvent(
      SttResult(
        text: text,
        isFinal: isFinal,
        confidence: 1,
        timestamp: DateTime.utc(2026),
        sourceId: 'default',
      ),
    );

void main() {
  late _MockBrowserSourceServer mockServer;
  late BrowserSourceTarget target;

  setUp(() {
    mockServer = _MockBrowserSourceServer();
    when(
      () => mockServer.pushCaption(any(), isFinal: any(named: 'isFinal')),
    ).thenReturn(null);
    when(
      () => mockServer.pushSessionState(any()),
    ).thenReturn(null);
    target = BrowserSourceTarget(server: mockServer);
  });

  test('final SttResultEvent → pushCaption(text, isFinal: true)', () {
    target.onCaptionEvent(_event());
    verify(() => mockServer.pushCaption('hello', isFinal: true)).called(1);
  });

  test('interim SttResultEvent → pushCaption(text, isFinal: false)', () {
    target.onCaptionEvent(_event(text: 'hel', isFinal: false));
    verify(
      () => mockServer.pushCaption('hel', isFinal: false),
    ).called(1);
  });

  test(
    'SessionStateEvent(recording) → pushCaption empty string',
    () {
      target.onCaptionEvent(
        const SessionStateEvent(
          RecordingState.recording(sessionId: 's1'),
        ),
      );
      verify(
        () => mockServer.pushCaption('', isFinal: false),
      ).called(1);
    },
  );

  test(
    'SessionStateEvent(stopped) → pushSessionState("stopped")',
    () {
      target.onCaptionEvent(
        const SessionStateEvent(
          RecordingState.stopped(sessionId: 's1'),
        ),
      );
      verify(() => mockServer.pushSessionState('stopped')).called(1);
    },
  );
}
