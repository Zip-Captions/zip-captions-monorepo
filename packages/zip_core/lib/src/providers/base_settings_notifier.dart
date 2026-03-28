import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/app_settings.dart';
import 'package:zip_core/src/models/enums.dart';

part 'base_settings_notifier.g.dart';

/// Provider for a pre-initialized [SharedPreferences] instance.
///
/// Must be overridden in the app's `ProviderScope` with a pre-initialized
/// instance. In tests, use `SharedPreferences.setMockInitialValues()` before
/// creating the `ProviderContainer`.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(
    'sharedPreferences must be overridden with a '
    'pre-initialized instance',
  );
}

/// Abstract base for app-specific settings notifiers (BR-11).
///
/// Concrete subclasses in each app are annotated with `@riverpod`.
/// This abstract base provides the shared persistence implementation.
///
/// SharedPreferences key format: `{keyPrefix}.{fieldName}`
abstract class BaseSettingsNotifier extends Notifier<AppSettings> {
  /// App-specific key prefix for SharedPreferences.
  ///
  /// Example: `'zip_captions'` or `'zip_broadcast'`.
  String get keyPrefix;

  @override
  AppSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return _loadSettings(prefs);
  }

  AppSettings _loadSettings(SharedPreferences prefs) {
    final defaults = AppSettings.defaults();

    return AppSettings(
      scrollDirection: _loadEnum(
        prefs,
        'scrollDirection',
        ScrollDirection.values,
        defaults.scrollDirection,
      ),
      captionTextSize: _loadEnum(
        prefs,
        'captionTextSize',
        CaptionTextSize.values,
        defaults.captionTextSize,
      ),
      captionFont: _loadEnum(
        prefs,
        'captionFont',
        CaptionFont.values,
        defaults.captionFont,
      ),
      themeModeSetting: _loadEnum(
        prefs,
        'themeModeSetting',
        ThemeModeSetting.values,
        defaults.themeModeSetting,
      ),
      maxVisibleLines: _loadInt(
        prefs,
        'maxVisibleLines',
        defaults.maxVisibleLines,
      ),
    );
  }

  T _loadEnum<T extends Enum>(
    SharedPreferences prefs,
    String fieldName,
    List<T> values,
    T defaultValue,
  ) {
    final key = '$keyPrefix.$fieldName';
    try {
      final stored = prefs.getString(key);
      if (stored == null) return defaultValue;
      return values.firstWhere(
        (v) => v.name == stored,
        orElse: () {
          // SR-03: log field name and failure reason only
          log(
            'Failed to load $fieldName: unrecognized value',
            level: 500,
            name: 'BaseSettingsNotifier',
          );
          return defaultValue;
        },
      );
    // SharedPreferences can throw TypeError (extends Error, not Exception)
    // when stored value type doesn't match expected type.
    // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log(
        'Failed to load $fieldName: ${e.runtimeType}',
        level: 500,
        name: 'BaseSettingsNotifier',
      );
      return defaultValue;
    }
  }

  int _loadInt(
    SharedPreferences prefs,
    String fieldName,
    int defaultValue,
  ) {
    final key = '$keyPrefix.$fieldName';
    try {
      return prefs.getInt(key) ?? defaultValue;
    // SharedPreferences can throw TypeError (extends Error, not Exception)
    // when stored value type doesn't match expected type.
    // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log(
        'Failed to load $fieldName: ${e.runtimeType}',
        level: 500,
        name: 'BaseSettingsNotifier',
      );
      return defaultValue;
    }
  }

  /// Updates and persists the scroll direction.
  Future<void> setScrollDirection(
    ScrollDirection direction,
  ) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      '$keyPrefix.scrollDirection',
      direction.name,
    );
    state = state.copyWith(scrollDirection: direction);
  }

  /// Updates and persists the caption text size.
  Future<void> setCaptionTextSize(CaptionTextSize size) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      '$keyPrefix.captionTextSize',
      size.name,
    );
    state = state.copyWith(captionTextSize: size);
  }

  /// Updates and persists the selected caption font.
  Future<void> setCaptionFont(CaptionFont font) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      '$keyPrefix.captionFont',
      font.name,
    );
    state = state.copyWith(captionFont: font);
  }

  /// Updates and persists the theme mode setting.
  Future<void> setThemeModeSetting(
    ThemeModeSetting mode,
  ) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      '$keyPrefix.themeModeSetting',
      mode.name,
    );
    state = state.copyWith(themeModeSetting: mode);
  }

  /// Updates and persists the max visible lines.
  Future<void> setMaxVisibleLines(int lines) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('$keyPrefix.maxVisibleLines', lines);
    state = state.copyWith(maxVisibleLines: lines);
  }

  /// Resets all settings to defaults.
  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('$keyPrefix.'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    state = AppSettings.defaults();
  }
}
