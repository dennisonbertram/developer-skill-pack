---
name: debug
description: "Deterministic 7-phase debugging workflow — symptom capture, git archaeology, reproduce with a targeted test, log inspection, hypothesis, fix + green confirmation, regression test + commit. Use when asked to 'debug', 'fix a bug', 'investigate a failure', 'diagnose', 'root cause', or 'why is this broken'."
version: 1.0.0
user_invocable: true
---

# Debug

Deterministic 7-phase debugging workflow. Walk the phases in order. If a phase's gate cannot be satisfied, go back rather than skipping ahead.

## Phase 1 — Symptom Capture

Collect the symptom completely before touching any code.

Record:
- Error message (exact text, not paraphrase)
- Stack trace or log excerpt
- Affected route / component / module
- Environment: local | CI | production
- First-seen commit or deployment (if known)

**Gate**: One-paragraph incident description in working notes before Phase 2.

## Phase 2 — Git Archaeology

Find the most likely causal change.

```bash
git log --oneline -20
git diff HEAD~5..HEAD -- <suspected-path>
git log --oneline --all -- <suspected-path>
```

**Gate**: Most likely causal commit named, or ambiguity noted.

## Phase 3 — Reproduce With a Targeted Test

**Do not skip to Phase 4 without a reproducible failure.**

Choose the smallest command that reproduces the symptom. If no existing test covers it, write a minimal failing test first — this is the TDD Red step and it is non-negotiable.

```bash
# Targeted test
<test-runner> <specific-test-file>

# Broader search
<test-runner>
```

**Gate**: Exact test name and failure message recorded. If no red test can be produced, return to Phase 1.

## Phase 4 — Log Inspection

Now that the symptom is pinned, read the logs.

```bash
# Local
<dev-server-command> 2>&1 | tee /tmp/debug.log

# Production
<log-command> --tail 100
```

Look for: missing env vars, API error codes, unhandled rejections, database errors, timing drift.

**Gate**: Relevant log excerpts captured.

## Phase 5 — Hypothesis + Minimal Verification

State a single falsifiable hypothesis before changing anything:

> "I believe the bug is caused by X because Y. I will verify by Z."

Write a minimal test or probe that confirms or disproves. Do not fix anything in this phase.

If disproved, return to Phase 2 with new evidence.

**Gate**: Hypothesis survived verification.

## Phase 6 — Fix + Green Confirmation

Apply the smallest code change that turns the Phase 3 test green. Nothing more.

Then run full checks:

```bash
<typecheck-command>
<test-command>
```

**Baseline comparison table (required):**

| Metric | Before | After |
|--------|--------|-------|
| Tests passing | ??? | ??? |
| Tests failing | ??? | ??? |
| New tests added | 0 | ??? |

**Gate**: Failure count must not increase versus baseline.

## Phase 7 — Regression Test + Commit

1. Confirm the Phase 3 reproduction test is green and committed
2. Write the commit message:

```
fix(<area>): <short description>

Root cause: <why>
Symptom: <what the user saw>
Fix: <what changed>
Regression: tests/<path>

Closes #<issue-number>
```

3. Push to a branch and open a PR. Never push directly to main.

## Phase-Gate Checklist

- [ ] Phase 1: symptom captured with exact error text
- [ ] Phase 2: most likely causal commit named
- [ ] Phase 3: red test exists and was observed failing
- [ ] Phase 4: relevant log excerpts captured
- [ ] Phase 5: hypothesis stated before any fix
- [ ] Phase 6: before/after baseline table filled; failure count did not increase
- [ ] Phase 7: regression test committed; PR opened on a branch
