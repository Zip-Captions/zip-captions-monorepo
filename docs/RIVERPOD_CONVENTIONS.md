# Riverpod Conventions (FR-02.4)

Conventions established by Unit 2 (`zip_core`) for all Riverpod usage in the Zip Captions v2 monorepo.

## Provider Declaration

Use `@riverpod` / `@Riverpod(keepAlive: true)` annotations with `riverpod_generator`. Do not write hand-written providers in production code.

```dart
// Stateless provider (auto-dispose)
@riverpod
List<SpeechLocale> localeInfo(Ref ref) => const [];

// Stateful, persistent provider
@Riverpod(keepAlive: true)
class RecordingStateNotifier extends _$RecordingStateNotifier {
  @override
  RecordingState build() => const RecordingState.idle();
}
```

### When to use `keepAlive: true`

- State that must survive navigation (recording state, settings, locale)
- Providers that hold expensive resources or long-lived connections
- The `sharedPreferencesProvider` override pattern

### When to use auto-dispose (default)

- Derived/computed values that can be cheaply recomputed
- Providers scoped to a single screen or widget lifecycle

## SharedPreferences Pattern

`sharedPreferencesProvider` is declared with `@Riverpod(keepAlive: true)` and throws `UnimplementedError` by default. It **must** be overridden at the app level with a pre-initialized instance:

```dart
// In app startup (e.g., main.dart)
final prefs = await SharedPreferences.getInstance();
runApp(
  ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ),
);
```

This ensures synchronous access in `Notifier.build()` methods.

## BaseSettingsNotifier Pattern

App-specific settings use a concrete subclass of `BaseSettingsNotifier` with a unique `keyPrefix`:

```dart
@riverpod
class CaptionsSettingsNotifier extends BaseSettingsNotifier {
  @override
  String get keyPrefix => 'zip_captions';
}
```

The base class handles all persistence, per-field corruption recovery, and provides setter methods for each `AppSettings` field.

## Testing with ProviderContainer

Unit tests use `ProviderContainer` directly (no widget tree needed):

```dart
final container = ProviderContainer(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ],
);
addTearDown(container.dispose);

final settings = container.read(settingsProvider);
final notifier = container.read(settingsProvider.notifier);
```

## Ref Parameter Convention

Use `Ref` (not the generated `*Ref` typedef) as the parameter type for functional providers, since generated typedefs are deprecated in riverpod_generator 2.x:

```dart
@riverpod
List<SpeechLocale> localeInfo(Ref ref) => const [];
```

## Code Generation

Run `dart run build_runner build --delete-conflicting-outputs` after modifying any `@riverpod`-annotated file. Generated files (`*.g.dart`) are committed to version control.
