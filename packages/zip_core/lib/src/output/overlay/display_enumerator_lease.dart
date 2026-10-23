import 'dart:async';
import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:zip_broadcast/src/output/overlay/display_enumerator.dart';

/// One controller's claim on the engine's single display enumerator.
///
/// Both window controllers in the main engine share **one** platform observer
/// (a second instance would open a second `screen_retriever` subscription that
/// nothing disposes), yet Unit 8's controller `dispose()` still calls
/// `_enumerator.dispose()` and its tests still assert `isDisposed` afterwards.
/// The lease satisfies both: every member delegates to the shared instance, and
/// [dispose] releases only this controller's share (NFR Design §3).
///
/// The shared instance is disposed by the last release, or by
/// [DisplayEnumeratorHost.dispose] (or whatever owns the shared instance),
/// whichever comes first. [dispose] is idempotent, so a double release is a
/// no-op.
class DisplayEnumeratorLease implements DisplayEnumerator {
  /// Creates a lease over [shared].
  ///
  /// [onRelease] runs exactly once, on this lease's first [dispose]. The host
  /// passes a callback that decrements its count and disposes the shared
  /// instance when the count reaches zero.
  DisplayEnumeratorLease(this._shared, {void Function()? onRelease})
      : _onRelease = onRelease;

  final DisplayEnumerator _shared;
  final void Function()? _onRelease;
  bool _released = false;

  /// Whether this lease has been released.
  bool get isReleased => _released;

  /// The shared instance this lease delegates to.
  DisplayEnumerator get shared => _shared;

  @override
  Future<List<DisplayInfo>> displays() => _shared.displays();

  @override
  Stream<List<DisplayInfo>> get changes => _shared.changes;

  @override
  Future<Size?> primarySize() => _shared.primarySize();

  /// Releases this share. Idempotent; never disposes [shared] itself.
  @override
  Future<void> dispose() async {
    if (_released) return;
    _released = true;
    _onRelease?.call();
  }
}

/// Reference-counts one shared [DisplayEnumerator] for a set of leases.
///
/// Owned by `OverlayWindowHost` (NFR Design §2). [leases] issues a lease and
/// increments the count; [dispose] disposes the shared instance regardless of
/// outstanding leases, and a later release then finds it already disposed and
/// does nothing (logged at `INFO` by the shared instance's own idempotence).
class DisplayEnumeratorHost {
  /// Creates the host over the one shared instance.
  DisplayEnumeratorHost(
    this._shared, {
    Logger? log,
  }) : _log = log ?? Logger('zip_core.DisplayEnumeratorHost');

  final DisplayEnumerator _shared;
  final Logger _log;
  int _outstanding = 0;
  bool _disposed = false;

  /// The shared instance.
  DisplayEnumerator get shared => _shared;

  /// Whether [dispose] has run.
  bool get isDisposed => _disposed;

  /// The number of leases not yet released.
  int get outstanding => _outstanding;

  /// Issues a lease.
  DisplayEnumeratorLease lease() {
    _outstanding++;
    return DisplayEnumeratorLease(_shared, onRelease: _release);
  }

  void _release() {
    if (_outstanding > 0) _outstanding--;
    if (_outstanding == 0) unawaited(_disposeShared('last release'));
  }

  /// Disposes the shared instance and drops every outstanding share.
  Future<void> dispose() async {
    _outstanding = 0;
    await _disposeShared('host dispose');
  }

  Future<void> _disposeShared(String why) async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _shared.dispose();
    } on Object catch (error) {
      _log.info('enumerator dispose failed ($why): ${error.runtimeType}');
    }
  }
}