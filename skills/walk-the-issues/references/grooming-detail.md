# Issue Grooming — Detailed Reference

## Grooming Rubric

Each issue is evaluated against four pass/fail criteria plus one informational label check. An issue is `well-specified` only if it passes all four pass/fail criteria.

### 1. Problem Statement (Pass/Fail)

**Pass:** The issue describes a concrete, observable problem or a specific desired behavior change. A developer unfamiliar with the codebase could understand what is wrong or what needs to exist.

**Fail indicators:**
- "Fix the bug with X" (no description of the bug)
- "Improve performance" (no baseline, no target)
- "Refactor Y" (no reason or outcome)

**Action on fail:** Post a comment requesting specifics. Label `needs-clarification`.

### 2. Acceptance Criteria (Pass/Fail)

**Pass:** The issue has explicit, testable conditions for "done." Can be a checklist, a list of expected behaviors, or a described input/output.

**Fail indicators:**
- No criteria section at all
- Criteria like "it works" or "it's better"
- Missing edge cases for bug reports (what input triggers it?)

**Action on fail:** Attempt to infer and add a criteria section as a comment:
```
## Suggested Acceptance Criteria
- [ ] {criterion 1}
- [ ] {criterion 2}
```
Then label `needs-clarification` for the author to confirm.

### 3. Scope (Pass/Fail)

**Pass:** The issue addresses exactly one concern. A single PR could reasonably close it without touching unrelated systems.

**Fail indicators:**
- "Fix X and also refactor Y and add feature Z"
- The issue title contains "and"
- Body references multiple unrelated file areas

**Action on fail:** Comment suggesting a split. Create child issues if you can fully specify them. Label the parent `blocked` (on children).

### 4. Blockers (Pass/Fail)

**Pass:** Either has no blockers, or all blockers are explicitly listed with issue numbers.

**Fail indicators:**
- "Depends on the new auth system" with no reference
- Implicitly requires another issue to be merged first

**Action on fail:** Find the blocking issue(s). Add `blocked-by: #N` to the issue body. Label `blocked`.

### 5. Labels (Informational)

Labels don't block `well-specified` status but must be applied before entering the loop.

**Required label categories:**
- **Type**: `bug`, `enhancement`, `chore`, `docs`, `test`
- **Size**: `small` (< 2h), `medium` (2–8h), `large` (> 8h)
- **Status**: `well-specified`, `needs-clarification`, `blocked`, `pr-created`

---

## Label Taxonomy

| Label | Meaning |
|-------|---------|
| `well-specified` | Passes all 5 grooming criteria, ready to implement |
| `needs-clarification` | Failed one or more criteria, awaiting author response |
| `blocked` | Depends on another open issue or external factor |
| `pr-created` | Implementation PR has been opened |
| `small` | Estimated < 2 hours of implementation |
| `medium` | Estimated 2–8 hours |
| `large` | Estimated > 8 hours — consider splitting |
| `bug` | Fixes incorrect behavior |
| `enhancement` | Adds new functionality |
| `chore` | Maintenance, refactor, tooling |
| `docs` | Documentation only |
| `test` | Test-only changes |

---

## Grooming Subagent Output Format

Each grooming subagent writes to `docs/investigations/issue-{number}-grooming.md`:

```markdown
# Issue #{number} Grooming: {title}

## Scores
- Problem Statement: PASS / FAIL — {reason}
- Acceptance Criteria: PASS / FAIL — {reason}
- Scope: PASS / FAIL — {reason}
- Blockers: PASS / FAIL — {reason}

## Overall: WELL-SPECIFIED / NEEDS-CLARIFICATION / BLOCKED

## Recommended Labels
- Type: {bug|enhancement|chore|docs|test}
- Size: {small|medium|large}
- Status: {well-specified|needs-clarification|blocked}

## Actions
- [ ] {action 1}
- [ ] {action 2}

## Comments to Post
{comment text if any, or "none"}
```

---

## Parallel Batch Strategy

To groom efficiently:

1. Fetch all open issues in one call
2. Group into batches of 4–6
3. Spawn all subagents in a batch simultaneously
4. Wait for batch to complete, then apply results
5. Start next batch

Do not spawn all issues at once if there are > 20 — context overhead becomes unmanageable.

---

## Edge Cases

**Stale issues (> 6 months old, no activity):**
Post a comment: "This issue has been open for 6+ months with no activity. Is it still relevant?" Label `needs-clarification`. Do not close automatically.

**Issues with PRs already open:**
Check `gh issue view {number} --json linkedPRs`. If a PR is already open and unmerged, label `pr-created` and skip.

**Issues referencing external dependencies:**
If the fix requires an upstream library change, label `blocked` and document the external dependency in the issue body.
