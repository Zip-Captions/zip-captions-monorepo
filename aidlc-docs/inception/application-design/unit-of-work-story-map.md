# Unit of Work — Requirements Traceability Map

Note: The User Stories stage was skipped for Phase 0 (infrastructure scaffolding with no new user-facing features). This document maps approved functional requirements (FR-01 through FR-07) and non-functional requirements (NFR-01 through NFR-04) to units of work.

---

## Functional Requirements → Units

| Requirement | Description | Unit |
|---|---|---|
| FR-01.1 | Pub Workspaces + Melos root configuration | Unit 1 |
| FR-01.2 | `zip_core` package stub (pubspec, analysis, build_runner) | Unit 1 + Unit 2 |
| FR-01.3 | `zip_captions` Flutter app shell | Unit 3 |
| FR-01.4 | `zip_broadcast` Flutter app shell | Unit 3 |
| FR-01.5 | `zip_supabase` scaffold | Unit 4 |
| FR-01.6 | `melos.yaml` scripts (bootstrap, test, analyze, format) | Unit 1 |
| FR-02.1 | Replace `provider` with Riverpod; add `riverpod_generator` + `build_runner` | Unit 2 |
| FR-02.2 | Migrate PoC providers to Riverpod (locale, settings, recording) | Unit 2 |
| FR-02.3 | Stub providers for Phase 1 domain objects (`SttEngineProvider`) | Unit 2 |
| FR-02.4 | Riverpod conventions documented (`RIVERPOD_CONVENTIONS.md`) | Unit 2 |
| FR-02.5 | Settings persistence via `shared_preferences` in Riverpod pattern | Unit 2 |
| FR-03.1 | GitHub Actions workflow (analyze + test) | Unit 5 |
| FR-03.2 | Build verification: iOS and Android | Unit 5 |
| FR-03.3 | Branch protection rules for `main` | Unit 5 |
| FR-03.4 | `analyze` + `test` as required status checks on `main` and `develop` | Unit 5 |
| FR-03.5 | Pinned Flutter SDK; `pubspec.lock` committed | Units 1 + 5 |
| FR-04.1 | Docker Compose for local Supabase stack | Unit 4 |
| FR-04.2 | Initial database migration (empty schema, RLS enabled) | Unit 4 |
| FR-04.3 | `.env.example` template; no secrets committed | Unit 4 |
| FR-04.4 | Local dev setup documentation | Unit 4 |
| FR-05.1 | `l10n.yaml` and ARB scaffold in `zip_core` | Unit 2 |
| FR-05.2 | Import + convert v1 translations (ar, de, es, fr, id, it, pl, pt, uk) | Unit 2 |
| FR-05.3 | Phase 0 English string keys seeded; non-English ARBs carry forward v1 keys | Unit 2 |
| FR-05.4 | Both apps consume `zip_core` l10n + own app-specific ARBs | Unit 3 |
| FR-06.1 | Desktop build verification (macOS, Windows, Linux) | Unit 6 |
| FR-06.2 | Platform setup documentation (`docs/PLATFORM_SETUP.md`) | Unit 6 |
| FR-06.3 | Build blockers logged as GitHub Issues | Unit 6 |
| FR-07.1 | Verify `ai-dlc` git submodule configured | Unit 1 |
| FR-07.2 | `.aidlc-rule-details/` present and populated | Unit 1 |
| FR-07.3 | Per-package `AGENTS.md` files verified | Unit 1 |

---

## Non-Functional Requirements → Units

| Requirement | Description | Primary Unit |
|---|---|---|
| NFR-01.1 | `very_good_analysis` zero warnings | Units 1, 2, 3 |
| NFR-01.2 | No `// ignore` in hand-written code | All units |
| NFR-01.3 | Package imports only (no relative cross-package imports) | Units 2, 3 |
| NFR-01.4 | `snake_case` files, `PascalCase` classes, `camelCase` variables | Units 2, 3 |
| NFR-02.1 | Test scaffold present; at least one passing test per package | Units 1, 2, 3 |
| NFR-02.2 | TDD workflow established | Unit 2 (exemplar) |
| NFR-02.3 | `glados` PBT framework in `zip_core` dev dependencies | Unit 2 |
| NFR-03.1 | No credentials committed; `.env.example` templates | Unit 4 |
| NFR-03.2 | Lock files committed; vulnerability scan in CI | Units 1, 5 |
| NFR-03.3 | CI pipeline access-controlled via branch protection | Unit 5 |
| NFR-03.4 | Transcript logging prohibition established | Unit 2 |
| NFR-03.5 | No default Supabase credentials in committed files | Unit 4 |
| NFR-04.1 | Conventional Commits format | All units |
| NFR-04.2 | Git worktrees, one PR per unit | All units |

---

## Phase 0 Exit Criteria → Units

| Exit Criterion | Verified By |
|---|---|
| `melos bootstrap` succeeds | Unit 1 |
| `melos run test` passes for all packages | Units 2, 3 (Unit 5 CI verifies) |
| `zip_captions` launches on iOS simulator | Unit 3 |
| `zip_broadcast` launches on macOS | Unit 3 |
| CI passes; `analyze` + `test` are required status checks | Unit 5 |
| Supabase local stack starts and accepts connections | Unit 4 |
| No `provider` dependency anywhere | Units 2, 3 |

---

## Coverage Verification

All 27 functional requirements and 14 non-functional requirements from `requirements.md` are assigned to at least one unit. No unassigned requirements.
