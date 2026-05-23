---
name: walk-the-issues
description: This skill should be used when the user asks to "walk the issues", "work through github issues", "groom and implement issues", "tackle the issue backlog", "start the issue loop", "go through tickets", "work all open issues", "clear the backlog", "process all tickets", or "close out open issues". Orchestrates an end-to-end workflow: groom all open GitHub issues with subagents, then loop through them one-by-one — branching, researching, implementing with swarms, testing, committing, merging, and creating PRs until all issues are complete.
version: 0.1.0
user_invocable: true
---

# Walk the Issues

Orchestrate a full end-to-end GitHub issue grooming and implementation workflow. This skill drives two sequential phases: **Grooming** (analyze all open issues for clarity and completeness), then **Implementation Loop** (branch → research → swarm implement → test → PR → repeat).

---

## Phase 1: Grooming

Before touching any code, groom every **open** issue so the implementation loop only encounters well-specified work. Closed issues are skipped entirely — do not re-open or re-analyze them.

### Grooming Setup

```bash
# Ensure gh CLI is authenticated for your target account
# gh auth switch --user YOUR_GITHUB_USERNAME  # Uncomment if needed
gh issue list --state open --json number,title,labels,body,assignees --limit 200
```

### Spawn Grooming Subagents

For each open issue, spawn a **read-only Explore subagent** (no worktree needed) to analyze it. Run subagents in parallel batches of 4-6.

Each grooming subagent evaluates:

1. **Already addressed?** — Search the codebase for evidence the issue has already been fixed or implemented. Check recent commits, PR history, and relevant source files. If the work is already done, mark the issue `already-resolved` and it will be closed (see Apply Grooming Results below).
2. **Clarity** — Is the problem statement unambiguous?
3. **Acceptance criteria** — Are "done" conditions explicit?
4. **Scope** — Is the issue atomic (one concern only)?
5. **Blockers** — Does it depend on another issue?
6. **Labels** — Does it have appropriate labels (bug, enhancement, chore)?
7. **Effort signal** — Rough size (small/medium/large)?

Each subagent outputs its findings to `docs/investigations/issue-{number}-grooming.md`.

### Apply Grooming Results

After subagents complete, the top-level agent applies grooming changes:

- **Close already-resolved issues** with a comment explaining what existing code/commit addresses it:
  ```bash
  gh issue comment {number} --body "Closing — this has already been addressed in {commit/file/PR}. ..."
  gh issue close {number}
  ```
- Add labels: `well-specified`, `needs-clarification`, `blocked`, `small`, `medium`, `large`
- Post a comment on unclear issues asking for clarification
- Close duplicates with a reference to the canonical issue
- Update issue body with structured acceptance criteria if missing

```bash
# Label example
gh issue edit {number} --add-label "well-specified,small"

# Comment example
gh issue comment {number} --body "Needs clarification: ..."
```

Only issues labeled `well-specified` (and still open) enter the implementation loop.

---

## Phase 2: Implementation Loop

Repeat until all `well-specified` open issues have associated PRs.

### Step 1 — Select Next Issue

```bash
gh issue list --state open --label "well-specified" --json number,title,labels --limit 1
```

Pick the lowest-numbered unhandled issue. If none remain, the loop is complete — report a summary and stop.

### Step 2 — Create a Working Branch

```bash
ISSUE_NUM={number}
SLUG=$(echo "{title}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-40)
BRANCH="issue-${ISSUE_NUM}-${SLUG}"
git checkout main && git pull upstream main
git checkout -b "$BRANCH"
```

All work for this issue happens on `$BRANCH`. Never commit directly to `main`.

### Step 3 — Research and Planning

Spawn **read-only Explore subagents** (no worktree needed) to produce a structured implementation plan. These subagents should:

1. Read the issue body, comments, and any referenced files
2. Explore the relevant codebase sections
3. Identify all files likely to change
4. Use **Context7** to fetch documentation for any unfamiliar libraries or tools:
   ```
   Use context7 to look up: {library or tool name}
   ```
5. Identify existing tests covering affected code
6. Output plan to `docs/plans/issue-{number}-plan.md` using the project plan template

Plan must include:
- Summary of changes required
- Files to create/modify
- Testing strategy (unit + regression)
- Risk areas / edge cases
- Commit strategy (what logical commits to make)
- Library Research section (context7 findings, if any)

### Step 4 — Regression Tests First

Before implementing, write regression tests for every code path that will change.

Spawn a **general-purpose subagent with worktree isolation** to:

1. Read `docs/plans/issue-{number}-plan.md`
2. Identify existing test files covering affected areas
3. Add regression tests that will **fail** until the implementation is correct
4. Commit the failing tests:
   ```bash
   git add <specific test files>
   git commit -m "test(#{number}): add regression tests for {area}"
   ```

This ensures the test suite is red before implementation begins.

### Step 5 — Implement with Swarms

Use a **swarm** (2–4 agents in parallel per wave) for implementation. Each agent works in its own **worktree** (`isolation: "worktree"`).

> **Review Policy** — This project is internal software under the user's control, not deployed in an adversarial environment. The default swarm skill requires 3 consecutive passing reviews across Security/UX/Correctness perspectives. **That is not required here.** A single round of review is sufficient. The hard requirements are:
> 1. All tests pass (`go test ./...` + `-race`)
> 2. Regression tests are written for every changed code path
> 3. New functionality has unit tests
> 4. Coverage gate holds (80% minimum)
>
> Only escalate to multi-round review if the change touches security-sensitive code (auth, permissions, token handling) or concurrent shared state. When in doubt, do one review and move on.

Commit discipline inside worktrees:
- Commit after each logical unit of work (not just at the end)
- Commit message format: `feat(#{number}): {what changed}`
- Stage specific files — never `git add -A`

After each wave:
1. Merge worktrees back to `$BRANCH`:
   ```bash
   git checkout "$BRANCH"
   git merge --no-ff {worktree-branch}
   git worktree remove {worktree-path}
   git branch -d {worktree-branch}
   ```
2. Resolve any conflicts
3. Commit the merge: `git commit -m "chore(#{number}): merge wave-{n} to branch"`
4. Run tests to verify green state before next wave

### Step 6 — Run Tests

After all implementation waves are merged:

```bash
go test ./...
go test ./... -race
./scripts/test-regression.sh
```

All tests must pass. If any fail:
- Spawn a debug subagent to identify the root cause
- Fix in a new commit on `$BRANCH`
- Re-run until clean

### Step 7 — New Tests for New Functionality

For any new functions, types, or behaviors added during implementation, spawn a subagent to:

1. Identify new public APIs and behaviors introduced
2. Write unit tests and integration tests for new functionality
3. Ensure coverage gate is maintained (80% minimum)
4. Commit: `test(#{number}): add tests for new functionality`

Run the full suite again to confirm everything is green.

### Step 8 — Document Issues

If anything unexpected occurred during implementation (surprising behavior, edge cases discovered, architectural constraints, deferred work), append an entry to `docs/logs/engineering-log.md`.

Use the log format defined in `references/implementation-loop-detail.md#engineering-log-format`.

File new GitHub issues for any deferred work discovered.

### Step 9 — Create PR

Use the PR body template from `references/implementation-loop-detail.md#pr-body-template`.

```bash
gh pr create \
  --title "fix/feat(#{number}): {issue title}" \
  --body "$(cat <<'EOF'
{paste from references/implementation-loop-detail.md PR body template}
EOF
)" \
  --base main \
  --head "$BRANCH"
```

### Step 10 — Mark Ticket Handled

```bash
gh issue edit {number} --add-label "pr-created"
gh issue comment {number} --body "PR created: {pr-url}"
```

Do **not** close the issue — the PR merge will close it via the "Closes #N" reference.

### Step 11 — Loop

Return to Step 1 and select the next `well-specified` open issue.

---

## Loop Completion

When no `well-specified` open issues remain:

1. Print a summary: issues handled, PRs created, issues skipped (needs-clarification)
2. List any issues filed for deferred work
3. Report `Task status: DONE`

---

## Commit Discipline (Summary)

| When | What to commit | Format |
|------|---------------|--------|
| After writing regression tests | Test files only | `test(#{N}): add regression tests for {area}` |
| After each worktree wave | Merge commit | `chore(#{N}): merge wave-{n} to branch` |
| After implementation units | Specific changed files | `feat(#{N}): {what}` or `fix(#{N}): {what}` |
| After new functionality tests | Test files | `test(#{N}): add tests for new functionality` |

Never commit directly to `main`. Never use `git add -A`. Always stage specific files.

---

## Additional Resources

- **`references/grooming-detail.md`** — Detailed grooming rubric and label taxonomy
- **`references/implementation-loop-detail.md`** — Edge cases, merge conflict handling, worktree cleanup

See also: `swarm` skill (for spawning implementation waves), `context7` (for library docs), `code-review` skill (for optional external review — one round is sufficient for this project).
