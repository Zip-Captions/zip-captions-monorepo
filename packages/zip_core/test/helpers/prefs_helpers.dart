import 'package:zip_core/src/models/app_settings.dart';

/// Corruption state for a single settings field (LC-04).
enum FieldState { valid, missing, wrongType, unrecognizedEnum }

/// Builds a complete, valid SharedPreferences mock values map from
/// [settings] using [keyPrefix].
Map<String, Object> validPrefsMap(String keyPrefix, AppSettings settings) {
  return {
    '$keyPrefix.scrollDirection': settings.scrollDirection.name,
    '$keyPrefix.captionTextSize': settings.captionTextSize.name,
    '$keyPrefix.captionFont': settings.captionFont.name,
    '$keyPrefix.themeModeSetting': settings.themeModeSetting.name,
    '$keyPrefix.maxVisibleLines': settings.maxVisibleLines,
  };
}

/// Builds a SharedPreferences mock values map where each field is
/// independently valid, missing, wrong-typed, or unrecognized based on
/// [fieldStates].
///
/// [validSource] provides the values for fields in [FieldState.valid] state.
Map<String, Object> corruptPrefsMap(
  String keyPrefix,
  Map<String, FieldState> fieldStates,
  AppSettings validSource,
) {
  final map = <String, Object>{};

  for (final entry in fieldStates.entries) {
    final key = '$keyPrefix.${entry.key}';
    switch (entry.value) {
      case FieldState.valid:
        map[key] = _validValue(entry.key, validSource);
      case FieldState.missing:
        break; // Omit from map
      case FieldState.wrongType:
        map[key] = _wrongTypeValue(entry.key);
      case FieldState.unrecognizedEnum:
        map[key] = _unrecognizedValue(entry.key);
    }
  }

  return map;
}

Object _validValue(String fieldName, AppSettings settings) {
  return switch (fieldName) {
    'scrollDirection' => settings.scrollDirection.name,
    'captionTextSize' => settings.captionTextSize.name,
    'captionFont' => settings.captionFont.name,
    'themeModeSetting' => settings.themeModeSetting.name,
    'maxVisibleLines' => settings.maxVisibleLines,
    _ => throw ArgumentError('Unknown field: $fieldName'),
  };
}

Object _wrongTypeValue(String fieldName) {
  // For enum fields (stored as String), return an int.
  // For int fields, return a String.
  return switch (fieldName) {
    'scrollDirection' => 42,
    'captionTextSize' => 42,
    'captionFont' => 42,
    'themeModeSetting' => 42,
    'maxVisibleLines' => 'not_an_int',
    _ => throw ArgumentError('Unknown field: $fieldName'),
  };
}

Object _unrecognizedValue(String fieldName) {
  return switch (fieldName) {
    'scrollDirection' => 'diagonal',
    'captionTextSize' => 'xxxl',
    'captionFont' => 'papyrus',
    'themeModeSetting' => 'neon',
    'maxVisibleLines' => 'not_a_number',
    _ => throw ArgumentError('Unknown field: $fieldName'),
  };
}

/// All AppSettings field names for iteration in tests.
const appSettingsFieldNames = [
  'scrollDirection',
  'captionTextSize',
  'captionFont',
  'themeModeSetting',
  'maxVisibleLines',
];
