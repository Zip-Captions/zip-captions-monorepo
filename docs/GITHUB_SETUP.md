# GitHub Repository Setup Checklist

> One-time manual setup for the `zip-captions-monorepo` repository. Complete these steps before agents begin working.

---

## 1. Branch Protection Rules

Go to: Repository Settings > Branches > Add branch protection rule

### Rule 1: `main`

- **Branch name pattern:** `main`
- [x] Require a pull request before merging
  - [x] Require approvals: 1
  - [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require status checks to pass before merging
  - [x] Require branches to be up to date before merging
  - Status checks to require (add after CI is set up): `analyze`, `test`
- [x] Do not allow bypassing the above settings
- [x] Restrict who can push to matching branches (select: no one — all changes via PR)

### Rule 2: `develop`

- **Branch name pattern:** `develop`
- [x] Require a pull request before merging
  - [x] Require approvals: 1
- [x] Require status checks to pass before merging
  - Status checks to require (add after CI is set up): `analyze`, `test`
- [ ] Do NOT require branches to be up to date (avoids unnecessary rebases for parallel work)

---

## 2. Create `develop` Branch

```bash
git checkout main
git checkout -b develop
git push -u origin develop
```

Set `develop` as the default branch in Settings > General > Default branch.

---

## 3. GitHub Projects Board

1. Go to the repository or organization, click "Projects" tab
2. Create a new project: "Zip Captions v2"
3. Select "Board" layout
4. Create columns in this order:
   - **Backlog**
   - **Ready**
   - **In Progress**
   - **Tests Written**
   - **In Review**
   - **Done**
5. Link the project to the `zip-captions-monorepo` repository

---

## 4. Labels

Go to: Repository > Issues > Labels. Create the following:

### Status Labels (used by agent scripts)

| Label | Color (hex) | Description |
|-------|-------------|-------------|
| `status:ready` | `#0E8A16` (green) | Approved, available for agents to pick up |
| `status:in-progress` | `#FBCA04` (yellow) | Claimed by an agent, work underway |
| `status:tests-written` | `#1D76DB` (blue) | Failing tests committed |
| `status:in-review` | `#D93F0B` (orange) | PR open, awaiting review |

### Phase Labels

| Label | Color (hex) |
|-------|-------------|
| `phase:0` | `#C2E0C6` |
| `phase:1` | `#C2E0C6` |
| `phase:2` | `#C2E0C6` |
| `phase:3` | `#C2E0C6` |
| `phase:4` | `#C2E0C6` |
| `phase:5` | `#C2E0C6` |
| `phase:6` | `#C2E0C6` |
| `phase:7` | `#C2E0C6` |
| `phase:8` | `#C2E0C6` |

### Package Labels

| Label | Color (hex) |
|-------|-------------|
| `pkg:zip-core` | `#BFD4F2` |
| `pkg:zip-captions` | `#BFD4F2` |
| `pkg:zip-broadcast` | `#BFD4F2` |
| `pkg:zip-supabase` | `#BFD4F2` |

### Type Labels

| Label | Color (hex) |
|-------|-------------|
| `type:story` | `#E4E669` |
| `type:spike` | `#E4E669` |
| `type:bug` | `#E4E669` |

### Priority Labels (optional, for sorting)

| Label | Color (hex) |
|-------|-------------|
| `priority:p0-critical` | `#B60205` |
| `priority:p1-high` | `#D93F0B` |
| `priority:p2-medium` | `#FBCA04` |
| `priority:p3-low` | `#0E8A16` |

---

## 5. Fine-Grained Personal Access Token

1. Go to https://github.com/settings/tokens?type=beta
2. Click "Generate new token"
3. **Name:** `zip-captions-agent-project-access`
4. **Expiration:** 90 days (set a calendar reminder to renew)
5. **Repository access:** Only select repositories > `zip-captions-monorepo`
6. **Permissions:**
   - Issues: **Read and write**
   - Projects: **Read and write**
   - Metadata: **Read-only** (auto-granted)
   - Everything else: **No access**
7. Generate and copy the token

Create `.env.github` in the repo root:

```bash
GITHUB_PROJECT_TOKEN=github_pat_xxxxxxxxxxxx
GITHUB_REPO_OWNER=jptrsn
GITHUB_REPO_NAME=zip-captions-monorepo
GITHUB_PROJECT_NUMBER=1
```

Verify `.env.github` is in `.gitignore`. **Never commit this file.**

Your partner needs their own PAT with the same permissions, stored in their own `.env.github`.

---

## 6. Repository Settings

- **General > Features:** Enable Issues, disable Wiki (docs live in repo), enable Projects
- **General > Pull Requests:** Allow squash merging, allow merge commits, disable rebase merging. Auto-delete head branches after merge.
- **General > Default branch:** `develop`

---

## 7. Verification

After completing the above:

- [ ] `main` branch exists and is protected
- [ ] `develop` branch exists, is protected, and is the default branch
- [ ] GitHub Project board exists with all 6 columns
- [ ] All labels created
- [ ] PAT created and `.env.github` configured locally
- [ ] `.env.github` is gitignored
- [ ] Agent scripts (`scripts/list-available.sh`, etc.) are executable
- [ ] `./scripts/list-available.sh` runs without errors (returns empty list if no issues exist yet)
