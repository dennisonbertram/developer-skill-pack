# Implementation Loop — Detailed Reference

## Worktree Lifecycle

Every swarm agent works in its own git worktree. Managing these correctly prevents merge chaos.

### Creating a Worktree (done by each swarm agent)

```bash
# Each wave agent gets a unique worktree
WAVE=1
AGENT=a
WORKTREE_BRANCH="issue-${ISSUE_NUM}-wave${WAVE}-${AGENT}"
WORKTREE_PATH=".harness/worktrees/${WORKTREE_BRANCH}"

git worktree add "$WORKTREE_PATH" -b "$WORKTREE_BRANCH" "$BRANCH"
cd "$WORKTREE_PATH"
# ... do work, commit regularly ...
```

### Merging a Worktree Back to Branch

After a wave completes, merge each worktree sequentially (not simultaneously):

```bash
cd {project-root}

# For each completed worktree:
git checkout "$BRANCH"
git merge --no-ff "$WORKTREE_BRANCH" -m "chore(#${ISSUE_NUM}): merge wave-${WAVE}-${AGENT} to branch"

# Clean up
git worktree remove "$WORKTREE_PATH" --force
git branch -d "$WORKTREE_BRANCH"
git worktree prune
```

**Always merge sequentially.** Merging two worktrees simultaneously causes conflicts.

### Conflict Resolution

If a merge conflict occurs:
1. Identify conflicting files
2. Spawn a short-lived debug subagent to analyze the conflict
3. Resolve by understanding what each side intended — never blindly accept ours or theirs
4. Commit the resolution with: `fix(#${ISSUE_NUM}): resolve merge conflict in {file}`

---

## Wave Structure for Swarms

A "wave" is one round of parallel swarm agents. Structure waves by file ownership:

**Wave planning rules:**
- Agents in the same wave MUST NOT touch the same files
- Wave size: 2–4 agents max
- If all changes are sequential or dependent, use a single agent (no wave)

**Example wave decomposition for a feature:**
```
Wave 1 (parallel):
  Agent A: data layer changes (models, store)
  Agent B: test infrastructure (helpers, fixtures)

Wave 2 (depends on Wave 1, parallel):
  Agent C: business logic using new data layer
  Agent D: additional unit tests

Wave 3 (sequential if needed):
  Agent E: integration tests, final wiring
```

Document the wave plan in `docs/plans/issue-{number}-plan.md` before spawning.

---

## Context7 Usage Pattern

Before implementing any unfamiliar library or tool integration, fetch documentation:

```
# In your planning/research phase, explicitly request:
"Use context7 to look up: {library name} — focusing on {specific API or feature}"
```

Use context7 for:
- Third-party Go packages (unfamiliar APIs)
- OpenAI / Anthropic API changes
- Any library where the current usage might be out of date
- New packages being introduced for the first time

Document findings in `docs/plans/issue-{number}-plan.md` under a "Library Research" section.

---

## Regression Test Strategy

### What to test before implementing

For every file that will be modified, find its existing tests and determine:

1. **Currently passing tests** — these must still pass after implementation (regression baseline)
2. **Gaps** — behaviors that exist in code but aren't tested — add tests for these too
3. **The exact behaviors that will change** — write tests that currently pass the old behavior and will fail with the new behavior (red-green-refactor)

### Test file naming convention

Follow the project's existing convention. For this project:
- Unit tests: `{package}_test.go` in the same package
- Integration tests: `{package}_integration_test.go`
- Regression marker: add `// regression: issue #{N}` comment above each new test

### When no tests exist for affected code

If modified code has 0% test coverage:
1. Write basic smoke tests first (panic/happy path)
2. Then write the regression tests
3. Note in engineering log: "Added initial test coverage for {area} while fixing #{N}"

---

## Test Commands

```bash
# Run all tests
go test ./...

# Run with race detector (mandatory before PR)
go test ./... -race

# Run regression suite with coverage gate
./scripts/test-regression.sh

# Run a specific package
go test ./internal/harness/...

# Run a specific test
go test ./internal/harness/... -run TestFunctionName -v
```

---

## Engineering Log Format

Append to `docs/logs/engineering-log.md` whenever:
- An unexpected behavior was discovered
- A design decision was made that isn't obvious
- A deferred item was identified
- A workaround was used (and why)

```markdown
## {YYYY-MM-DD} — Issue #{N}: {title}

### Unexpected: {short description}
{What was surprising or difficult}

### Decision
{What was decided and why — include alternatives considered}

### Follow-up
{New issue to file, or "none"}
```

---

## PR Body Template

```markdown
## Summary

Closes #{N}

{2-4 bullet points describing what changed}

## Changes

- `{file}` — {what changed}
- `{file}` — {what changed}

## Testing

- [ ] Regression tests added for affected code paths
- [ ] New functionality tests added
- [ ] `go test ./...` passing
- [ ] `go test ./... -race` passing
- [ ] `./scripts/test-regression.sh` passing

## Notes for Reviewer

{Anything important: design decisions, edge cases, follow-up work}

🤖 Implemented via walk-the-issues skill
```

---

## Loop Termination Conditions

The loop ends when any of these is true:

1. **All `well-specified` issues have `pr-created` label** — normal completion
2. **No more well-specified issues** (only `needs-clarification` or `blocked`) — partial completion, report remaining
3. **User interrupts** — save state in `docs/investigations/walk-the-issues-state.md` with current issue and progress

On completion, print a summary:
```
Walk-the-issues complete.

PRs created: N
Issues handled: [list with PR links]
Issues skipped (needs-clarification): [list]
Issues skipped (blocked): [list]
New issues filed: [list]

Task status: DONE
```

---

## Handling Large Issues

If an issue is labeled `large` (> 8h estimated):

1. Propose a split in a comment: "This issue is large. Suggest splitting into: {list}"
2. If the user has pre-approved working large issues, proceed but use more waves
3. Large issues may require 3–5 waves instead of 1–2
4. Commit more frequently (every logical chunk, not just at wave boundaries)
5. Aim for PR that is reviewable — if changes are > 500 lines, consider splitting the PR too

---

## GitHub Label Setup

If the required labels don't exist in the repo, create them first:

```bash
gh label create "well-specified" --color "0E8A16" --description "Issue is clear and ready to implement"
gh label create "needs-clarification" --color "FFA500" --description "Issue needs more detail before implementation"
gh label create "blocked" --color "B60205" --description "Blocked by another issue or external factor"
gh label create "pr-created" --color "5319E7" --description "Implementation PR has been opened"
gh label create "small" --color "C2E0C6" --description "Estimated < 2 hours"
gh label create "medium" --color "FEF2C0" --description "Estimated 2-8 hours"
gh label create "large" --color "F9D0C4" --description "Estimated > 8 hours"
```
