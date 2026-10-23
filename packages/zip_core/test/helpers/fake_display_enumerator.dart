import 'dart:async';
import 'dart:ui';

import 'package:zip_core/src/output/overlay/display_enumerator.dart';

/// A scriptable [DisplayEnumerator] used by the contract test and by the
/// controller's fakes.
///
/// It implements the published event contract by hand so the contract test
/// asserts the contract itself, not the adapter's copy of it.
class FakeDisplayEnumerator implements DisplayEnumerator {
  /// Creates a fake seeded with [initial].
  FakeDisplayEnumerator({List<DisplayInfo>? initial})
      : _current = initial ?? const <DisplayInfo>[];

  List<DisplayInfo> _current;
  bool _disposed = false;
  bool _closed = false;
  /// Each subscriber's sink, so [emit] reaches them and [dispose] can close
  /// them. Built by hand rather than with a controller so that `cancel()`
  /// completes synchronously under `fakeAsync`.
  final List<MultiStreamController<List<DisplayInfo>>> _sinks =
      <MultiStreamController<List<DisplayInfo>>>[];

  /// Every call to [displays] and to [emit].
  final List<String> calls = <String>[];

  /// Simulates a platform event carrying a new list.
  void emit(List<DisplayInfo> next) {
    calls.add('emit');
    if (_disposed) return;
    _current = next;
    for (final sink in List.of(_sinks)) {
      sink.add(next);
    }
  }

  /// Simulates a platform failure: logged, no error on the stream, stays open.
  void platformError() {
    calls.add('platformError');
    log.add('display enumeration failed');
  }

  /// Fixed strings the fake "logged", mirroring the adapter's redacted log.
  final List<String> log = <String>[];

  bool get isDisposed => _disposed;

  @override
  Future<List<DisplayInfo>> displays() async {
    calls.add('displays');
    return _current;
  }

  bool get isClosed => _closed;

  @override
  Stream<List<DisplayInfo>> get changes {
    calls.add('changes');
    return Stream<List<DisplayInfo>>.multi((sink) {
      if (_closed) {
        unawaited(sink.close());
        return;
      }
      // The contract's first emission is the current list, to a listener that
      // subscribed at any time.
      sink.onCancel = () => _sinks.remove(sink);
      // The contract's first emission is the current list, to a listener that
      // subscribed at any time.
      _sinks.add(sink);
      sink.add(_current);
    });
  }

  @override
  Future<Size?> primarySize() async {
    calls.add('primarySize');
    return null;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    for (final sink in List.of(_sinks)) {
      unawaited(sink.close());
    }
    _sinks.clear();
  }
}
