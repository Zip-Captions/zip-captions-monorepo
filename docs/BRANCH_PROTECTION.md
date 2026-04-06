# Branch Protection Rules

Configure these rules in **GitHub Settings > Branches > Branch protection rules** for the Zip Captions repository.

## `main` branch

| Setting | Value |
|---|---|
| **Require a pull request before merging** | Yes |
| Require approvals | 1 |
| Dismiss stale pull request approvals when new commits are pushed | Yes |
| **Require status checks to pass before merging** | Yes |
| Status checks that are required | `CI` |
| Require branches to be up to date before merging | Yes |
| **Require conversation resolution before merging** | Yes |
| **Do not allow bypassing the above settings** | Yes |
| **Allow force pushes** | No |
| **Allow deletions** | No |

## `develop` branch

| Setting | Value |
|---|---|
| **Require a pull request before merging** | Yes |
| Require approvals | 1 |
| Dismiss stale pull request approvals when new commits are pushed | Yes |
| **Require status checks to pass before merging** | Yes |
| Status checks that are required | `CI` |
| Require branches to be up to date before merging | No |
| **Allow force pushes** | No |
| **Allow deletions** | No |

## Notes

- The `CI` status check name corresponds to the `name: CI` field in `.github/workflows/ci.yml`.
- A `Build Verify` workflow (Android/iOS build checks) will be added once app platform scaffolding is in place. It can then be added as a required check.
- Status checks only appear in the dropdown after the workflow has run at least once. Push a test PR to trigger the workflows before configuring branch protection.
- `develop` does not require branches to be up to date, allowing merges without rebasing (reduces merge queue friction during active development).
