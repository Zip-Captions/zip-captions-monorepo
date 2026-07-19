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

## Side Effects

Side effects (service calls, I/O, hardware) belong inside **notifier transition methods**, not in reactive listeners or `build()`.

```dart
// CORRECT — explicit call in the transition method
Future<void> start() async {
  await _wakeLockService.acquire();
  _captionBus.publish(SessionStateEvent(...));
  state = RecordingState.recording(...);
}

// WRONG — reactive side effect in a provider build
final sideEffectProvider = Provider<void>((ref) {
  final state = ref.watch(recordingStateNotifierProvider);
  if (state is RecordingActiveState) {
    ref.read(wakeLockServiceProvider).acquire(); // don't do this
  }
});
```

Services are obtained once via `ref.read(someServiceProvider)` in `build()` or the transition method itself. **No provider should watch another provider solely to trigger a side effect.**

**Why:** Side effects in reactive chains make execution order implicit and make testing harder. Explicit calls are traceable, testable, and consistent with Dart's imperative model.

## `onDispose` Safety

**Never call `ref.read` inside an `onDispose` callback.** The callback fires during a provider dispose cycle which may itself be triggered by another provider's rebuild — calling `ref.read` at that point violates Riverpod's invariant and throws an assertion.

Capture any values needed by the cleanup closure *before* registering it:

```dart
// WRONG — ref.read inside onDispose
ref.onDispose(() {
  ref.read(sessionStopCallbackProvider).callback = null; // assertion thrown
});

// CORRECT — capture before the closure
final stopCallback = ref.read(sessionStopCallbackProvider);
ref.onDispose(() {
  stopCallback.callback = null;
});
```

## Eager Watch for Resource-Managing Providers

When a `Provider` watches a settings notifier and conditionally registers/deregisters resources (e.g., `transcriptWriterTargetProvider`), it only rebuilds when it has an **active subscriber**. Without one, the rebuild is deferred until the next `ref.read`.

The widget shell must `ref.watch` such providers to drive immediate rebuilds when settings change:

```dart
// In ZcAppShell.build — keeps transcriptWriterTargetProvider subscribed
ref.watch(transcriptWriterTargetProvider);
```

In integration tests there is no widget layer, so simulate the eager watch by reading the provider explicitly after each settings change:

```dart
await transcriptNotifier.setCaptureEnabled(value: false);
container.read(transcriptWriterTargetProvider); // triggers rebuild + onDispose
```

## `ref.listen` in `Notifier.build()` for Settings-Driven Connection Management

When a `keepAlive` notifier must connect or disconnect an external resource in response to a boolean settings flag, use `ref.listen` with `fireImmediately: true` inside `build()`. This is the correct Riverpod pattern for stateful notifiers — it avoids the reactive-side-effect anti-pattern while still reacting to settings changes.

```dart
@override
ObsConnectionStatus build() {
  _target = ref.watch(obsWebSocketTargetProvider);

  ref.listen(
    outputTargetSettingsNotifierProvider.select((s) => s.obsEnabled),
    (_, enabled) {
      if (enabled) {
        _busSub = ref.read(captionBusProvider).stream.listen(_onCaptionEvent);
        unawaited(_target!.connect());
      } else {
        _busSub?.cancel();
        unawaited(_target!.disconnect());
      }
    },
    fireImmediately: true,
  );

  return ObsConnectionStatus.disconnected;
}
```

`fireImmediately: true` drives the initial connect/disconnect on first build without requiring a separate `read` call after construction.

**Why this is not a reactive side-effect anti-pattern:** `ref.listen` inside a `Notifier` is an explicit subscription to state changes, not a computed value chain. Execution order is deterministic — the listener fires once per change, in the order notifiers are read.

## Async Deferred Load with Future Fence

When `Notifier.build()` must return a synchronous default but load persisted state asynchronously, fire the async load immediately and store the `Future` as a private field. All mutating methods must await the fence before proceeding, ensuring no mutation races with the initial load.

```dart
Future<void>? _loadFuture;

@override
List<AudioInputConfig> build() {
  _loadFuture = _loadAsync(); // fires immediately, completes asynchronously
  return _defaultConfig;      // synchronous default while load is in-flight
}

Future<void> addConfig(AudioInputConfig config) async {
  await _loadFuture; // wait for load before mutating
  final updated = [...state, config];
  state = updated;
  await _persist(updated);
}
```

**Why:** `Notifier.build()` is synchronous; `SharedPreferences.getInstance()` is not. Returning a synchronous default keeps the widget tree rendering while the real data loads. The future fence prevents a mutation that fires immediately after construction (e.g., from a deep-link or widget test) from overwriting freshly loaded state.

## List State Mutation Safety

When a `Notifier` holds a `List` as its state and iterates or removes from it inside an async method, take a defensive snapshot with `List.of()` **before** any `await`. Iterating `state` directly while another async path modifies `state` throws `ConcurrentModificationError`.

```dart
// CORRECT — snapshot before iteration
Future<void> _stopEngines() async {
  final engines = List.of(_sessions); // snapshot
  for (final session in engines) {
    await session.engine.stop();
  }
}

// WRONG — iterating state while another path may modify it
Future<void> _stopEngines() async {
  for (final session in _sessions) { // ConcurrentModificationError risk
    await session.engine.stop();
  }
}
```

Apply this pattern in any method that loops over list state and contains an `await`, or that is called concurrently from `pause`, `resume`, `stop`, and `dispose` lifecycle methods.

## Widget Test — Button Finders

`FilledButton.icon` creates an internal `_FilledButtonWithIcon` subtype that does not match `find.byType(FilledButton)`. Use `find.bySubtype<ButtonStyleButton>()` instead:

```dart
// CORRECT
find.ancestor(
  of: find.text('Start'),
  matching: find.bySubtype<ButtonStyleButton>(),
)

// WRONG — misses FilledButton.icon variants
find.widgetWithText(FilledButton, 'Start')
```

## Code Generation

Run `dart run build_runner build --delete-conflicting-outputs` after modifying any `@riverpod`-annotated file. Generated files (`*.g.dart`) are committed to version control.
