# NFR Design — Unit 6: Zip Broadcast App

**Unit**: Unit 6: Zip Broadcast App (S-10)
**Stage**: NFR Design
**Status**: COMPLETE

---

## Test Architecture Overview

Unit 6 uses three test layers:

| Layer | Tool | Scope |
|-------|------|-------|
| Provider unit tests | `flutter_test` + `riverpod_test` (`ProviderContainer`) | `BroadcastRecordingNotifier`, `ObsConnectionNotifier`, `AudioInputConfigNotifier` |
| Widget tests | `flutter_test` + `WidgetTester` + GoRouter harness | All 4 screens; `ComingSoonCard`; `StatusPill`; `ZbRecordingControlsBar` |
| PBT | `glados` | Multi-engine partial failure; `AudioInputConfig` JSON round-trip |

No new packages are required. `glados` is already a `zip_core` dev dependency (established in Unit 1); `zip_broadcast` dev dependencies are `flutter_test`, `riverpod_test`, and `mocktail`.

---

## Mock Seams

### Seam 1: `MockSttEngine`

**Backs**: `BroadcastRecordingNotifier` unit tests (TEST-U6.2), multi-engine PBT (Section PBT-1).

`MockSttEngine` implements `SttEngine`. Each instance is independently configurable so
tests can mix succeeding and failing engines in a single notifier under test.

```dart
class MockSttEngine implements SttEngine {
  bool shouldFailInit = false;
  void Function(SttResult)? _onResult;

  int initCount    = 0;
  int startCount   = 0;
  int stopCount    = 0;
  int pauseCount   = 0;
  int resumeCount  = 0;

  @override
  Future<bool> initialize() async {
    initCount++;
    return !shouldFailInit;
  }

  @override
  Future<void> startListening({
    required String locale,
    required void Function(SttResult) onResult,
  }) async {
    startCount++;
    _onResult = onResult;
  }

  @override
  Future<void> stopListening() async => stopCount++;

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> resume() async => resumeCount++;

  /// Drive a fake recognition result from the test.
  void emit(SttResult result) => _onResult?.call(result);
}
```

**Usage**: Tests construct a `List<MockSttEngine>` and inject it into
`BroadcastRecordingNotifier` via a `ProviderContainer` override.

---

### Seam 2: `MockObsWebSocketTarget`

**Backs**: `ObsConnectionNotifier` unit tests (TEST-U6.3).

```dart
class MockObsWebSocketTarget implements ObsWebSocketTarget {
  bool shouldFailConnect   = false;
  bool shouldTimeoutTest   = false;
  Duration testDelay       = Duration.zero;

  int connectCount    = 0;
  int disconnectCount = 0;
  int testCount       = 0;

  final List<String> sentCaptions = [];

  @override
  Future<void> connect() async {
    connectCount++;
    if (shouldFailConnect) throw const ObsConnectionException('mock fail');
  }

  @override
  Future<void> disconnect() async => disconnectCount++;

  @override
  Future<ObsConnectionStatus> testConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    testCount++;
    if (shouldTimeoutTest) {
      await Future<void>.delayed(testDelay.isNegative ? timeout : testDelay);
      return ObsConnectionStatus.error;
    }
    return ObsConnectionStatus.connected;
  }

  @override
  Future<void> send(String captionText) async => sentCaptions.add(captionText);
}
```

**Usage**: `ObsConnectionNotifier` tests override `obsWebSocketTargetProvider` with a
`ProviderContainer` that supplies `MockObsWebSocketTarget`.

---

### Seam 3: `MockBrowserSourceTarget`

**Backs**: `ZbAppShell` orchestration widget tests (TEST-U6.1), verifying that toggling
`OutputTargetSettingsNotifier.browserSourceEnabled` starts and stops the server.

```dart
class MockBrowserSourceTarget implements BrowserSourceTarget {
  bool shouldThrowOnStart = false;
  int startCount = 0;
  int stopCount  = 0;

  @override
  Future<void> start() async {
    startCount++;
    if (shouldThrowOnStart) throw BrowserSourceStartException('mock failure');
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  bool get isRunning => startCount > stopCount;
}
```

---

### Seam 4: Fake SharedPreferences

**Backs**: `AudioInputConfigNotifier` unit tests (TEST-U6.4).

Flutter's `SharedPreferences` package ships a test helper. No custom class is needed:

```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({});
});
```

For tests that pre-seed persisted state:

```dart
SharedPreferences.setMockInitialValues({
  'zip_broadcast.audioInputConfigs': jsonEncode([
    {'deviceId': 'mic-1', 'speakerLabel': 'Speaker A', 'colorIndex': 0},
  ]),
});
```

The notifier's `build()` method calls `SharedPreferences.getInstance()`, which returns the
mock instance in test context without any additional wiring.

---

### Seam 5: `MockCaptionBus`

**Backs**: `BroadcastRecordingNotifier` unit tests verifying that `SttResult` events are
tagged with `sourceId` before publication (TEST-U6.2, row 7).

```dart
class MockCaptionBus implements CaptionBus {
  final List<CaptionEvent> published = [];

  @override
  void publish(CaptionEvent event) => published.add(event);

  @override
  void subscribe(CaptionOutputTarget target) {}

  @override
  void unsubscribe(CaptionOutputTarget target) {}
}
```

**Key assertion**:

```dart
final bus = MockCaptionBus();
// ... drive engine to emit SttResult ...
final events = bus.published.whereType<SttResultEvent>().toList();
expect(events.first.sourceId, equals('mic-1'));
```

---

## Test Patterns

### Pattern 1: `BroadcastRecordingNotifier` Provider Unit Tests (TEST-U6.2 / REL-U6.1)

#### Problem

`BroadcastRecordingNotifier` manages N concurrent `PlatformSttEngine` instances. Unit
tests must drive the full lifecycle (start, pause, resume, stop) with controllable engines
and verify partial-failure isolation without spawning real platform channels.

#### Pattern

Use a `ProviderContainer` with overrides for the engine factory, the `CaptionBus`, and
`AudioInputConfigNotifier`. Each test constructs a fixed list of `MockSttEngine` instances
and injects them via a provider override.

```dart
ProviderContainer buildContainer({
  required List<MockSttEngine> engines,
  MockCaptionBus? bus,
}) {
  final mockBus = bus ?? MockCaptionBus();
  return ProviderContainer(
    overrides: [
      captionBusProvider.overrideWithValue(mockBus),
      sttEngineFactoryProvider.overrideWith(
        (ref, sourceId) => engines[_indexFor(sourceId)],
      ),
      audioInputConfigNotifierProvider.overrideWith(
        () => _FakeAudioInputConfigNotifier(deviceIds: ['mic-0', 'mic-1']),
      ),
    ],
  );
}
```

#### Coverage Map (from NFR-R TEST-U6.2)

| # | Scenario | Setup | Assertion |
|---|----------|-------|-----------|
| 1 | All engines initialize → `isRecording` | All `shouldFailInit = false` | `state.isRecording == true` |
| 2 | One engine fails init → remaining continue | `engines[1].shouldFailInit = true` | `state.perEngineStates['mic-1'] == engineError`, `state.isRecording == true` |
| 3 | All engines fail → `IdleState` + error | All `shouldFailInit = true` | `state is IdleState`, `state.lastError != null` |
| 4 | Stop → all engines receive `stopListening()` | Start then stop | `engines.every((e) => e.stopCount == 1)` |
| 5 | Pause → all engines pause | Start then pause | `engines.every((e) => e.pauseCount == 1)` |
| 6 | Resume → all engines resume | Pause then resume | `engines.every((e) => e.resumeCount == 1)` |
| 7 | `SttResult` tagged with `sourceId` | Emit from `engines[0]` | `bus.published.first.sourceId == 'mic-0'` |

---

### Pattern 2: Multi-Engine Partial Failure PBT (PBT-1 / REL-U6.1)

#### Problem

Test coverage for `BroadcastRecordingNotifier.start()` partial failure cannot exhaustively
enumerate all combinations of N engines with mixed success/failure for arbitrary N. A
property-based test captures the invariant across all combinations.

#### Invariants

**P1** — If at least one engine initializes successfully, `BroadcastSessionState.isRecording` is `true` after `start()`.

**P2** — If all engines fail to initialize, the notifier returns to `IdleState` with a non-null `lastError`.

**P3** — `perEngineStates` has exactly one entry per configured audio input device, regardless of init outcome.

#### Implementation

```dart
void main() {
  final initOutcomesArb = Arbitrary.list(
    Arbitrary.bool,
    minLength: 1,
    maxLength: 4,
  );

  gladosTest(
    'P1+P2: partial failure isolation',
    initOutcomesArb,
    (List<bool> outcomes) async {
      final engines = outcomes
          .map((ok) => MockSttEngine()..shouldFailInit = !ok)
          .toList();
      final container = buildContainer(engines: engines);
      addTearDown(container.dispose);

      final notifier = container.read(
        broadcastRecordingNotifierProvider.notifier,
      );
      await notifier.start();

      final state = container.read(broadcastRecordingNotifierProvider);
      if (outcomes.any((ok) => ok)) {
        expect(state.isRecording, isTrue, reason: 'At least one engine succeeded');
      } else {
        expect(state, isA<IdleState>(), reason: 'All engines failed');
        expect((state as IdleState).lastError, isNotNull);
      }
    },
  );

  gladosTest(
    'P3: perEngineStates count matches configured inputs',
    initOutcomesArb,
    (List<bool> outcomes) async {
      final engines = outcomes
          .map((ok) => MockSttEngine()..shouldFailInit = !ok)
          .toList();
      final container = buildContainer(engines: engines);
      addTearDown(container.dispose);

      await container
          .read(broadcastRecordingNotifierProvider.notifier)
          .start();

      final state = container.read(broadcastRecordingNotifierProvider);
      if (state is BroadcastActiveState) {
        expect(state.perEngineStates.length, equals(outcomes.length));
      }
    },
  );
}
```

---

### Pattern 3: `AudioInputConfig` JSON Round-Trip PBT (PBT-2 / TEST-U6.4)

#### Problem

`AudioInputConfigNotifier` serializes `List<AudioInputConfig>` to JSON and reads it back
from `SharedPreferences`. The round-trip must be lossless across all valid field
combinations (deviceId, speakerLabel, colorIndex 0–3).

#### Generator

```dart
final audioInputConfigArb = Arbitrary.combine4(
  Arbitrary.string.where((s) => s.isNotEmpty),   // deviceId
  Arbitrary.string,                               // speakerLabel (may be empty)
  Arbitrary.integer(min: 0, max: 3),             // colorIndex
  Arbitrary.string.where((s) => s.isNotEmpty),   // name
  AudioInputConfig.new,
);

final configListArb = Arbitrary.list(
  audioInputConfigArb,
  minLength: 0,
  maxLength: 5,
);
```

#### Invariant

**P4** — For any valid `List<AudioInputConfig>`, serializing to JSON and deserializing
produces a list equal to the original.

```dart
gladosTest('P4: AudioInputConfig JSON round-trip', configListArb, (configs) {
  final json    = configs.map((c) => c.toJson()).toList();
  final decoded = json.map(AudioInputConfig.fromJson).toList();
  expect(decoded, equals(configs));
});
```

#### Persistence Boundary Test (non-PBT complement)

```dart
test('persists to SharedPreferences under correct key', () async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await container
      .read(audioInputConfigNotifierProvider.notifier)
      .addConfig(AudioInputConfig(deviceId: 'mic-1', ...));

  final prefs  = await SharedPreferences.getInstance();
  final stored = prefs.getString('zip_broadcast.audioInputConfigs');
  expect(stored, isNotNull);
  expect(jsonDecode(stored!), isA<List>());
});
```

---

### Pattern 4: `ObsConnectionNotifier` Unit Tests (TEST-U6.3)

#### Pattern

`ObsConnectionNotifier` is tested with `ProviderContainer`. `MockObsWebSocketTarget` is
injected via provider override. The 5-second timeout (NFR-DQ2=A) is verified using
`FakeAsync` so tests do not wait 5 real seconds.

```dart
test('testConnection() timeout returns error status', () {
  fakeAsync((fake) async {
    final mock = MockObsWebSocketTarget()
      ..shouldTimeoutTest = true
      ..testDelay = const Duration(seconds: 5);

    final container = ProviderContainer(
      overrides: [
        obsWebSocketTargetProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);

    final resultFuture = container
        .read(obsConnectionNotifierProvider.notifier)
        .testConnection();

    fake.elapse(const Duration(seconds: 6));
    final result = await resultFuture;
    expect(result, ObsConnectionStatus.error);
  });
});
```

#### Coverage Map (from NFR-R TEST-U6.3)

| # | Scenario | Mock setup | Assertion |
|---|----------|-----------|-----------|
| 1 | Enable OBS → `connect()` called | Default mock | `mock.connectCount == 1` |
| 2 | WebSocket disconnect event → status `disconnected` | Trigger disconnect stream event | `state == ObsConnectionStatus.disconnected` |
| 3 | `testConnection()` success | Default mock | Returns `ObsConnectionStatus.connected` |
| 4 | `testConnection()` timeout (5 s via FakeAsync) | `shouldTimeoutTest = true` | Returns `ObsConnectionStatus.error` |
| 5 | Disable OBS while connected → `disconnect()` called | Start connected, then disable | `mock.disconnectCount == 1` |

---

### Pattern 5: Widget Test Harness — Common Setup

#### Problem

All 4 screens use `GoRouter` with `ShellRoute`. Widget tests need a runnable
`MaterialApp.router` with injectable `ProviderScope` overrides and a controllable initial
route.

#### Harness

```dart
// test/helpers/zb_test_harness.dart

Widget buildZbApp({
  List<Override> overrides = const [],
  String initialLocation = '/',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ZbAppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/recording',
            builder: (_, __) => const RecordingScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/audio-inputs',
            builder: (_, __) => const AudioSourceConfigScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (_, __) => const Scaffold(
              body: Text('History'),
            ),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}
```

**Key points**:

- The router is constructed fresh per test to avoid route state bleed between tests.
- `/history` is a stub — its only role is to be a navigation destination so tests can
  assert route changes.
- `ZbAppShell` renders the full shell (nav rail or hamburger), so tests that check rail
  selection state can do so without additional scaffolding.

---

### Pattern 6: HomeScreen Widget Tests (TEST-U6.1)

#### Provider Overrides Required

| Provider | Idle (no inputs) | Idle (1+ inputs) |
|----------|-----------------|-----------------|
| `broadcastRecordingNotifierProvider` | `IdleState()` | `IdleState()` |
| `audioInputConfigNotifierProvider` | `[]` | `[AudioInputConfig(...)]` |
| `outputTargetSettingsNotifierProvider` | defaults | 2 targets enabled |

#### Coverage

```dart
testWidgets('Start button disabled when no audio inputs configured', (tester) async {
  await tester.pumpWidget(buildZbApp(
    overrides: [
      audioInputConfigNotifierProvider.overrideWith(() => _FakeEmpty()),
      broadcastRecordingNotifierProvider.overrideWith(() => _FakeIdle()),
    ],
  ));
  await tester.pumpAndSettle();

  final startButton = find.byKey(const Key('startBroadcastButton'));
  expect(tester.widget<ElevatedButton>(startButton).onPressed, isNull);
});

testWidgets('Start button enabled when 1+ inputs configured and idle', (tester) async {
  await tester.pumpWidget(buildZbApp(
    overrides: [
      audioInputConfigNotifierProvider.overrideWith(() => _FakeOneInput()),
      broadcastRecordingNotifierProvider.overrideWith(() => _FakeIdle()),
    ],
  ));
  await tester.pumpAndSettle();

  final startButton = find.byKey(const Key('startBroadcastButton'));
  expect(tester.widget<ElevatedButton>(startButton).onPressed, isNotNull);
});

testWidgets('Status pill reflects input count and active target count', (tester) async {
  // ... override with 2 inputs, 3 targets enabled ...
  // assert: find.text('Ready · 2 inputs · 3 targets active')
});

testWidgets('ComingSoonCard for Remote Viewers is non-interactive', (tester) async {
  // assert: no GestureDetector tap response, opacity < 1.0, 'Coming soon' badge visible
});
```

---

### Pattern 7: RecordingScreen Widget Tests (TEST-U6.1 / TEST-U6.5 / REL-U6.5)

#### Provider Overrides Required

| Provider | Recording active | Paused |
|----------|-----------------|--------|
| `broadcastRecordingNotifierProvider` | `RecordingActiveState` | `PausedState` |
| `obsConnectionNotifierProvider` | `connected` | `connected` |
| `audioLevelProvider` | `{'mic-0': 0.5, 'mic-1': 0.8}` | `{}` (hidden when paused) |
| `browserSourceUrlProvider` | `'http://localhost:9001/captions'` | same |

#### Coverage

```dart
testWidgets('Controls bar shows Pause and Stop when recording active', (tester) async {
  await tester.pumpWidget(buildZbApp(
    initialLocation: '/recording',
    overrides: [
      broadcastRecordingNotifierProvider.overrideWith(() => _FakeRecording()),
    ],
  ));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('pauseButton')), findsOneWidget);
  expect(find.byKey(const Key('stopButton')), findsOneWidget);
  expect(find.byKey(const Key('resumeButton')), findsNothing);
});

testWidgets('PopScope back gesture shows AlertDialog when recording', (tester) async {
  await tester.pumpWidget(buildZbApp(
    initialLocation: '/recording',
    overrides: [
      broadcastRecordingNotifierProvider.overrideWith(() => _FakeRecording()),
    ],
  ));
  await tester.pumpAndSettle();

  // Simulate Android back gesture
  final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
  await widgetsAppState.didPopRoute();
  await tester.pumpAndSettle();

  expect(find.byType(AlertDialog), findsOneWidget);
  expect(find.text('Stop captioning? Your session will end.'), findsOneWidget);
});

testWidgets('AlertDialog Cancel leaves route unchanged', (tester) async {
  // ... pump with recording state ...
  // trigger back, pumpAndSettle
  // tap Cancel
  // assert: still on /recording, AlertDialog gone
});

testWidgets('AlertDialog Stop calls stop() then navigates to /history', (tester) async {
  // ... pump with _FakeRecording that records stop() calls ...
  // trigger back → dialog → tap Stop
  // assert: stop() called, route == /history
});

testWidgets('StoppedState ref.listen navigates to /history', (tester) async {
  final stateController = StateController(
    const RecordingActiveState() as BroadcastNotifierState,
  );
  // override to emit StoppedState after pump
  // assert: navigates to /history, transcriptSessionListProvider invalidated
});

testWidgets('AudioLevelRow hidden when paused', (tester) async {
  await tester.pumpWidget(buildZbApp(
    initialLocation: '/recording',
    overrides: [
      broadcastRecordingNotifierProvider.overrideWith(() => _FakePaused()),
    ],
  ));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('audioLevelRow')), findsNothing);
});

testWidgets('StatusPill OBS has semantic label', (tester) async {
  // pump with obsConnectionNotifier = connected
  // assert SemanticsNode contains 'OBS: connected'
});
```

---

### Pattern 8: SettingsScreen Widget Tests (TEST-U6.1)

#### Coverage

```dart
testWidgets('All 6 category rows present', (tester) async {
  await tester.pumpWidget(buildZbApp(initialLocation: '/settings'));
  await tester.pumpAndSettle();

  for (final label in [
    'Speech Recognition', 'Appearance', 'OBS WebSocket',
    'Output Targets', 'Audio Inputs', 'Transcripts & Behaviour',
  ]) {
    expect(find.text(label), findsOneWidget);
  }
});

testWidgets('Tapping OBS category shows OBS detail view', (tester) async {
  // tap 'OBS WebSocket' row
  // assert: 'Test Connection' button visible, host/port/password fields visible
  // assert: back button visible, tapping returns to list view
});

testWidgets('OBS password field uses obscureText', (tester) async {
  // navigate to OBS detail
  // find TextField for password
  // assert: obscureText == true (SEC-U6.2 / FD Update)
});

testWidgets('Test Connection button triggers snackbar on success', (tester) async {
  // override obsConnectionNotifier with _FakeConnected
  // tap 'Test Connection'
  // assert: SnackBar with success message appears
});

testWidgets('Coming-soon row in Output Targets is announced as unavailable', (tester) async {
  // navigate to Output Targets detail
  // assert SemanticsNode for Remote Viewers row contains 'not yet available'
  // assert tapping row produces no action (ACC-U6.2)
});
```

---

### Pattern 9: AudioSourceConfigScreen Widget Tests (TEST-U6.1)

#### Coverage

```dart
testWidgets('Shows one card per AudioInputConfig', (tester) async {
  await tester.pumpWidget(buildZbApp(
    initialLocation: '/audio-inputs',
    overrides: [
      audioInputConfigNotifierProvider.overrideWith(() => _FakeTwoInputs()),
      audioDeviceServiceProvider.overrideWithValue(_FakeAudioDeviceService()),
    ],
  ));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('audioInputCard')), findsNWidgets(2));
});

testWidgets('Device already assigned to one card is disabled in other cards dropdown',
    (tester) async {
  // two cards, mic-1 assigned to card 0
  // open card 1's DropdownButton
  // assert: mic-1 item is disabled (DropdownMenuItem.enabled == false)
});

testWidgets('Add input button hidden when all devices assigned', (tester) async {
  // mock: 2 devices available, 2 configs already present
  // assert: dashed Add card not found
});

testWidgets('Remove config triggers animated exit', (tester) async {
  // tap remove on card 0
  // pumpAndSettle
  // assert: 1 card remaining
});

testWidgets('Color swatch selection calls setColor()', (tester) async {
  // override notifier with spy
  // tap swatch index 2
  // assert: setColor(deviceId, 2) called
});

testWidgets('Empty state shown when all inputs removed', (tester) async {
  // configure with 1 input, remove it
  // assert: empty-state widget visible
});
```

---

### Pattern 10: History Refresh After Session End (REL-U6.4)

This pattern mirrors Unit 5 Pattern 2 exactly, adapted for `BroadcastRecordingNotifier`.

```dart
ref.listen(broadcastRecordingNotifierProvider, (previous, next) {
  if (next is StoppedState && context.mounted) {
    ref.invalidate(transcriptSessionListProvider);  // REL-U6.4
    context.go('/history');
  }
});
```

**Key points** (same invariants as Unit 5 REL-U5.1):

- `ref.invalidate` is called before `context.go`. The order ensures `HistoryScreen`'s
  first `build` triggers a fresh async load.
- `transcriptSessionListProvider` invalidation covers all family instances (Riverpod
  invalidates the entire family from the root provider).
- No race condition risk: `StoppedState` is emitted only after all engine `stopListening()`
  calls complete and `TranscriptWriterTarget` has received `SessionStateEvent(stopped)`.

**Widget test verification** (included in Pattern 7 above):

Assert that `transcriptSessionListProvider` state is `AsyncLoading` immediately after
`StoppedState` is emitted and before `HistoryScreen` settles, confirming the invalidation
fired before navigation.

---

### Pattern 11: `ComingSoonCard` Semantic Verification (ACC-U6.2 / MAINT-U6.1)

`ComingSoonCard` is tested as a standalone widget, separate from the screens that embed it.
This validates both the accessibility requirement (ACC-U6.2) and the extraction requirement
(MAINT-U6.1) — if the card is not extracted, the test file has nowhere to import it from.

```dart
testWidgets('ComingSoonCard announces feature name + not yet available', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: ComingSoonCard(featureName: 'Remote Viewers'),
      ),
    ),
  );

  final semantics = tester.getSemantics(find.byType(ComingSoonCard));
  expect(semantics.label, contains('Remote Viewers'));
  expect(semantics.label, contains('not yet available'));
  expect(semantics.hasFlag(SemanticsFlag.isEnabled), isFalse);
});

testWidgets('ComingSoonCard tap produces no action', (tester) async {
  var tapped = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          onTap: () => tapped = true,  // should not fire
          child: const ComingSoonCard(featureName: 'Remote Viewers'),
        ),
      ),
    ),
  );

  await tester.tap(find.byType(ComingSoonCard), warnIfMissed: false);
  expect(tapped, isFalse);
});
```

---

## Logical Components — Unit 6

### New Files (zip_broadcast)

#### Models

| File | Contents |
|------|---------|
| `models/audio_input_config.dart` | `AudioInputConfig` (freezed; deviceId, name, speakerLabel, colorIndex) |
| `models/audio_input_visual_style.dart` | `AudioInputVisualStyle` (colorIndex → accent + label Color pair) |
| `models/obs_connection_status.dart` | `ObsConnectionStatus` enum (connecting, connected, disconnected, reconnecting, error) |
| `models/broadcast_session_state.dart` | `BroadcastSessionState` (freezed; sessionId, perEngineStates, isRecording, isPaused) |

#### Providers / Notifiers

| File | Contents |
|------|---------|
| `providers/broadcast_recording_notifier.dart` | `BroadcastRecordingNotifier` — multi-engine state machine |
| `providers/obs_connection_notifier.dart` | `ObsConnectionNotifier` — OBS WebSocket lifecycle |
| `providers/audio_level_provider.dart` | `AudioLevelProvider` — per-source RMS level map |
| `providers/audio_input_config_notifier.dart` | `AudioInputConfigNotifier` — config list with SharedPreferences persistence |
| `providers/browser_source_url_provider.dart` | `BrowserSourceUrlProvider` — derived URL + running status |

#### Routing / Shell

| File | Contents |
|------|---------|
| `routing/zb_router.dart` | `zbRouter` — `GoRouter` with `ShellRoute` |
| `shell/zb_app_shell.dart` | `ZbAppShell` — adaptive shell (rail ≥768px, hamburger <768px) |
| `shell/zb_nav_rail.dart` | `ZbNavRail` — 3 primary destinations + trailing icons |
| `shell/zb_nav_drawer.dart` | `ZbNavDrawer` — hamburger drawer |

#### Screens

| File | Contents |
|------|---------|
| `screens/home_screen.dart` | `HomeScreen` |
| `screens/recording_screen.dart` | `RecordingScreen` (`ConsumerStatefulWidget`) |
| `screens/settings_screen.dart` | `SettingsScreen` (`ConsumerStatefulWidget` with `_SettingsView` enum) |
| `screens/audio_source_config_screen.dart` | `AudioSourceConfigScreen` |

#### Widgets

| File | Contents |
|------|---------|
| `widgets/zb_recording_controls_bar.dart` | `ZbRecordingControlsBar` — state-driven Pause/Resume/Stop |
| `widgets/appearance_panel.dart` | `AppearancePanel` — chip-based selectors (mirrors zip_captions) |
| `widgets/status_pill.dart` | `StatusPill` — color dot + semantic label |
| `widgets/audio_level_row.dart` | `AudioLevelRow` — per-source level tracks; excluded from semantics |
| `widgets/coming_soon_card.dart` | `ComingSoonCard` — disabled card with "Coming soon" badge (MAINT-U6.1) |

#### Test Helpers

| File | Contents |
|------|---------|
| `test/helpers/zb_test_harness.dart` | `buildZbApp()` — GoRouter + ProviderScope harness |
| `test/helpers/mock_stt_engine.dart` | `MockSttEngine` |
| `test/helpers/mock_obs_websocket_target.dart` | `MockObsWebSocketTarget` |
| `test/helpers/mock_browser_source_target.dart` | `MockBrowserSourceTarget` |
| `test/helpers/mock_caption_bus.dart` | `MockCaptionBus` |
| `test/helpers/fake_notifiers.dart` | `_FakeIdle`, `_FakeRecording`, `_FakePaused`, `_FakeOneInput`, etc. |

### `app.dart` Changes (zip_broadcast)

`ZipBroadcastApp.build()` changes from `MaterialApp(home: HomeScreen())` to
`MaterialApp.router(routerConfig: zbRouter)`. Theme wiring (`AppTheme.light()` /
`AppTheme.dark()` driven by `displaySettingsNotifierProvider`) is unchanged.

### `pubspec.yaml` Changes (zip_broadcast)

```yaml
dev_dependencies:
  riverpod_test: ^2.0.0   # ProviderContainer test utilities
  mocktail: ^1.0.0        # lightweight mock support alongside MockSttEngine etc.
  # flutter_test: already present
  # glados: already present via zip_core (shared dev dep)
```
