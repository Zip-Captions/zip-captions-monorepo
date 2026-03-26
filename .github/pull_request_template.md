## Summary

<!-- What does this PR do? One or two sentences. -->

## User Story

<!-- Link to the story file and the GitHub issue -->

Implements: [P0-US-XXX](stories/phase-X/P0-US-XXX-description.md)
Issue: #NNN

## Package(s) Changed

<!-- Which packages does this PR touch? -->

- [ ] `zip_core`
- [ ] `zip_captions`
- [ ] `zip_broadcast`
- [ ] `zip_supabase`

## Acceptance Criteria Covered

- [ ] AC-1: ...
- [ ] AC-2: ...

## Test Coverage

| AC | Test File | Passes? |
|---|---|---|
| AC-1 | `packages/.../test/...` | [ ] |
| AC-2 | `packages/.../test/...` | [ ] |

## Checklist

- [ ] Tests written before implementation
- [ ] All new tests pass locally (`melos run test`)
- [ ] No existing tests broken
- [ ] Static analysis passes (`melos run analyze`)
- [ ] Generated code committed (`melos run generate`)
- [ ] Code follows project style (`docs/04-technical-specification.md`)
- [ ] Spec docs updated if behavior changed
- [ ] Story status updated via `./scripts/update-status.sh`
- [ ] No secrets, credentials, or PII in the code
- [ ] No out-of-scope features
- [ ] No new dependencies added without human approval

## Security Review

<!-- Check if this PR touches security-sensitive areas -->

- [ ] This PR does NOT modify encryption, auth, RLS policies, or transcript-handling code
- [ ] OR: This PR modifies security-critical code and the approach was pre-approved by a human (link to approval: ___)
