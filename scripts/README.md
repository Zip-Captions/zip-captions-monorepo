# GitHub Project Scripts

Wrapper scripts for agents to interact with the GitHub Projects board. These scripts provide a controlled interface — agents use these instead of raw `gh` CLI commands.

## Prerequisites

### 1. GitHub CLI

Install the GitHub CLI: https://cli.github.com/

### 2. Fine-Grained Personal Access Token

See `docs/GITHUB_SETUP.md` Section 5 for detailed PAT creation instructions.

### 3. Environment Setup

Create a `.env.github` file in the repo root (this file is gitignored):

```bash
GITHUB_PROJECT_TOKEN=github_pat_xxxxxxxxxxxx
GITHUB_REPO_OWNER=jptrsn
GITHUB_REPO_NAME=zip-captions-monorepo
GITHUB_PROJECT_NUMBER=1
```

The scripts source this file automatically. Never commit it.

### Security Notes

- The PAT intentionally has NO contents/push access. Agents push code via their normal git credentials, which are governed by branch protection rules.
- Even if an agent reads the token value, it cannot push code, change repo settings, or perform destructive actions through it.
- Branch protection on `main` and `develop` is your primary defense against unauthorized code changes.

## Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `list-available.sh` | Show stories ready for work | `./scripts/list-available.sh` |
| `claim-story.sh` | Assign a story and move to In Progress | `./scripts/claim-story.sh P0-US-001` |
| `update-status.sh` | Move a story to a new status column | `./scripts/update-status.sh P0-US-001 "Tests Written"` |

## Valid Statuses

Agent-settable: "In Progress", "Tests Written", "In Review"

Human-only: "Ready", "Done"
