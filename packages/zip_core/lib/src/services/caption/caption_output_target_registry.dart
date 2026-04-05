import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/caption_output_target.dart';

/// Manages registered output targets and fans out `CaptionBus` events
/// to each target with error isolation.
///
/// Uses lazy subscription (Q5=B): subscribes to the bus stream only when
/// the first target is added, unsubscribes when the last target is removed.
///
/// Uses fire-and-forget error isolation (Q2=A): a thrown exception in
/// one target does not affect other targets.
class CaptionOutputTargetRegistry {
  /// Creates a registry that fans out events from `bus`.
  CaptionOutputTargetRegistry(this._bus);

  static final _log =
      Logger('zip_core.CaptionOutputTargetRegistry');

  final CaptionBus _bus;
  final Set<CaptionOutputTarget> _targets = {};
  StreamSubscription<CaptionEvent>? _busSubscription;
  bool _disposed = false;

  /// Register and subscribe a target.
  ///
  /// If this is the first target, subscribes to the bus stream.
  /// Duplicate adds (same object instance) are no-ops.
  void add(CaptionOutputTarget target) {
    if (_disposed) return;
    if (_targets.add(target)) {
      _log.info('Target added: ${target.targetId}');
      _ensureSubscribed();
    }
  }

  /// Unsubscribe and remove a target, then dispose it.
  ///
  /// If the set is now empty, cancels the bus subscription.
  /// No-op if the target is not registered.
  void remove(CaptionOutputTarget target) {
    if (_targets.remove(target)) {
      _log.info('Target removed: ${target.targetId}');
      target.dispose();
      _ensureUnsubscribedIfEmpty();
    }
  }

  /// Currently registered targets (unmodifiable view).
  Set<CaptionOutputTarget> get activeTargets =>
      Set.unmodifiable(_targets);

  /// Unsubscribe from bus, dispose all targets, clear the set.
  void dispose() {
    _disposed = true;
    unawaited(_busSubscription?.cancel());
    _busSubscription = null;
    for (final target in _targets) {
      target.dispose();
    }
    _targets.clear();
  }

  void _ensureSubscribed() {
    _busSubscription ??= _bus.stream.listen(_onBusEvent);
  }

  void _ensureUnsubscribedIfEmpty() {
    if (_targets.isEmpty) {
      unawaited(_busSubscription?.cancel());
      _busSubscription = null;
    }
  }

  void _onBusEvent(CaptionEvent event) {
    for (final target in _targets) {
      try {
        target.onCaptionEvent(event);
      } on Object catch (e, st) {
        // SECURITY-03: Log targetId and error type only, never event content.
        _log.severe(
          'Target ${target.targetId} error: ${e.runtimeType}',
          e,
          st,
        );
      }
    }
  }
}
