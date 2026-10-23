import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:zip_core/src/output/overlay/display_enumerator.dart';

/// The platform's screen-change notifications, as the adapter needs them.
///
/// A plain interface so the adapter's re-read-and-diff logic and its id
/// normalisation can be tested without loading the plugin's platform channel.
abstract interface class ScreenEventSource {
  /// Starts delivering platform screen events to [onEvent].
  void addListener(void Function(String event) onEvent);

  /// Stops delivering events to the listener added by [addListener].
  void removeListener(void Function(String event) onEvent);
}

/// [ScreenEventSource] backed by `screen_retriever`'s singleton.
class ScreenRetrieverEventSource implements ScreenEventSource {
  final _ScreenListenerAdapter _adapter = _ScreenListenerAdapter();

  @override
  void addListener(void Function(String event) onEvent) {
    _adapter.onEvent = onEvent;
    ScreenRetriever.instance.addListener(_adapter);
  }

  @override
  void removeListener(void Function(String event) onEvent) {
    ScreenRetriever.instance.removeListener(_adapter);
    if (_adapter.onEvent == onEvent) _adapter.onEvent = null;
  }
}

/// Bridges the plugin's `ScreenListener` mixin to a plain function.
class _ScreenListenerAdapter with ScreenListener {
  void Function(String event)? onEvent;

  @override
  void onScreenEvent(String eventName) => onEvent?.call(eventName);
}

/// [DisplayEnumerator] backed by `screen_retriever` 0.2.2.
///
/// **This is the only file in the package that imports the plugin** (ID-3,
/// SECURITY-10 section 5 item 4). It owns three things:
///
/// 1. **Id normalisation.** Linux reports `""` for every monitor, so the id
///    falls back to the name and then to the list position; a repeated name is
///    suffixed with `#<position>` so ids stay unique.
/// 2. **The re-read-and-diff path.** The plugin's events carry no payload and
///    cover only add/remove, so every event re-reads the whole list and
///    compares it with the last emitted one. That single path produces first
///    emission, connect, disconnect, rearrangement and duplicate suppression.
/// 3. **The event contract's error rule.** A platform failure is logged with a
///    fixed string and the stream stays open.
class ScreenRetrieverDisplayEnumerator implements DisplayEnumerator {
  /// Creates the production enumerator.
  ///
  /// [eventSource] and [readDisplays] exist for tests; production callers pass
  /// neither.
  ScreenRetrieverDisplayEnumerator({
    ScreenEventSource? eventSource,
    Future<List<Display>> Function()? readDisplays,
    void Function(String message)? logWarning,
  })  : _eventSource = eventSource ?? ScreenRetrieverEventSource(),
        _readDisplays = readDisplays ?? ScreenRetriever.instance.getAllDisplays,
        _logWarning = logWarning;

  final ScreenEventSource _eventSource;
  final Future<List<Display>> Function() _readDisplays;
  final void Function(String message)? _logWarning;

  final StreamController<List<DisplayInfo>> _controller =
      StreamController<List<DisplayInfo>>.broadcast();

  List<DisplayInfo>? _last;
  bool _listening = false;
  bool _disposed = false;

  @override
  Future<List<DisplayInfo>> displays() async {
    final displays = normalizeDisplays(await _readDisplays());
    _last = displays;
    return displays;
  }

  @override
  Stream<List<DisplayInfo>> get changes {
    // The platform listener starts on the first Dart listener and stops when
    // the last one leaves, so the plugin's observer is never leaked.
    _controller.onListen = _startListening;
    _controller.onCancel = _stopListening;
    return Stream<List<DisplayInfo>>.multi((controller) {
      // First emission to any subscriber, per the contract.
      final last = _last;
      if (last != null) {
        controller.add(last);
      } else {
        unawaited(
          displays().then(
            controller.add,
            onError: (Object _) => _reportFailure(),
          ),
        );
      }
      final subscription = _controller.stream.listen(
        controller.add,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<Size?> primarySize() async {
    try {
      final primary = await ScreenRetriever.instance.getPrimaryDisplay();
      return primary.size;
    } on Object {
      _reportFailure();
      return null;
    }
  }

  void _startListening() {
    if (_listening || _disposed) return;
    _listening = true;
    _eventSource.addListener(_onScreenEvent);
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    _eventSource.removeListener(_onScreenEvent);
  }

  Future<void> _onScreenEvent(String event) async {
    try {
      final next = normalizeDisplays(await _readDisplays());
      if (_last != null && _listsEqual(_last!, next)) return;
      _last = next;
      if (!_controller.isClosed) _controller.add(next);
    } on Object {
      _reportFailure();
    }
  }

  void _reportFailure() {
    // Fixed string, no display detail (BR-U8-18). The stream stays open.
    _logWarning?.call('display enumeration failed');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopListening();
    await _controller.close();
  }

  static bool _listsEqual(List<DisplayInfo> a, List<DisplayInfo> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Normalises a plugin display list into [DisplayInfo]s.
  ///
  /// Ids, in order: the plugin's non-empty `id`; otherwise the non-empty
  /// `name`, suffixed with `#<position>` when that name repeats; otherwise
  /// `display-<index>`. `scaleFactor` passes through, `0` included (the frame
  /// conversion treats it as 1). Exactly one display is primary: the plugin's
  /// first `main` display, otherwise the first display in platform order.
  static List<DisplayInfo> normalizeDisplays(List<Display> displays) {
    final nameCounts = <String, int>{};
    for (final display in displays) {
      final name = display.name ?? '';
      if (display.id.isEmpty && name.isNotEmpty) {
        nameCounts[name] = (nameCounts[name] ?? 0) + 1;
      }
    }

    final usedNames = <String, int>{};
    // Exactly one display is primary: the first in platform order (A-4).
    final result = <DisplayInfo>[];
    for (var index = 0; index < displays.length; index++) {
      final display = displays[index];
      final name = display.name ?? '';

      final String id;
      if (display.id.isNotEmpty) {
        id = display.id;
      } else if (name.isNotEmpty) {
        final seen = (usedNames[name] ?? 0) + 1;
        usedNames[name] = seen;
        id = (nameCounts[name] ?? 0) > 1 ? '$name#$seen' : name;
      } else {
        id = 'display-$index';
      }


      result.add(
        DisplayInfo(
          id: id,
          label: name,
          bounds: Rect.fromLTWH(
            display.visiblePosition?.dx ?? 0,
            display.visiblePosition?.dy ?? 0,
            display.visibleSize?.width ?? display.size.width,
            display.visibleSize?.height ?? display.size.height,
          ),
          scaleFactor: display.scaleFactor?.toDouble() ?? 0,
          // The plugin exposes no primary flag on 0.2.2's Display model, so the
          // first display in platform order is primary (A-4).
          isPrimary: index == 0,
        ),
      );
    }
    return result;
  }
}
