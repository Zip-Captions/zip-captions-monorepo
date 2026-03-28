# Tech Stack Decisions — Unit 5: CI/CD Pipeline

## CI/CD Platform

**Decision**: GitHub Actions.

**Rationale**: Repository is hosted on GitHub. Native integration, no external service needed. Free tier sufficient for Phase 0.

---

## Runners

**Decision**:
- `ubuntu-latest` for analyze, test, and Android build jobs
- No macOS runner in Phase 0 (iOS builds verified locally in Unit 6)

**Rationale**: Ubuntu runners are fastest and cheapest. iOS CI builds deferred to reduce cost and complexity in Phase 0.

---

## Flutter SDK Management

**Decision**: `subosito/flutter-action` with pinned Flutter version (latest stable as of March 2026, determined at generation time).

**Rationale**: Most widely used Flutter setup action. Supports version pinning and caching.

---

## Dependency Scanning

**Decision**: `dart pub outdated` (informational, non-blocking).

**Rationale**: Lightweight check for stale dependencies. Full CVE scanning (`osv-scanner`) deferred to a later phase when the dependency tree is larger.

---

## Caching

**Decision**: Cache `pub-cache` directory across CI runs using `actions/cache`.

**Rationale**: Reduces `dart pub get` / `flutter pub get` time on subsequent runs. Standard practice for Dart/Flutter CI.

---

## Monorepo Orchestration

**Decision**: Melos for running `analyze` and `test` across all packages.

**Rationale**: Already configured in Unit 1. `melos run analyze` and `melos run test` execute across all packages in dependency order.

---

## Workflow Structure

| Workflow | Trigger | Runner | Jobs |
|---|---|---|---|
| `ci.yml` | PR (all branches), push to main/develop | `ubuntu-latest` | analyze, test, pub outdated |
| `build-verify.yml` | PR to main/develop | `ubuntu-latest` | Android APK debug build (zip_captions) |
