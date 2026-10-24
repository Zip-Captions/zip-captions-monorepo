import 'dart:async';
import 'dart:ui';

import 'package:zip_core/overlay.dart';

/// A scriptable [DisplayEnumerator] for the app's own window tests.
///
/// `zip_core` has its own copy under `test/helpers/`, but an app cannot import
/// another package's `test/` directory, so this one exists for the tests that
/// still build a controller directly.
class FakeDisplayEnumerator implements DisplayEnumerator {
  /// Creates a fake seeded with [initial].
  FakeDisplayEnumerator({List<DisplayInfo>? initial})
      : _current = initial ?? const <DisplayInfo>[];

  List<DisplayInfo> _current;
  bool _disposed = false;
  bool _closed = false;
  final List<MultiStreamController<List<DisplayInfo>>> _sinks =
      <MultiStreamController<List<DisplayInfo>>>[];

  /// Simulates a platform event carrying a new list.
  void emit(List<DisplayInfo> next) {
    if (_disposed) return;
    _current = next;
    for (final sink in List.of(_sinks)) {
      sink.add(next);
    }
  }

  /// Whether [dispose] has run.
  bool get isDisposed => _disposed;

  @override
  Future<List<DisplayInfo>> displays() async => _current;

  @override
  Stream<List<DisplayInfo>> get changes {
    return Stream<List<DisplayInfo>>.multi((sink) {
      if (_closed) {
        unawaited(sink.close());
        return;
      }
      sink.onCancel = () => _sinks.remove(sink);
      _sinks.add(sink);
      sink.add(_current);
    });
  }

  @override
  Future<Size?> primarySize() async => null;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    for (final sink in List.of(_sinks)) {
      unawaited(sink.close());
    }
    _sinks.clear();
  }
}
