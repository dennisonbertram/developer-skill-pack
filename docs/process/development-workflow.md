# Development Workflow

## Before You Start

Before any implementation work, read these:

1. `docs/context/repo-practices.md` — durable patterns and rules
2. `docs/context/known-issues.md` — known bugs and workarounds

Match your implementation to documented patterns first. Deviate only with a stated reason.

## Bootstrap

Every fresh clone, worktree, or agent session must install dependencies before running tests, type-checks, or builds.

## Worktree Isolation

Every implementation task happens in a git worktree. No exceptions. This is about race-safety across parallel agent processes.

1. The main checkout stays on `main`. Never switch branches in it.
2. Every implementation subagent gets a worktree (`isolation: "worktree"`).
3. Stay synced with `origin/main` before starting any task.

## Behavior-First TDD

Every implementation change follows Red-Green-Refactor:

1. **RED** — Write a failing test that defines the desired behavior. Run it. Commit.
2. **GREEN** — Write the minimum code to make the test pass. Run it. Commit.
3. **REFACTOR** — Clean up while keeping tests green.

Rules:
- Never modify `src/` before writing the corresponding test
- Bug fixes require a regression test first
- Features require an acceptance or integration test first
- If you cannot point to the exact failing test, stop and define it

## Branch Protection

Direct pushes to `main` are forbidden. Every change goes through a PR:

```
git checkout -b fix/my-change
# ... make changes and commit ...
git push origin fix/my-change
gh pr create --base main --title "fix: description"
```

## Definition Of Done

A change is not done until:

1. Failing test observed first (Red commit)
2. Implementation passes test (Green commit)
3. Targeted test suite is green
4. Adjacent regression suite is green
5. Type-check passes
6. Full test suite failure count has not increased
7. Docs updated
8. PR opened with passing CI
