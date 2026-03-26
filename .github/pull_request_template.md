## Summary

<!-- What does this PR do? One or two sentences. -->

## Feature

<!-- Describe the feature being implemented. Link to AI-DLC inception artifacts if available. -->

AI-DLC inception artifacts: `aidlc-docs/inception/` (commit the aidlc-docs/ directory if you want a permanent record)

## Package(s) Changed

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

- [ ] Tests written before implementation (TDD)
- [ ] All new tests pass locally (`melos run test`)
- [ ] No existing tests broken
- [ ] Static analysis passes (`melos run analyze`)
- [ ] Generated code committed (`melos run generate`)
- [ ] Code follows project style (`docs/04-technical-specification.md`)
- [ ] No secrets, credentials, or PII in the code
- [ ] No out-of-scope changes
- [ ] No new dependencies added without human approval

## Security Review

- [ ] This PR does NOT modify encryption, auth, RLS policies, or transcript-handling code
- [ ] OR: This PR modifies security-critical code and the approach was pre-approved by a human (link to approval: ___)
