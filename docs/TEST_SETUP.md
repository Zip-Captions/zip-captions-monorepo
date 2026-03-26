# Test Infrastructure Setup

> How to set up, write, and run tests for each package.

**Last Updated:** 2026-03-26

---

## 1. Overview

| Package | Framework | Test Location | Run Command |
|---|---|---|---|
| `zip_core` | `dart test` + `mocktail` | `packages/zip_core/test/` | `melos run test --scope zip_core` |
| `zip_captions` | `flutter test` + `mocktail` | `packages/zip_captions/test/` | `melos run test --scope zip_captions` |
| `zip_broadcast` | `flutter test` + `mocktail` | `packages/zip_broadcast/test/` | `melos run test --scope zip_broadcast` |
| `zip_supabase` | Deno test (Edge Functions) | `packages/zip_supabase/functions/*/test/` | `cd packages/zip_supabase && deno test` |

---

## 2. Dart / Flutter Tests

### Setup

Dependencies are managed via Melos. After cloning:

```bash
melos bootstrap       # Installs all dependencies, links local packages
melos run generate    # Runs build_runner for freezed, riverpod_generator, json_serializable
```

### Running Tests

```bash
# All packages
melos run test

# Single package
melos run test --scope zip_core

# Single test file
cd packages/zip_core
dart test test/src/stt/stt_engine_registry_test.dart -r expanded

# With coverage
melos run coverage
# Coverage reports output to coverage/ in each package
```

### Writing Tests

Reference the story in every test file:

```dart
// Tests for P0-US-003: STT Engine Interface
```

Reference acceptance criteria in test names:

```dart
test('AC-1: registers and retrieves engine by ID', () {
  // Arrange
  final registry = SttEngineRegistry();
  final engine = MockSttEngine();
  when(() => engine.engineId).thenReturn('mock-engine');

  // Act
  registry.register(engine);
  final result = registry.getById('mock-engine');

  // Assert
  expect(result, equals(engine));
});
```

### Mocking with mocktail

Create mocks in `test/helpers/mocks.dart` within each package:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/zip_core.dart';

class MockSttEngine extends Mock implements SttEngine {}
class MockCaptionBus extends Mock implements CaptionBus {}
```

### Widget Testing (zip_captions, zip_broadcast)

Use a shared `pumpApp` helper in `test/helpers/pump_app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: widget,
        ),
      ),
    );
  }
}
```

### Riverpod Provider Testing

Test providers without a widget tree using `ProviderContainer`:

```dart
test('AC-1: settings provider loads defaults on first access', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  final settings = await container.read(settingsProvider.future);
  expect(settings.textSize, equals(defaultTextSize));
});
```

---

## 3. Supabase Edge Function Tests

### Setup

Edge Functions use Deno. Install Deno and the Supabase CLI:

```bash
# Install Deno: https://deno.land/manual/getting_started/installation
# Install Supabase CLI: https://supabase.com/docs/guides/cli
```

### Running Tests

```bash
cd packages/zip_supabase
deno test functions/
```

### Writing Tests

```typescript
// functions/patreon-webhook/test/handler_test.ts
import { assertEquals } from "https://deno.land/std/testing/asserts.ts";

Deno.test("AC-1: valid pledge event grants entitlement", async () => {
  // Arrange, Act, Assert
});

Deno.test("AC-2: invalid signature returns 401", async () => {
  // ...
});
```

### Local Supabase for Integration Tests

```bash
cd packages/zip_supabase
docker compose up -d       # Start local Supabase
supabase db reset           # Apply migrations + seed
supabase functions serve    # Serve Edge Functions locally
```

---

## 4. Shared Test Fixtures

For cross-package contracts, use shared fixture files in `test-fixtures/` at the repo root:

```
test-fixtures/
  stt/
    stt_result_final.json         # Example SttResult with isFinal=true
    stt_result_partial.json       # Example SttResult with isFinal=false
  caption_bus/
    caption_event.json            # Caption bus event payload
  transport/
    webrtc_offer.json             # SDP offer format
    realtime_caption_payload.json # Encrypted caption payload for Realtime
```

Both the producing package and consuming package load the same fixture in their tests. If either side changes the format, the other's tests break immediately.

---

## 5. Code Generation

After modifying any file that uses `freezed`, `riverpod_generator`, or `json_serializable`:

```bash
melos run generate
# Or for a single package:
cd packages/zip_core
dart run build_runner build --delete-conflicting-outputs
```

Commit generated files (`*.g.dart`, `*.freezed.dart`) alongside source changes.

---

## 6. CI Integration

CI runs on every PR:

1. `melos bootstrap`
2. `melos run generate` (verify no uncommitted generated code)
3. `melos run analyze` (zero warnings)
4. `melos run test` (all packages)
5. Coverage report (informational during Phase 0, blocking from Phase 1)

---

## 7. Quick Reference

| What | Command |
|---|---|
| Install dependencies | `melos bootstrap` |
| Run code generation | `melos run generate` |
| All tests | `melos run test` |
| Single package tests | `melos run test --scope zip_core` |
| Single test file | `cd packages/zip_core && dart test test/path/to/test.dart` |
| Coverage | `melos run coverage` |
| Static analysis | `melos run analyze` |
| Format check | `melos run format` |
| Supabase Edge Function tests | `cd packages/zip_supabase && deno test` |
| Start local Supabase | `cd packages/zip_supabase && docker compose up -d` |

---

*Customize this document as new test infrastructure is added.*
