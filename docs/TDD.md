# Test-Driven Development Process

> For the broader development workflow (branching, task tracking, code review), see `CONTRIBUTING.md`.

**Last Updated:** 2026-03-26

---

## 1. Core Principle

**No code ships without tests. No tests are written without a user story.**

```
User Story --> Acceptance Criteria --> Tests --> Implementation --> Tests Pass --> PR
```

---

## 2. The Cycle

### Step 1: Define the Story

Write a user story using `docs/STORY_TEMPLATE.md`. The story must include acceptance criteria (AC-1, AC-2, etc.) and a test coverage mapping that links each AC to a specific test file.

### Step 2: Write Failing Tests

Write tests that cover every acceptance criterion. Run them. Confirm they fail. Commit:

```
test(zip_core): add failing tests for P0-US-001
```

### Step 3: Implement

Write the minimum code to make all tests pass. Do not add features beyond the acceptance criteria. Do not optimize prematurely.

### Step 4: Refactor

With passing tests as a safety net, refactor for clarity and consistency. Run tests after every change.

### Step 5: PR

Open a PR with: story reference, test files, implementation, updated story status.

---

## 3. Agent Instructions

### Building a Feature

1. Confirm a user story exists and is Ready (check via `./scripts/list-available.sh`)
2. Claim the story (`./scripts/claim-story.sh <story-id>`)
3. Write tests first, referencing acceptance criteria in test descriptions
4. Implement the feature
5. Run tests: `melos run test`
6. Run analysis: `melos run analyze`
7. If any file uses `freezed`, `riverpod_generator`, or `json_serializable`, run code generation first: `melos run generate`
8. Update status (`./scripts/update-status.sh <story-id> "Tests Written"`, then "In Review" when PR opens)
9. Reference the story ID in commits and PR description

### Fixing a Bug

1. Write a test that reproduces the bug (should fail)
2. Fix the bug
3. Confirm the new test passes and no existing tests regress

### Test Quality Rules

- **Independent.** No test depends on another test's side effects.
- **Deterministic.** No randomness, no timing, no network calls in unit tests.
- **Readable.** Format: `test('AC-N: [what it tests]')` -- e.g., `test('AC-3: rejects engine start without microphone permission')`
- **Focused.** Each test file starts with a comment referencing the story: `// Tests for P0-US-003: STT Engine Interface`
- **Mock external dependencies** in unit tests using `mocktail`. Only integration tests touch real infrastructure.

---

## 4. Test Types

### Unit Tests

All providers, models, and business logic. Mock dependencies.

```dart
// Tests for P0-US-003: STT Engine Interface
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSttEngine extends Mock implements SttEngine {}

void main() {
  group('SttEngineRegistry', () {
    test('AC-1: registers and retrieves engine by ID', () {
      // Arrange, Act, Assert
    });

    test('AC-2: returns empty list when no engines registered', () {
      // ...
    });

    test('AC-3: throws when retrieving unregistered engine ID', () {
      // ...
    });
  });
}
```

### Widget Tests

All custom widgets in `zip_captions` and `zip_broadcast`. Use a `pumpApp` helper that wraps with `ProviderScope` and required overrides.

```dart
// test/helpers/pump_app.dart
Future<void> pumpApp(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: widget),
    ),
  );
}
```

### Integration Tests

Critical flows (start captioning, save transcript, join broadcast). Run per-phase, not per-PR.

### Contract Tests

Cross-package agreements. Use shared fixtures in `test-fixtures/`.

---

## 5. Story Organization

```
stories/
  phase-0/
    P0-US-001-monorepo-scaffold.md
    P0-US-002-riverpod-setup.md
  phase-1/
    P1-US-001-stt-engine-interface.md
```

Story IDs are unique within their phase. The phase prefix prevents collisions across phases.

---

## 6. Acceptance Criteria Guidelines

Good criteria are **testable, specific, outcome-focused, and edge-case aware.**

Bad:
```
- [ ] Captioning works
```

Good:
```
- [ ] AC-1: SttEngine.startListening() emits SttResult objects with text and isFinal fields
- [ ] AC-2: SttEngine.startListening() with unsupported locale throws SttLocaleNotSupported
- [ ] AC-3: SttEngine.stopListening() stops the stream and completes the Future
- [ ] AC-4: SttEngineRegistry.getById() with unregistered ID throws SttEngineNotFound
```

---

## 7. Running Tests

```bash
# All packages
melos run test

# Single package
melos run test --scope zip_core

# Single test file
cd packages/zip_core
dart test test/src/stt/stt_engine_registry_test.dart

# With coverage
melos run coverage

# Watch mode (single package, during development)
cd packages/zip_core
dart test --reporter expanded
```

---

## 8. Coverage

Target: 80%+ per package. CI reports coverage but does not block PRs below threshold during Phase 0 (scaffolding phase). From Phase 1 onward, coverage below 80% blocks the PR.

Excluded from coverage:
- Generated code (`*.g.dart`, `*.freezed.dart`)
- Platform channel native code (tested via integration tests)
- Trivial getters/constructors with no logic

---

## 9. When to Skip TDD

- **Exploratory prototypes / research spikes:** No tests needed, but code must gain tests before merging to develop
- **Pure UI layout:** No unit tests for visual-only changes (functional UI behavior still needs widget tests)
- **Config file changes:** Validated by the build (`melos bootstrap`, `flutter analyze`)
- **Documentation changes:** No tests needed

When in doubt, write the tests.

---

*This is the authoritative TDD process for this project.*
