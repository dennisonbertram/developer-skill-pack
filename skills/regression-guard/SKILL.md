---
name: regression-guard
description: "Post-fix test-coverage analysis. Reviews a just-landed fix, generates targeted unit and regression tests, audits how the bug could have been caught earlier. Use after a fix is merged, when asked to 'add regression tests', 'pay off test debt', 'guard against regression', or 'ensure this doesn't happen again'."
version: 1.0.0
user_invocable: true
---

# Regression Guard

Post-fix test-debt payoff loop. Takes the git diff of a recent fix as input and generates targeted tests to prevent the bug from returning.

## Usage

```
/regression-guard [commit-range]
```

If no commit range is specified, uses `HEAD~3..HEAD`.

## Step 1 — Review What Was Fixed

Build a structured summary from git:

```bash
git log --oneline -10
git diff HEAD~3..HEAD
git log -1 --format=%B
```

Produce:
- **What broke** — the failure mode
- **What changed** — specific code paths
- **Files and functions touched**
- **Issue/PR reference**

## Step 2 — Generate Unit Tests

Write the smallest set of unit tests that lock in the correct behavior:

```
tests/unit/<area>/<fix-slug>.test.<ext>
```

Rules:
- Each test must be red when reverted against the pre-fix state
- Cover the happy path AND the corrected edge cases
- State which assertion would be red if reverted

## Step 3 — Generate Regression Tests

Write regression tests that construct the exact pre-fix state:

```
tests/regression/<area>/<fix-slug>-regression.test.<ext>
```

Rules:
- Include a top-of-file comment identifying the pre-fix state and symptom
- The test must pass the full check suite with no manual edits

## Step 4 — Audit: Could This Have Been Caught Earlier?

Answer honestly. Pick the most relevant gap category:

- **Missing boundary test** — contract assertion at a module seam
- **Missing negative test** — error path never exercised
- **Non-hermetic test harness** — shared state leaked between tests
- **Missing integration coverage** — only reproduced under production shape
- **Contract drift** — upstream contract widened/narrowed without downstream rebase

For each gap, write a concrete, actionable suggestion. No generic "add more tests."

## Step 5 — Recommend Integration Testing Additions

Name:
1. The specific test command to extend
2. The specific file to add a test into (or create)
3. A concrete test stub that would have caught the bug

## Output Report

Write to `docs/investigations/<date>-regression-guard-<fix-slug>.md`:

1. Fix summary
2. Generated unit tests (file paths + descriptions)
3. Generated regression tests (file paths + pre-fix state each reconstructs)
4. "Could this have been caught earlier?" diagnosis
5. Integration testing recommendations
6. Baseline comparison table

## Ship as a Draft PR

1. Create a new branch
2. Commit the generated test files and output report
3. Open a draft PR against main
4. Never push directly to main
