// Tests for Unit 8 (S-20): the display-enumerator event contract (BR-U8-05)
// and the io adapter's id normalisation and diff.
import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:zip_broadcast/src/output/overlay/display_enumerator.dart';
import 'package:zip_broadcast/src/output/overlay/screen_retriever_display_enumerator_io.dart';

import '../../helpers/fake_display_enumerator.dart';

DisplayInfo _display(String id, {double left = 0, bool isPrimary = false}) =>
    DisplayInfo(
      id: id,
      label: 'Display $id',
      bounds: Rect.fromLTWH(left, 0, 1920, 1080),
      scaleFactor: 1,
      isPrimary: isPrimary,
    );

/// A scriptable [ScreenEventSource]: the test decides when events fire.
class FakeScreenEventSource implements ScreenEventSource {
  final List<void Function(String event)> listeners =
      <void Function(String event)>[];

  void fire([String event = 'display-added']) {
    for (final listener in List.of(listeners)) {
      listener(event);
    }
  }

  @override
  void addListener(void Function(String event) onEvent) {
    listeners.add(onEvent);
  }

  @override
  void removeListener(void Function(String event) onEvent) {
    listeners.remove(onEvent);
  }
}

/// Builds a plugin [Display] with the fields the adapter reads.
Display _pluginDisplay({
  String id = 'plugin-id',
  String? name,
  double left = 0,
  double top = 0,
  double width = 1920,
  double height = 1080,
  num? scaleFactor = 1,
}) =>
    Display(
      id: id,
      name: name,
      size: Size(width, height),
      visiblePosition: Offset(left, top),
      visibleSize: Size(width, height),
      scaleFactor: scaleFactor,
    );

void main() {
  group('FakeDisplayEnumerator satisfies the contract', () {
    test('a late subscriber gets the current list first', () async {
      final enumerator = FakeDisplayEnumerator(
        initial: [_display('a', isPrimary: true)],
      );
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      enumerator.changes.listen(emissions.add);
      enumerator.emit([
        _display('a', isPrimary: true),
        _display('b', left: 1920),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.first.single.id, 'a');
      expect(emissions.last.map((d) => d.id), ['a', 'b']);
    });

    test('a platform error is logged and the stream stays open', () async {
      final enumerator = FakeDisplayEnumerator();
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      final errors = <Object>[];
      enumerator.changes.listen(emissions.add, onError: errors.add);

      enumerator
        ..platformError()
        ..emit([_display('a', isPrimary: true)]);
      await Future<void>.delayed(Duration.zero);

      expect(errors, isEmpty);
      expect(enumerator.log, ['display enumeration failed']);
      expect(emissions.last.single.id, 'a');
    });

    test('dispose closes the stream and is idempotent', () async {
      final enumerator = FakeDisplayEnumerator();

      final subscription = enumerator.changes.listen((_) {});
      await enumerator.dispose();
      await enumerator.dispose();
      await subscription.cancel();

      expect(enumerator.isClosed, isTrue);
      expect(enumerator.calls.where((call) => call == 'dispose').length, 2);
    });
  });

  group('ScreenRetrieverDisplayEnumerator', () {
    test('the first emission to a late subscriber is the current list',
        () async {
      final source = FakeScreenEventSource();
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () async => [_pluginDisplay(id: 'a')],
      );
      addTearDown(enumerator.dispose);

      // No platform event has fired yet.
      final first = await enumerator.changes.first;

      expect(first.single.id, 'a');
    });

    test('a connect emits the new list', () async {
      final source = FakeScreenEventSource();
      var displays = [_pluginDisplay(id: 'a')];
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () async => displays,
      );
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      enumerator.changes.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      displays = [
        _pluginDisplay(id: 'a'),
        _pluginDisplay(id: 'b', left: 1920),
      ];
      source.fire();
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.map((d) => d.id), ['a', 'b']);
    });

    test('a disconnect emits the list without the removed display', () async {
      final source = FakeScreenEventSource();
      var displays = [
        _pluginDisplay(id: 'a'),
        _pluginDisplay(id: 'b', left: 1920),
      ];
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () async => displays,
      );
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      enumerator.changes.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      displays = [_pluginDisplay(id: 'a')];
      source.fire('display-removed');
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.map((d) => d.id), ['a']);
    });

    test('a same-id list with changed bounds is emitted', () async {
      final source = FakeScreenEventSource();
      var displays = [_pluginDisplay(id: 'a')];
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () async => displays,
      );
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      enumerator.changes.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);
      final before = emissions.length;

      displays = [_pluginDisplay(id: 'a', left: 200)];
      source.fire();
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, before + 1);
    });

    test('an identical list is not emitted', () async {
      final source = FakeScreenEventSource();
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () async => [_pluginDisplay(id: 'a')],
      );
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      enumerator.changes.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);
      final before = emissions.length;

      source.fire();
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, before);
    });

    test('a platform error is logged and the stream stays open', () async {
      final source = FakeScreenEventSource();
      final logged = <String>[];
      var fail = false;
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () async {
          if (fail) throw StateError('no platform');
          return [_pluginDisplay(id: 'a')];
        },
        logWarning: logged.add,
      );
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      final errors = <Object>[];
      enumerator.changes.listen(emissions.add, onError: errors.add);
      await Future<void>.delayed(Duration.zero);

      fail = true;
      source.fire();
      await Future<void>.delayed(Duration.zero);

      expect(errors, isEmpty);
      expect(logged, ['display enumeration failed']);

      // Recovering after the failure still emits.
      fail = false;
      source.fire();
      await Future<void>.delayed(Duration.zero);
      expect(emissions, isNotEmpty);
    });

    test('dispose is idempotent and removes the platform listener', () async {
      final source = FakeScreenEventSource();
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () async => [_pluginDisplay(id: 'a')],
      );

      enumerator.changes.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(source.listeners, hasLength(1));

      await enumerator.dispose();
      await enumerator.dispose();

      expect(source.listeners, isEmpty);
    });

    test('cancelling before the first read resolves emits nothing and does '
        'not throw', () async {
      final source = FakeScreenEventSource();
      final read = Completer<List<Display>>();
      final enumerator = ScreenRetrieverDisplayEnumerator(
        eventSource: source,
        readDisplays: () => read.future,
      );
      addTearDown(enumerator.dispose);

      final emissions = <List<DisplayInfo>>[];
      final subscription = enumerator.changes.listen(emissions.add);
      await subscription.cancel();

      read.complete([_pluginDisplay(id: 'a')]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isEmpty);
      expect(source.listeners, isEmpty);
    });
  });

  group('id normalisation', () {
    test('a non-empty plugin id wins', () {
      final displays =
          ScreenRetrieverDisplayEnumerator.normalizeDisplays([
        _pluginDisplay(id: 'platform-handle', name: 'LG UltraFine'),
      ]);

      expect(displays.single.id, 'platform-handle');
    });

    test('an empty plugin id falls back to the name', () {
      final displays =
          ScreenRetrieverDisplayEnumerator.normalizeDisplays([
        _pluginDisplay(id: '', name: 'VGA-1'),
      ]);

      expect(displays.single.id, 'VGA-1');
    });

    test('a repeated fallback name is suffixed with its position', () {
      final displays =
          ScreenRetrieverDisplayEnumerator.normalizeDisplays([
        _pluginDisplay(id: '', name: 'VGA-1'),
        _pluginDisplay(id: '', name: 'VGA-1', left: 1920),
      ]);

      expect(displays.map((d) => d.id), ['VGA-1#1', 'VGA-1#2']);
    });

    test('an empty id and name fall back to the list position', () {
      final displays =
          ScreenRetrieverDisplayEnumerator.normalizeDisplays([
        _pluginDisplay(id: ''),
        _pluginDisplay(id: '', left: 1920),
      ]);

      expect(displays.map((d) => d.id), ['display-0', 'display-1']);
    });

    test('the empty label is kept and the first display is primary', () {
      final displays =
          ScreenRetrieverDisplayEnumerator.normalizeDisplays([
        _pluginDisplay(id: 'a'),
        _pluginDisplay(id: 'b', left: 1920),
      ]);

      expect(displays.first.label, isEmpty);
      expect(displays.map((d) => d.isPrimary), [true, false]);
    });

    test('bounds come from the visible position and size', () {
      final displays =
          ScreenRetrieverDisplayEnumerator.normalizeDisplays([
        _pluginDisplay(id: 'a', left: -1600, top: 25, width: 1600, height: 900),
      ]);

      expect(displays.single.bounds, const Rect.fromLTWH(-1600, 25, 1600, 900));
    });

    test('a missing scale factor becomes 0 and is passed through otherwise', () {
      final displays =
          ScreenRetrieverDisplayEnumerator.normalizeDisplays([
        _pluginDisplay(id: 'a', scaleFactor: null),
        _pluginDisplay(id: 'b', scaleFactor: 1.5, left: 1920),
      ]);

      expect(displays.map((d) => d.scaleFactor), [0, 1.5]);
    });
  });
}
