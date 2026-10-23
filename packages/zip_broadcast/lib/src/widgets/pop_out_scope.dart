import 'package:flutter/material.dart';

/// What [PopOutScope] hands its descendants: whether the pop-out is on, and
/// the one toggle action.
///
/// The screens are below the shell in the widget tree, not inside its state,
/// so the flag and the toggle travel down through an `InheritedWidget` rather
/// than a provider. A provider would put the shell's own in-memory state into
/// the container, which is exactly where Q10 B says it must not live.
@immutable
class PopOutState {
  /// Creates a [PopOutState].
  const PopOutState({
    required this.enabled,
    required this.onToggle,
    required this.available,
  });

  /// Whether the pop-out window is on.
  final bool enabled;

  /// The shell's toggle.
  final VoidCallback onToggle;

  /// Whether `popOutAvailability` currently enables the toggle.
  ///
  /// FD frontend-components §4: the in-surface toggle obeys the same rule as
  /// the chrome one, so the two can never disagree.
  final bool available;
}

/// Exposes the shell's pop-out state to the screens (UX-PIP-05, UX-PIP-02).
class PopOutScope extends InheritedWidget {
  /// Creates a [PopOutScope].
  const PopOutScope({
    required this.enabled,
    required this.onToggle,
    required this.available,
    required super.child,
    super.key,
  });

  /// Whether the pop-out is on.
  final bool enabled;

  /// The shell's toggle.
  final VoidCallback onToggle;

  /// Whether `popOutAvailability` currently enables the toggle.
  ///
  /// FD frontend-components §4: the in-surface toggle obeys the same rule as
  /// the chrome one, so the two can never disagree.
  final bool available;

  /// The nearest scope's value, or null above a shell (a bare screen test).
  static PopOutState? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PopOutScope>();
    if (scope == null) return null;
    return PopOutState(
      enabled: scope.enabled,
      onToggle: scope.onToggle,
      available: scope.available,
    );
  }

  @override
  bool updateShouldNotify(PopOutScope oldWidget) =>
      oldWidget.enabled != enabled ||
      oldWidget.onToggle != onToggle ||
      oldWidget.available != available;
}
