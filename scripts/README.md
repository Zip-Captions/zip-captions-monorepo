# Scripts

Utility scripts for development workflow tasks.

## Git Worktree Helpers

Each unit of work runs in an isolated git worktree. See `CONTRIBUTING.md` Section 2 for the full worktree workflow.

```bash
# Create a worktree for a new feature (run from monorepo root):
git worktree add ../zip-captions-<feature-name> -b feature/<feature-name>

# List all active worktrees:
git worktree list

# Remove a worktree after its PR has merged:
git worktree remove ../zip-captions-<feature-name>
git branch -d feature/<feature-name>
```

## Adding Scripts

Place any project-specific automation scripts here. Follow the naming convention `<verb>-<noun>.sh` (e.g., `check-coverage.sh`, `seed-fixtures.sh`).
