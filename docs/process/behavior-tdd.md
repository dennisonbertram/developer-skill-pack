# Behavior-First TDD

## Core Principle

Tests describe **behavior**, not implementation. Write tests that a product manager could read and understand.

Bad: "Test the validation function"
Good: "When a user submits a form with an empty name field, an error message 'Name is required' appears below the field"

## The Loop

### 1. Define the Behavior

Write a concrete scenario:

```
Given <precondition>
When <action>
Then <observable result>
```

### 2. RED — Write the Failing Test

```bash
# Write the test
# Run it
# Confirm it FAILS for the RIGHT reason
# Commit: test(red): TASK-XXX failing tests for <behavior>
```

The failing output goes in the commit message as proof.

### 3. GREEN — Implement

```bash
# Write the minimum code to pass
# Run the test
# Confirm it PASSES
# Commit: feat|fix: TASK-XXX implement <behavior>
```

### 4. REFACTOR — Clean Up

Only after tests are green. Keep tests green throughout.

### 5. REGRESSION — Verify Broader Impact

```bash
# Run the full test suite
# Confirm no regressions
# Commit: test(regression): TASK-XXX regression coverage
```

## Audit Trail

The three commits make TDD compliance provable from `git log`:

```
i7j8k9l test(regression): TASK-042 regression coverage
e4f5g6h feat: TASK-042 implement per-IP rate limiting
a1b2c3d test(red): TASK-042 failing tests for rate-limit
```

## When Separate Commits Are Required

Separate red/green commits are required when:
- The change is non-trivial (more than a few lines)
- The change touches security, auth, or billing
- The change modifies shared state or concurrency

Separate commits may be combined when:
- The change is a one-line typo fix with an obvious test
- Document the exception in the PR

## Checklist Template

```
- Behavior: <user/operator path name>
- Test file: <path>
- RED command: <test command>
- Expected red reason: <why it should fail>
- GREEN command: <same test command>
- Red commit: <hash>
- Green commit: <hash>
- Adjacent suite: <command> — PASS
```
