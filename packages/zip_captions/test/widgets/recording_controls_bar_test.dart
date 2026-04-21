import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/widgets/recording_controls_bar.dart';
import 'package:zip_core/zip_core.dart';

Widget _wrap(
  RecordingState state, {
  VoidCallback? onPause,
  VoidCallback? onResume,
  VoidCallback? onStop,
}) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Scaffold(
      body: RecordingControlsBar(
        state: state,
        onPause: onPause ?? () {},
        onResume: onResume ?? () {},
        onStop: onStop ?? () {},
      ),
    ),
  );
}

void main() {
  group('RecordingControlsBar', () {
    group('idle state', () {
      testWidgets('shows spinner', (tester) async {
        await tester.pumpWidget(_wrap(const RecordingState.idle()));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('does not show stop button', (tester) async {
        await tester.pumpWidget(_wrap(const RecordingState.idle()));
        expect(find.byIcon(Icons.stop), findsNothing);
      });
    });

    group('recording state', () {
      testWidgets('shows pause button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.recording(sessionId: 's')),
        );
        expect(find.byIcon(Icons.pause), findsOneWidget);
      });

      testWidgets('shows stop button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.recording(sessionId: 's')),
        );
        expect(find.byIcon(Icons.stop), findsOneWidget);
      });

      testWidgets('does not show resume button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.recording(sessionId: 's')),
        );
        expect(find.byIcon(Icons.play_arrow), findsNothing);
      });

      testWidgets('pause button fires onPause callback', (tester) async {
        var called = false;
        await tester.pumpWidget(
          _wrap(
            const RecordingState.recording(sessionId: 's'),
            onPause: () => called = true,
          ),
        );
        await tester.tap(find.byIcon(Icons.pause));
        expect(called, isTrue);
      });

      testWidgets('stop button fires onStop callback', (tester) async {
        var called = false;
        await tester.pumpWidget(
          _wrap(
            const RecordingState.recording(sessionId: 's'),
            onStop: () => called = true,
          ),
        );
        await tester.tap(find.byIcon(Icons.stop));
        expect(called, isTrue);
      });
    });

    group('paused state', () {
      testWidgets('shows resume button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.paused(sessionId: 's')),
        );
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      });

      testWidgets('shows stop button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.paused(sessionId: 's')),
        );
        expect(find.byIcon(Icons.stop), findsOneWidget);
      });

      testWidgets('does not show pause button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.paused(sessionId: 's')),
        );
        expect(find.byIcon(Icons.pause), findsNothing);
      });

      testWidgets('resume button fires onResume callback', (tester) async {
        var called = false;
        await tester.pumpWidget(
          _wrap(
            const RecordingState.paused(sessionId: 's'),
            onResume: () => called = true,
          ),
        );
        await tester.tap(find.byIcon(Icons.play_arrow));
        expect(called, isTrue);
      });
    });

    group('reconnecting state', () {
      testWidgets('shows spinner', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.reconnecting(sessionId: 's')),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows stop button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.reconnecting(sessionId: 's')),
        );
        expect(find.byIcon(Icons.stop), findsOneWidget);
      });
    });

    group('stopped state', () {
      testWidgets('shows only stop button', (tester) async {
        await tester.pumpWidget(
          _wrap(const RecordingState.stopped(sessionId: 's')),
        );
        expect(find.byIcon(Icons.stop), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  });
}
