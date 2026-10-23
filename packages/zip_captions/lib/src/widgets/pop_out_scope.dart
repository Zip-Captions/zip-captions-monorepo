import 'package:flutter/material.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';

/// What [PopOutScope] hands its descendants: whether the pop-out is on, and
/// the one toggle action.
///
/// The screens are below the shell in the widget tree, not inside its state,
/// so the flag and the toggle travel down through an `InheritedWidget` rather
/// than a provider. A provider would put the shell's own in-memory state into
/// the container, which is where Q10 B says it must not live.
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

/// Exposes the shell's pop-out state to the screens (UX-PIP-05, UX-PIP-02),
/// and the app's copy to the pop-out widgets (this app reads its ARB through
/// [ZcStrings], with no generated localizations).
class PopOutScope extends InheritedWidget {
  /// Creates a [PopOutScope].
  const PopOutScope({
    required this.enabled,
    required this.onToggle,
    required this.available,
    required this.strings,
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

  /// The loaded copy. The shell only builds its chrome once the ARB has
  /// loaded, so a screen can read it non-nullably.
  final ZcStrings strings;

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
      oldWidget.available != available ||
      oldWidget.strings != strings;
}

/// Reads the app's copy from the nearest [PopOutScope].
///
/// Mirrors `ZipBroadcastLocalizations.of`: the pop-out widgets are written
/// once and read the same way in both apps.
class ZcStringsScope {
  const ZcStringsScope._();

  /// The nearest scope's copy.
  static ZcStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PopOutScope>();
    if (scope == null) {
      throw FlutterError(
        'No PopOutScope above this widget. The pop-out controls are rendered '
        'inside ZcAppShell, which provides the app copy.',
      );
    }
    return scope.strings;
  }
}
