# NFR Design Patterns — Unit 1: Core Abstractions

## 1. Property-Based Testing Pattern (glados)

### Test Organization

PBT tests live alongside example-based tests in `packages/zip_core/test/pbt/`. Each PBT test file focuses on one component's properties.

| Test File | Component | Properties Tested |
|-----------|-----------|-------------------|
| `pbt/stt_result_properties_test.dart` | SttResult | Confidence range invariant, sourceId non-empty, isFinal text constraint |
| `pbt/recording_state_machine_test.dart` | RecordingState | Session ID consistency, idempotent transitions, valid state after any sequence |
| `pbt/caption_bus_properties_test.dart` | CaptionBus + Registry | All-targets-receive invariant, error isolation invariant |
| `pbt/display_settings_roundtrip_test.dart` | DisplaySettings | Save/load round-trip, defaults invariant, reset idempotence |
| `pbt/stt_engine_registry_test.dart` | SttEngineRegistry | Register/get round-trip, defaultEngine invariant |

### Custom Arbitrary Generators

All generators in `test/helpers/generators.dart` (Q1=A). Each generator produces valid domain instances with randomized fields.

```dart
// Generator patterns for Unit 1 domain types

/// Generates valid SttResult instances with random fields.
/// - text: random non-empty string for final results, any string for interim
/// - isFinal: random bool
/// - confidence: random double in [0.0, 1.0]
/// - sourceId: random non-empty string
class ArbitrarySttResult extends Arbitrary<SttResult> { ... }

/// Generates random sequences of state machine transitions.
/// Each transition is one of: start, pause, resume, stop, clearSession.
/// Used to verify state machine integrity under any input sequence.
class ArbitraryTransitionSequence extends Arbitrary<List<StateTransition>> { ... }

/// Generates valid DisplaySettings with random enum values and int fields.
class ArbitraryDisplaySettings extends Arbitrary<DisplaySettings> { ... }

/// Generates random sequences of registry operations (register, unregister, get).
class ArbitraryRegistryOps extends Arbitrary<List<RegistryOp>> { ... }
```

### StateTransition Enum (Test Helper)

```dart
enum StateTransition { start, pause, resume, stop, clearSession }
```

Used by `ArbitraryTransitionSequence` to generate random sequences. The PBT test applies each transition to a `RecordingStateNotifier` and asserts invariants after every step.

### PBT Test Pattern

```dart
// Example: RecordingState session ID consistency
Glados(arbitraryTransitionSequence).test(
  'sessionId is consistent within a session',
  (transitions) {
    final notifier = createTestNotifier();
    String? currentSessionId;

    for (final t in transitions) {
      applyTransition(notifier, t);
      final state = notifier.state;

      if (state is ActiveSessionState) {
        if (currentSessionId == null) {
          currentSessionId = state.sessionId;
        } else {
          expect(state.sessionId, equals(currentSessionId));
        }
      } else if (state is IdleState) {
        currentSessionId = null; // session ended
      }
    }
  },
);
```

---

## 2. MockSttEngine Pattern

### Design

`MockSttEngine` implements the full `SttEngine` interface with configurable behavior and a brief default async delay (~100ms, Q2=C).

```dart
class MockSttEngine implements SttEngine {
  MockSttEngine({
    this.engineId = 'mock',
    this.displayName = 'Mock Engine',
    this.requiresNetwork = false,
    this.requiresDownload = false,
    this.mockLocales = const [],
    this.mockIsAvailable = true,
    this.asyncDelay = const Duration(milliseconds: 100),
  });

  // --- Configurable properties ---
  @override
  final String engineId;
  @override
  final String displayName;
  @override
  final bool requiresNetwork;
  @override
  final bool requiresDownload;

  final List<SpeechLocale> mockLocales;
  final bool mockIsAvailable;
  final Duration asyncDelay;

  // --- Internal state ---
  bool _initialized = false;
  bool _listening = false;
  void Function(SttResult)? _onResult;
  String? _activeLocaleId;

  // --- Test inspection ---
  bool get isInitialized => _initialized;
  bool get isListening => _listening;
  String? get activeLocaleId => _activeLocaleId;

  // --- Interface implementation ---
  @override
  Future<bool> initialize() async {
    await Future.delayed(asyncDelay);
    _initialized = true;
    return true;
  }

  @override
  Future<bool> isAvailable() async {
    await Future.delayed(asyncDelay);
    return mockIsAvailable;
  }

  @override
  Future<List<SpeechLocale>> supportedLocales() async {
    await Future.delayed(asyncDelay);
    return mockLocales;
  }

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult) onResult,
  }) async {
    await Future.delayed(asyncDelay);
    _activeLocaleId = localeId;
    _onResult = onResult;
    _listening = true;
    return true;
  }

  @override
  Future<void> stopListening() async {
    await Future.delayed(asyncDelay);
    _listening = false;
    _onResult = null;
  }

  @override
  Future<bool> pause() async {
    await Future.delayed(asyncDelay);
    _listening = false;
    return true;
  }

  @override
  Future<bool> resume() async {
    await Future.delayed(asyncDelay);
    _listening = true;
    return true;
  }

  @override
  void dispose() {
    _listening = false;
    _onResult = null;
  }

  // --- Test trigger ---
  /// Simulates an STT result arriving from the engine.
  /// Calls the onResult callback registered via startListening.
  void emitResult(SttResult result) {
    _onResult?.call(result);
  }
}
```

### Key Design Decisions

- **Default async delay of 100ms** (Q2=C): All Future-returning methods delay by 100ms by default, making tests exercise real async behavior without being slow. Tests that need synchronous behavior can pass `asyncDelay: Duration.zero`.
- **`emitResult()` trigger**: Synchronous — the test controls exactly when results arrive. The async delay applies to lifecycle methods (initialize, startListening, etc.), not to result delivery.
- **State inspection**: `isInitialized`, `isListening`, `activeLocaleId` allow tests to assert engine state without relying on side effects.
- **Location**: `packages/zip_core/test/helpers/mock_stt_engine.dart` — reusable by downstream units.

---

## 3. Logging Pattern

### Logger Per Component

Each service class creates a named `Logger` instance using the `logging` package:

```dart
import 'package:logging/logging.dart';

class CaptionOutputTargetRegistry {
  static final _log = Logger('zip_core.CaptionOutputTargetRegistry');

  void _onBusEvent(CaptionEvent event) {
    for (final target in _targets) {
      try {
        target.onCaptionEvent(event);
      } catch (e, st) {
        _log.severe(
          'Target ${target.targetId} error: ${e.runtimeType}',
          e,
          st,
        );
      }
    }
  }
}
```

### Naming Convention

`zip_core.{ClassName}` — e.g.:
- `zip_core.CaptionOutputTargetRegistry`
- `zip_core.CaptionBus`
- `zip_core.BaseSettingsNotifier`
- `zip_core.RecordingStateNotifier`

### Log Levels

| Level | Usage |
|-------|-------|
| `fine` | State transitions (recording started, paused, etc.) |
| `info` | Engine registered, target added/removed |
| `warning` | Corrupted settings value, fallback to default |
| `severe` | Target error in onCaptionEvent, engine initialization failure |

### Security Constraint

**SECURITY-03**: No logger may output `SttResult.text` or `RecordingState.currentSegment`. Log messages reference IDs (sessionId, engineId, targetId) and error types only.

### Migration from dart:developer

Files modified in Unit 1 replace `import 'dart:developer'` with `import 'package:logging/logging.dart'` and change `log(message, level: N, name: 'X')` to `Logger('zip_core.X').log(Level, message)`.

---

## 4. CaptionBus Throughput Test Pattern

Verify PERF-U1.1 (20 events/sec) with a simple timing test:

```dart
test('bus sustains 20 events/sec', () async {
  final bus = CaptionBus();
  final registry = CaptionOutputTargetRegistry(bus);
  final target = CollectingTarget(); // test target that collects events
  registry.add(target);

  final events = List.generate(20, (i) => SttResultEvent(
    SttResult(
      text: 'word $i',
      isFinal: false,
      confidence: 1.0,
      timestamp: DateTime.now(),
      sourceId: 'test',
    ),
  ));

  final sw = Stopwatch()..start();
  for (final event in events) {
    bus.publish(event);
  }
  sw.stop();

  expect(target.received.length, equals(20));
  expect(sw.elapsedMilliseconds, lessThan(1000));

  registry.dispose();
  bus.dispose();
});
```

This is a sanity check, not a microbenchmark. The broadcast StreamController is in-process and will trivially exceed 20/sec — the test confirms no accidental blocking is introduced.

---

## 5. Error Isolation Test Pattern

Verify REL-U1.1 with a throwing target alongside a healthy target:

```dart
test('error in one target does not affect others', () {
  final bus = CaptionBus();
  final registry = CaptionOutputTargetRegistry(bus);

  final healthyTarget = CollectingTarget();
  final throwingTarget = ThrowingTarget(); // throws on every onCaptionEvent

  registry.add(healthyTarget);
  registry.add(throwingTarget);

  final event = SttResultEvent(SttResult(...));
  bus.publish(event);

  // Healthy target still received the event
  expect(healthyTarget.received.length, equals(1));
  // No unhandled exception propagated
  // ThrowingTarget is still registered (not removed)
  expect(registry.activeTargets.length, equals(2));

  registry.dispose();
  bus.dispose();
});
```

### Test Helper Targets

```dart
/// Collects all received events for assertion.
class CollectingTarget implements CaptionOutputTarget {
  final received = <CaptionEvent>[];
  @override String get targetId => 'collecting';
  @override void onCaptionEvent(CaptionEvent event) => received.add(event);
  @override void dispose() {}
}

/// Throws on every event.
class ThrowingTarget implements CaptionOutputTarget {
  @override String get targetId => 'throwing';
  @override void onCaptionEvent(CaptionEvent event) => throw Exception('fail');
  @override void dispose() {}
}
```

**Location**: `packages/zip_core/test/helpers/test_targets.dart`
