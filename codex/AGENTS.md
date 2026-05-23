# Agent Workflow — Codex CLI

These rules apply to all agent work in this repository when using OpenAI Codex CLI.

## TDD Is Non-Negotiable

Every implementation change must follow Red-Green-Refactor:

1. **RED** — Write the failing test first and run it.
2. **GREEN** — Make the smallest change that passes.
3. **REFACTOR** — Clean up while the tests stay green.

Never modify `src/` before writing the corresponding test.

## Before You Start

1. Read `docs/context/repo-practices.md` — durable patterns and rules
2. Read `docs/context/known-issues.md` — known bugs and workarounds
3. Run the baseline test command for the surface you're about to change

## Branch Discipline

- Never push directly to `main`
- One issue per PR, one branch per issue
- All changes via PR with CI passing

## Worktree Isolation

Every implementation task happens in a git worktree:

```bash
git fetch origin
git worktree add -b <feature-branch> /tmp/<project>-<name> origin/main
cd /tmp/<project>-<name>
<package-manager> install
```

## Definition Of Done

1. Failing test observed first
2. Targeted test suite green
3. Adjacent regression suite green
4. Typecheck passes
5. Full test suite passes
6. Docs updated
7. PR opened on a branch
