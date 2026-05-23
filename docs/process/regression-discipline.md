# Regression Discipline

## Rule

Every bug fix must include a failing regression test first.

## When It's Mandatory

- Production incidents
- Customer-reported bugs
- Auth, permissions, or billing bugs
- Database migration bugs
- Data integrity issues

## Process

1. **Reproduce**: Create a deterministic local reproduction
2. **Red test**: Write a regression test that fails, proving the bug exists
3. **Commit red**: `test(red): regression test for <bug description>`
4. **Fix**: Implement the smallest change that turns the test green
5. **Commit green**: `fix: <bug description>`
6. **Verify**: Run full suite, confirm no regressions

## Regression Test Location

```
tests/regression/<area>/<bug-slug>-regression.test.<ext>
```

Include a top-of-file comment:
```
// Pre-fix: <description of the broken behavior>
// Regresses: PR #<number> or commit <hash>
```

## Baseline Comparison (Required)

| Metric | Before | After |
|--------|--------|-------|
| Tests passing | ??? | ??? |
| Tests failing | ??? | ??? |
| New tests added | 0 | ??? |

The failure count must not increase.
