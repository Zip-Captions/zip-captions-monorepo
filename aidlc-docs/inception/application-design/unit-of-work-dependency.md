# Unit of Work Dependencies — Zip Captions v2, Phase 0

## Dependency Matrix

| Unit | Depends On | Blocks |
|---|---|---|
| Unit 1: Monorepo Scaffold | — (none) | Units 2, 3, 4 |
| Unit 2: zip_core Library | Unit 1 | Unit 3, Unit 5 |
| Unit 3: App Shells | Units 1, 2 | Units 5, 6 |
| Unit 4: Supabase Local Dev | Unit 1 | Unit 5 |
| Unit 5: CI/CD Pipeline | Units 1, 2, 3, 4 | — (none) |
| Unit 6: Spike 0.1 | Unit 3 | — (none) |

---

## Dependency Graph

```
Unit 1: Monorepo Scaffold
  |
  +--------+----------+--------+
  |        |          |        |
  v        v          v        |
Unit 2   Unit 3*   Unit 4     |
zip_core  App Shells  Supabase  |
  |        |  ^        |       |
  +--------+  |        |       |
  |           |        |       |
  v           | (Unit 2 merged first)
  +---------->+        |
              |        |
              v        v
           Unit 5: CI/CD Pipeline
              |
              v (independent)
           Unit 6: Spike 0.1**
```

*Unit 3 depends on both Unit 1 and Unit 2 being merged first.
**Unit 6 depends on Unit 3; can run in parallel with Unit 5.

---

## Sequencing and Parallelization

### Phase 1 (sequential — Unit 1 must be first)
- **Unit 1**: Monorepo Scaffold

### Phase 2 (parallel — after Unit 1 merges)
- **Unit 2**: zip_core Library  ← Track A
- **Unit 4**: Supabase Local Dev  ← Track B (independent of Track A)

### Phase 3 (sequential — after Unit 2 merges)
- **Unit 3**: App Shells (requires zip_core to be importable)

### Phase 4 (parallel — after Units 2, 3, 4 merge)
- **Unit 5**: CI/CD Pipeline  ← Track C
- **Unit 6**: Spike 0.1  ← Track D (independent of CI/CD)

### Build and Test (after all units merge)
- Final integration verification, build and test instructions

---

## Integration Checkpoints

| Checkpoint | After Units | Verification |
|---|---|---|
| Checkpoint 1 | Unit 1 | `melos bootstrap` succeeds; `dart analyze` passes on empty packages |
| Checkpoint 2 | Unit 2 | `melos run test` passes for `zip_core`; no `provider` dependency |
| Checkpoint 3 | Unit 3 | Both apps launch on at least one platform each |
| Checkpoint 4 | Unit 4 | `docker-compose up` starts Supabase stack; no secrets committed |
| Checkpoint 5 | Unit 5 | CI passes on a PR; branch protection active on `main` and `develop` |
| Final | All units | All Phase 0 exit criteria met |

---

## Rollback Strategy

Each unit is an isolated git worktree branch. If a unit fails:
1. Discard the worktree branch — no impact on `develop`
2. Root cause in isolation
3. Re-create the worktree from the latest `develop`

Units that depend on a failed unit simply wait — they cannot start until the blocking unit is merged.

---

## Coordination Notes

- Unit 2 is the critical path bottleneck — it must merge before Unit 3 can start
- Unit 4 (Supabase) is fully independent after Unit 1 and can proceed in parallel with Unit 2
- Unit 6 (Spike 0.1) is low-risk research; it should not block Unit 5
- All PRs target `develop`; `main` is updated only via a release merge
