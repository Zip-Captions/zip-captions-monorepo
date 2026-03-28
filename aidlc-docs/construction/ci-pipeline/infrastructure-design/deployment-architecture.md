# Deployment Architecture — Unit 5: CI/CD Pipeline

## Architecture Overview

GitHub Actions workflows triggered by Git events. No deployment targets — CI only (build verification, not release).

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Repository                                       │
│                                                         │
│  Push/PR Event                                          │
│       │                                                 │
│       ├── ci.yml ──────────────────────────────┐        │
│       │   Trigger: PR (all), push main/develop │        │
│       │   Runner: ubuntu-latest                │        │
│       │   Steps: analyze → test → coverage     │        │
│       │          → pub outdated                │        │
│       │                                        │        │
│       └── build-verify.yml ────────────────┐   │        │
│           Trigger: PR to main/develop      │   │        │
│           Runner: ubuntu-latest            │   │        │
│           Steps: build APK (zip_captions)  │   │        │
│                                            │   │        │
│  ┌─────────────────────────────────────────┘   │        │
│  │                                             │        │
│  │  Artifacts: coverage/lcov.info              │        │
│  │  Status Checks: ci, build-android           │        │
│  └─────────────────────────────────────────────┘        │
│                                                         │
│  Branch Protection Rules                                │
│  ┌─────────────────────────────────────────────────┐    │
│  │  main:    require ci ✓, require PR review       │    │
│  │  develop: require ci ✓, require PR review       │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Workflow Trigger Flow

### ci.yml

```
Developer pushes code
       │
       ├─── Push to main/develop? ──► Run ci.yml
       │
       └─── Opens/updates PR? ──► Run ci.yml
                                      │
                                      ▼
                              Concurrency check:
                              ci-${{ github.ref }}
                                      │
                              ┌───────┴───────┐
                              │ In-progress    │
                              │ run exists?    │
                              │   ▼            │
                              │ Cancel it      │
                              └───────┬───────┘
                                      │
                                      ▼
                              Run: analyze → test → upload coverage → pub outdated
                                      │
                                      ▼
                              Report status check ✓/✗
```

### build-verify.yml

```
Developer opens/updates PR targeting main or develop
       │
       ▼
Concurrency check: build-${{ github.ref }}
       │
       ▼
Run: setup → build APK (zip_captions)
       │
       ▼
Report status check ✓/✗
```

## Branch Protection Setup

Configure in GitHub Settings → Branches:

### `main` branch

| Setting | Value |
|---|---|
| Require pull request before merging | Yes |
| Required approvals | 1 |
| Require status checks to pass | Yes |
| Required checks | `ci` |
| Require branches to be up to date | Yes |
| Allow force pushes | No |
| Allow deletions | No |

### `develop` branch

| Setting | Value |
|---|---|
| Require pull request before merging | Yes |
| Required approvals | 1 |
| Require status checks to pass | Yes |
| Required checks | `ci` |
| Require branches to be up to date | No (allow merge without rebase) |
| Allow force pushes | No |
| Allow deletions | No |

## File Structure

```
.github/
└── workflows/
    ├── ci.yml              # Analyze + test + coverage + pub outdated
    └── build-verify.yml    # Platform build verification (Android, macOS, Windows, Linux)
```

## Future Phases

- **iOS CI builds**: Add `macos-latest` runner job when cost/benefit justifies it
- **Release workflows**: CD pipeline for Play Store / App Store deployment (Phase 6)
- **osv-scanner**: Full CVE scanning when dependency tree grows
- **Codecov integration**: External coverage reporting service
