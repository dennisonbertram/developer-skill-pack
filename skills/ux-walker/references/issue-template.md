# GitHub Issue Template — UX Walker Findings

Used by the orchestrator to file GitHub issues via `gh issue create` for findings classified as "filed issue" by the triage rubric.

## Template

```markdown
## Context

Found by `/ux-walker` during **STORY-{STORY_ID}: "{STORY_TITLE}"**
- **Run date**: {ISO_DATE}
- **Step**: Step {STEP_NUMBER} — "{STEP_DESCRIPTION}"
- **URL at time of finding**: {CURRENT_URL}

## Finding

**ID**: {FINDING_ID}
**Severity**: {SEVERITY}
**Category**: {CATEGORY}
**Rubric Criterion**: {CRITERION} ({SCORE})

### Description
{DETAILED_DESCRIPTION}

### Expected Behavior
{EXPECTED}

### Actual Behavior
{ACTUAL}

## Evidence

### Screenshot
<!-- Attach or reference the screenshot -->
![{FINDING_ID}]({SCREENSHOT_PATH})

### Page Snapshot (if relevant)
<details>
<summary>Accessibility tree at time of finding</summary>

```
{SNAPSHOT_EXCERPT}
```

</details>

## Suggested Approach

{SUGGESTED_FIX_OR_APPROACH}

### Files Likely Involved
{FILES_LIST — bulleted list of file paths}

### Estimated Complexity
- **Files to change**: {FILE_COUNT}
- **Regression risk**: {LOW|MEDIUM|HIGH}
- **Design input needed**: {YES|NO}

## Related

- **Story**: STORY-{STORY_ID} in `docs/ux-paths/catalog.md`
- **Walk report**: `docs/ux-walker/stories/STORY-{STORY_ID}/walk-report.md`
- **Full findings**: `docs/ux-walker/stories/STORY-{STORY_ID}/findings.json`

---
🤖 Auto-filed by `/ux-walker`
```

## Usage — gh CLI Command

```bash
gh issue create \
  --title "UX: {SHORT_DESCRIPTION}" \
  --body "$(cat <<'EOF'
{FILLED_TEMPLATE}
EOF
)" \
  --label "ux-walker,auto-filed,{SEVERITY},{CATEGORY}"
```

## Field Reference

| Field | Source | Example |
|-------|--------|---------|
| `STORY_ID` | walk-plan.json | `STORY-014` |
| `STORY_TITLE` | catalog.md | `New user creates first workspace` |
| `ISO_DATE` | Current timestamp | `2026-03-20T14:30:00Z` |
| `STEP_NUMBER` | findings.json → step | `3` |
| `STEP_DESCRIPTION` | catalog.md step text | `Click "Create Workspace" button` |
| `CURRENT_URL` | agent-browser url output | `http://localhost:1420/workspaces` |
| `FINDING_ID` | findings.json → id | `F-014-003` |
| `SEVERITY` | findings.json → severity | `high` |
| `CATEGORY` | findings.json → category | `layout` |
| `CRITERION` | findings.json → criterion | `Viewport usage` |
| `SCORE` | findings.json → score | `fail` |
| `DETAILED_DESCRIPTION` | findings.json → description | Full narrative |
| `EXPECTED` | findings.json → expected | What should happen |
| `ACTUAL` | findings.json → actual | What actually happens |
| `SCREENSHOT_PATH` | findings.json → screenshot | Relative path |
| `SNAPSHOT_EXCERPT` | Saved snapshot output | Trimmed to relevant section |
| `SUGGESTED_FIX_OR_APPROACH` | findings.json → suggested_fix | Or "Needs design discussion" |
| `FILES_LIST` | findings.json → files_likely_involved | Bulleted paths |
| `FILE_COUNT` | Derived from files list | `4` |

## Notes

- Keep issue titles under 70 characters
- Title format: `UX: {verb} {what}` — e.g., "UX: simplify workspace creation form"
- If no suggested approach is obvious, write "Needs design discussion — the current implementation {description of problem}."
- Always include the screenshot — it's the most valuable part for async review
- For critical findings, add `priority:urgent` label if available in the repo
