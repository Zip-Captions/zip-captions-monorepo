import 'dart:async';
import 'dart:ui';

import 'package:zip_broadcast/src/output/overlay/display_enumerator.dart';

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
  final StreamController<List<DisplayInfo>> _controller =
      StreamController<List<DisplayInfo>>.broadcast();

  /// Every call to [displays] and to [emit].
  final List<String> calls = <String>[];

  /// Simulates a platform event carrying a new list.
  void emit(List<DisplayInfo> next) {
    calls.add('emit');
    if (_disposed) return;
    _current = next;
    _controller.add(next);
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

  bool get isClosed => _controller.isClosed;

  @override
  Stream<List<DisplayInfo>> get changes {
    calls.add('changes');
    // The contract's first-emission rule: a listener that subscribes at any
    // time gets the current list.
    return Stream<List<DisplayInfo>>.multi((controller) {
      controller.add(_current);
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
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
    await _controller.close();
  }
}
