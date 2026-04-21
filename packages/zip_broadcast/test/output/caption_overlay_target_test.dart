import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_target.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/stt_result.dart';

import '../helpers/mock_desktop_window_service.dart';

const _config = OverlayConfig();

SttResultEvent _finalEvent(String text) => SttResultEvent(
      SttResult(
        text: text,
        isFinal: true,
        confidence: 1,
        timestamp: DateTime.utc(2026),
        sourceId: 'default',
      ),
    );

void main() {
  late MockDesktopWindowService mockService;
  late CaptionOverlayTarget target;

  setUp(() {
    mockService = MockDesktopWindowService();
    when(() => mockService.isSupported).thenReturn(true);
    when(() => mockService.createWindow(any()))
        .thenAnswer((_) async => 42);
    when(() => mockService.closeWindow(any<int>()))
        .thenAnswer((_) async {});
    when(
      () => mockService.invokeMethod(any<int>(), any<String>(), any<Object?>()),
    ).thenAnswer((_) async {});

    target = CaptionOverlayTarget(windowService: mockService);
  });

  tearDown(() async {
    await target.dispose();
  });

  group('show()', () {
    test('on fresh target → createWindow() called once; isVisible = true',
        () async {
      await target.show(_config);

      verify(() => mockService.createWindow(any())).called(1);
      expect(target.isVisible, isTrue);
    });

    test('when already visible → no second createWindow()', () async {
      await target.show(_config);
      await target.show(_config);

      verify(() => mockService.createWindow(any())).called(1);
    });

    test(
      'when already visible → invokeMethod("updateConfig", ...) called',
      () async {
        await target.show(_config);
        await target.show(_config);

        verify(
          () => mockService.invokeMethod(42, 'updateConfig', any<String>()),
        ).called(1);
      },
    );

    test('isSupported == false → no-op; isVisible stays false', () async {
      when(() => mockService.isSupported).thenReturn(false);
      await target.show(_config);

      verifyNever(() => mockService.createWindow(any<String>()));
      expect(target.isVisible, isFalse);
    });
  });

  group('hide()', () {
    test('closeWindow() called; isVisible = false', () async {
      await target.show(_config);
      await target.hide();

      verify(() => mockService.closeWindow(42)).called(1);
      expect(target.isVisible, isFalse);
    });

    test('no-op when already hidden', () async {
      await target.hide(); // nothing shown yet

      verifyNever(() => mockService.closeWindow(any<int>()));
    });
  });

  group('dispose()', () {
    test('when visible → closeWindow() called', () async {
      await target.show(_config);
      await target.dispose();

      verify(() => mockService.closeWindow(42)).called(1);
    });
  });

  group('onCaptionEvent()', () {
    test('when not visible → invokeMethod not called', () {
      target.onCaptionEvent(_finalEvent('hello'));

      verifyNever(
        () => mockService.invokeMethod(
              any<int>(), any<String>(), any<Object?>()),
      );
    });

    test('when visible → invokeMethod("captionUpdate", ...) called',
        () async {
      await target.show(_config);
      target.onCaptionEvent(_finalEvent('hello'));

      verify(
        () => mockService.invokeMethod(42, 'captionUpdate', any<String>()),
      ).called(1);
    });
  });
}
