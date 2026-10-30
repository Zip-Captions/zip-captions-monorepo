# Scripts

Utility scripts for development workflow tasks.

## Hooks

`install-hooks.sh` installs the local pre-push hook, which runs
`dart analyze --fatal-infos` and blocks the push on any warning or info:

```bash
./scripts/install-hooks.sh
```

Branching workflow lives in `CONTRIBUTING.md` Section 2. There are no worktree
helpers: this project works one branch at a time in the main checkout.

## Adding Scripts

Place any project-specific automation scripts here. Follow the naming convention `<verb>-<noun>.sh` (e.g., `check-coverage.sh`, `seed-fixtures.sh`).
