# Triage Rubric — Quick Fix vs. Filed Issue

The orchestrator uses this rubric to classify each finding from walker sub-agents into one of two categories: **quick fix** (fix immediately with a worktree-isolated sub-agent) or **filed issue** (create a GitHub issue for later resolution).

## Decision Matrix

```
                        Low File Count (≤2)     High File Count (3+)
                      ┌──────────────────────┬──────────────────────┐
 Obvious Fix          │    QUICK FIX ✓       │    FILED ISSUE       │
 (clear solution)     │                      │                      │
                      ├──────────────────────┼──────────────────────┤
 Design Thought       │    FILED ISSUE       │    FILED ISSUE       │
 Needed               │                      │                      │
                      └──────────────────────┴──────────────────────┘
```

## Quick Fix Criteria

A finding qualifies as a **quick fix** if ALL of these are true:

1. **File scope**: Touches ≤2 source files
2. **Obvious solution**: The fix is self-evident from the finding (no design discussion needed)
3. **Low regression risk**: Change is isolated, unlikely to break other features
4. **Time estimate**: Can be completed in <15 minutes
5. **Severity**: Medium or lower (not critical/high)

### Quick Fix Examples

| Finding | Why Quick Fix |
|---------|---------------|
| Button text says "Cancle" instead of "Cancel" | 1 file, typo, zero risk |
| Sidebar has 24px padding instead of 16px | 1 CSS file, obvious fix |
| Missing label on form field | 1 file, add label attribute |
| Color doesn't match theme variable | 1 file, swap color value |
| Text overflow in card component | 1 CSS file, add overflow/truncation |
| Missing hover state on clickable element | 1 CSS file, add :hover style |
| Incorrect placeholder text | 1 file, change string |
| Z-index issue on dropdown | 1 CSS file, adjust z-index |
| Missing aria-label on icon button | 1 file, add attribute |
| Inconsistent border-radius | 1-2 files, update values |

## Filed Issue Criteria

A finding should be **filed as an issue** if ANY of these are true:

1. **File scope**: Touches 3+ source files
2. **Design thought needed**: No obvious "right" solution; requires discussion or mockup
3. **Regression risk**: Change could affect other features, routes, or components
4. **Severity**: Critical or high
5. **Workflow change**: Involves rethinking user flow or information architecture
6. **Component restructuring**: Requires splitting, merging, or significantly refactoring components
7. **State management**: Involves changing how state is managed across components
8. **New feature**: Fix requires implementing something that doesn't exist yet

### Filed Issue Examples

| Finding | Why Filed Issue |
|---------|-----------------|
| Navigation is confusing — user gets lost after 3 clicks | Workflow redesign needed |
| Form has 15 fields visible at once (should be progressive) | Multi-file restructuring |
| Error messages show raw API errors | Needs error handling strategy |
| No loading states throughout the app | Touches many components |
| Modal workflow should be a multi-step wizard | Major component restructuring |
| Page doesn't work on mobile viewport | Responsive redesign across files |
| Empty states are blank/broken | Needs design + implementation across views |
| No keyboard navigation support | Cross-cutting concern, many files |
| Auth flow drops user at wrong page | Route logic + state management |
| Data table pagination is broken at scale | Component + API changes |

## Severity Override Rules

Regardless of other criteria:
- **Critical** findings → Always filed issue (even if 1 file, needs careful attention)
- **Suggestion** findings → Never quick-fixed (they're ideas, not bugs); log in report only

## Quick Fix Limits

Per run, the orchestrator enforces these limits:
- **Max 3 fix agents running in parallel** (to avoid merge conflicts)
- **Max 10 quick fixes per run** (if more, the remaining become filed issues — suggests systemic problem)
- **No two fix agents touch the same file** (if conflict detected, queue the second fix)

## Filing Decision Checklist

For each finding, the orchestrator answers:

```
1. [ ] Severity ≤ medium?               (if no → FILE ISSUE)
2. [ ] Touches ≤2 files?                (if no → FILE ISSUE)
3. [ ] Solution is obvious?             (if no → FILE ISSUE)
4. [ ] Low regression risk?             (if no → FILE ISSUE)
5. [ ] Under 10 quick fixes this run?   (if no → FILE ISSUE)
6. [ ] No file conflict with active fix? (if no → QUEUE or FILE ISSUE)
→ All yes? QUICK FIX
→ Any no?  FILE ISSUE
```

## GitHub Issue Labeling

When filing issues, apply these labels:

| Label | When |
|-------|------|
| `ux-walker` | Always (identifies source) |
| `auto-filed` | Always (distinguishes from manual issues) |
| `critical` / `high` / `medium` / `low` | Match severity |
| `functional` / `visual` / `ux` / `a11y` | Match category |
| `needs-design` | When design thought is needed |
| `quick-win` | Filed but could be quick fix in next run (e.g., hit limit) |
