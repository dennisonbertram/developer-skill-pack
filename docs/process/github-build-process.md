# GitHub Build Process

## Issue-Driven Development

Every meaningful change starts with an issue. Three issue types are available:

1. **Feature Slice** (`feat:`) — A buildable, PR-sized feature with behavior contracts
2. **Bug Regression** (`fix:`) — A bug fix with mandatory regression test plan
3. **Research Spike** (`research:`) — Time-boxed research with structured output

## One Issue, One Branch, One PR

```
Issue → Branch → PR → CI → Merge
```

- One issue per PR
- One branch per issue
- Branch naming: `feat/<slug>`, `fix/<slug>`, `research/<slug>`
- PR-gated main branch

## Branch Protection Targets

When fully enabled:

- Require pull request before merge
- Require status checks to pass (CI)
- Require linear history
- Block force pushes and branch deletion on main
- Require at least 1 approval (with 2+ active reviewers)

## CI Gates

Before merge:

1. Type-check passes
2. Full test suite passes (or pre-existing failures documented)
3. Linting / formatting passes
4. No new security vulnerabilities

## Agent Workflow

```
1. Read context docs (repo-practices, known-issues)
2. Create or claim an issue
3. Create a worktree branch
4. Run baseline tests before editing
5. Write failing test (Red)
6. Implement (Green)
7. Run full checks
8. Push branch, create PR
9. CI passes → merge
```
