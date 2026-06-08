---
name: ux-walker
description: Walk UX story catalog through a real browser, testing each journey for correctness, visual quality, and UX excellence. Auto-fixes small issues, files GitHub issues for larger ones.
version: 1.0.0
user_invocable: true
---

# UX Walker

Walk the UX story catalog through a real browser, testing each user journey for functional correctness, visual quality, and UX excellence. Automatically fixes small issues on the spot and files GitHub issues for larger ones.

## Trigger Phrases

"walk the stories", "test the ux paths", "ux walker", "verify user journeys", "run ux tests", "browser test the stories", "qa the user flows"

## Usage

```
/ux-walker [url] [--full] [--focus topic] [--session name]
```

| Parameter | Default | Notes |
|-----------|---------|-------|
| **url** | Auto-detect from dev server or `package.json` | Target URL to walk |
| **--full** | Off | Force re-walk of all stories, ignoring run history |
| **--focus topic** | All topics | Only walk stories matching this topic |
| **--session name** | `ux-walker-{domain}` | Reuse an existing agent-browser session (preserves login state) |

If the user says something like "walk the stories" with no arguments, auto-detect the URL and start immediately. Do not ask clarifying questions unless authentication is mentioned but credentials are missing.

Always use `agent-browser` directly -- never `npx agent-browser`. The direct binary uses the fast Rust client. `npx` routes through Node.js and is significantly slower.

## Overview

```
User invokes /ux-walker [url] [flags]
└── Top-level agent (you — orchestrator only)
    ├── Phase 0: Preflight (orchestrator directly)
    │   └── URL check, catalog check, output dirs, run history, session
    ├── Phase 1: Story Planning (1 Explore agent)
    │   └── Parse catalog → cross-ref run history → walk-plan.json
    ├── Phase 2: Walk Loop (sequential walkers + parallel fixers)
    │   ├── Step 2a: Walker agent per story (general-purpose)
    │   │   └── Browser walk + UX audit → findings.json
    │   ├── Step 2b: Triage findings (orchestrator)
    │   ├── Step 2c: Fix agents (parallel, worktree-isolated, up to 3)
    │   │   └── Minimal fix → commit → report
    │   └── Step 2d: File GitHub issues (orchestrator)
    ├── Phase 3: Fix Merge & Verification
    │   └── Merge branches → rebuild → re-walk fixed stories → update history
    └── Phase 4: Report (1 general-purpose agent)
        └── latest-report.md
```

## Output Directory

```
docs/ux-walker/
├── run-history.json          # Persistent state across runs
├── latest-report.md          # Human-readable report from last run
├── walk-plan.json            # Plan for current/last run
├── issues-filed.md           # Log of all GitHub issues created
├── stories/
│   └── STORY-{NNN}/
│       ├── walk-report.md    # Narrative of what happened at each step
│       ├── findings.json     # Array of finding objects
│       ├── screenshots/      # Step screenshots + finding screenshots
│       ├── snapshots/        # DOM snapshots at key points
│       └── videos/           # Video reproductions of interactive issues
├── fixes/
│   └── {FINDING_ID}.md       # Fix report for each quick-fix applied
└── walk-plan.json            # Current walk plan
```

---

## Phase 0: Preflight

The orchestrator (top-level agent) performs these checks directly. Do not delegate preflight to a sub-agent.

### 0.1 URL Check

```bash
# If URL provided, check it responds
curl -s -o /dev/null -w "%{http_code}" {URL}
```

If not 200 (or no URL provided), detect the dev server:

```bash
# Check what's already running
lsof -i :{port} 2>/dev/null

# If nothing running, detect from package.json and start
# Read package.json scripts.dev or scripts.start to find the port
# Use a different port if the default is occupied
```

### 0.1.5 Deploy Check

Check if the app has version fingerprinting installed:

```bash
# Try the endpoint first (faster than browser)
curl -s "{URL}/__version" 2>/dev/null || curl -s "{URL}/version.json" 2>/dev/null
```

If the endpoint returns version JSON, compare `git_sha` against `git rev-parse --short HEAD`:

- **Match**: Log `Deploy check: SHA {sha} verified ✓` and continue.
- **Mismatch**: Warn `Deploy check: deployed SHA {deployed} ≠ HEAD {head} — testing may reflect an older build` but **continue** (the user may be testing an older deploy intentionally).
- **No endpoint / no meta tag**: Note `No version fingerprint found — run /deploy-check --install to add one` and continue. This is advisory, not blocking.

If the endpoint is missing, fall back to the meta tag via agent-browser:

```bash
agent-browser js "document.querySelector('meta[name=\"build-version\"]')?.content"
```

### 0.2 Catalog Check

Verify `docs/ux-paths/catalog.md` exists. If it does not:

```
The UX story catalog does not exist yet. Run /ux-paths first to generate
the story catalog, then re-run /ux-walker.
```

Stop execution. Do not proceed without a catalog.

### 0.3 Output Directories

```bash
mkdir -p docs/ux-walker/stories docs/ux-walker/fixes
```

### 0.4 Run History

Load `docs/ux-walker/run-history.json` or initialize it:

```json
{
  "runs": [],
  "stories": {}
}
```

Each story entry in `stories` tracks:

```json
{
  "STORY-001": {
    "last_walked": "2026-03-20T14:30:00Z",
    "status": "pass",
    "findings_count": 0,
    "source_files_hash": "abc123",
    "fixes_merged_since": false
  }
}
```

### 0.5 Session

If `--session` provided, verify the agent-browser session exists:

```bash
agent-browser --session {SESSION} snapshot
```

If it fails, create a new session. Otherwise, reuse it.

If no `--session` flag, create a session named `ux-walker-{domain}`:

```bash
agent-browser --session ux-walker-{domain} open {URL}
agent-browser --session ux-walker-{domain} wait --load networkidle
```

---

## Phase 1: Story Planning

Spawn **1 Explore sub-agent** (read-only, no worktree needed).

### Planning Agent Task

Parse `docs/ux-paths/catalog.md`, cross-reference with `docs/ux-walker/run-history.json`, and determine the walk order.

### Planning Logic

- If `--full`: mark all stories as `walk`
- If `--focus topic`: filter to stories matching that topic only
- Otherwise apply this priority system:
  - Stories never walked --> `walk`
  - Stories with `pass` status and no source file changes since last run --> `skip`
  - Stories with `pass` status but source files changed --> `re-verify`
  - Stories with `fail` status and fixes merged since --> `re-verify`
  - Stories with `fail` status and no fixes --> `walk` (retry)

### Planning Output

Write `docs/ux-walker/walk-plan.json`:

```json
{
  "timestamp": "2026-03-20T14:30:00Z",
  "total_stories": 42,
  "walking": 15,
  "skipping": 20,
  "re_verifying": 7,
  "order": [
    {
      "id": "STORY-001",
      "action": "walk",
      "reason": "never walked",
      "dependencies": []
    },
    {
      "id": "STORY-005",
      "action": "re-verify",
      "reason": "source changed",
      "dependencies": ["STORY-001"]
    }
  ]
}
```

**Return to orchestrator**: Path to `walk-plan.json` + summary sentence (e.g., "15 stories to walk, 7 to re-verify, 20 skipped").

---

## Phase 2: Walk Loop

Process stories **sequentially** (browser state is shared across stories). Fix agents run in **parallel** (worktree-isolated).

For each story in `walk-plan.order`:

### Step 2a: Spawn Walker Sub-agent

Spawn **1 general-purpose sub-agent** per story.

**allowed-tools**: `Bash(agent-browser:*)`, `Write`, `Read`, `Glob`, `Grep`

**Prompt template** (fill in variables from the walk plan and catalog):

```
You are a UX walker testing STORY-{ID}: "{TITLE}"

## Story
{FULL_STORY_TEXT from catalog — include Type, Topic, Persona, Goal, Preconditions, Steps, Variations, Edge Cases}

## Session
Use agent-browser session: {SESSION_NAME}

## Instructions

1. For each step in the story:
   a. Take a snapshot: `agent-browser --session {SESSION} snapshot`
   b. Read the snapshot to find the target element (by text, role, or selector)
   c. Execute the action: click, type, navigate, etc.
   d. Take a screenshot: `agent-browser --session {SESSION} screenshot {OUTPUT_DIR}/stories/STORY-{ID}/screenshots/step-{N}.png`
   e. Verify the expected result from the story step
   f. Run the UX audit checklist (see below) on the current page state

2. UX Audit at each page state (reference: references/ux-audit-rubric.md):
   - Simplicity: Is the user overwhelmed? Too many choices visible?
   - Progressive disclosure: Information appears when needed, not before
   - Layout quality: Fills viewport, no excess whitespace, scroll only when needed
   - Visual correctness: No overflow, broken divs, theme consistency, alignment
   - Happy path clarity: Can a naive user accomplish their goal?
   - "Take away" test: What could be removed without losing function?
   - Responsiveness: Does the layout work at the current viewport?
   - Typography: Readable font sizes, proper hierarchy, no orphan lines
   - Interaction feedback: Do clicks, hovers, transitions feel responsive?
   - Error states: Are errors shown clearly and helpfully?

3. For each finding:
   - Severity: critical / high / medium / low / suggestion
   - Category: simplicity / disclosure / layout / visual / happy-path / a11y / error-handling
   - Description: What is wrong
   - Expected: What should happen
   - Actual: What actually happens
   - Screenshot path: Reference to the evidence
   - Suggested fix: If obvious, describe the fix

4. If a step fails (element not found, unexpected state):
   - Screenshot the current state
   - Log the failure with full context
   - Attempt to recover (go back, refresh) and continue remaining steps
   - Mark story as `fail`

5. For interactive/behavioral issues, record video:
   ```bash
   agent-browser --session {SESSION} record start {OUTPUT_DIR}/stories/STORY-{ID}/videos/finding-{N}.webm
   # Reproduce at human pace with sleep 1-2 between actions
   agent-browser --session {SESSION} record stop
   ```

6. For static/visual issues, a single annotated screenshot is sufficient:
   ```bash
   agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/stories/STORY-{ID}/screenshots/finding-{N}.png
   ```

## Output
Write to {OUTPUT_DIR}/stories/STORY-{ID}/:
- walk-report.md (narrative of what happened at each step)
- findings.json (array of finding objects — see schema below)
- screenshots/ (step screenshots + finding screenshots)
- videos/ (video reproductions for interactive issues)

## findings.json Schema
[
  {
    "id": "F-{STORY_ID}-{SEQ}",
    "story_id": "STORY-{ID}",
    "severity": "critical|high|medium|low|suggestion",
    "category": "simplicity|disclosure|layout|visual|happy-path|a11y|error-handling",
    "criterion": "Which specific check failed",
    "score": "warn|fail",
    "description": "...",
    "expected": "...",
    "actual": "...",
    "screenshot": "screenshots/finding-{N}.png",
    "suggested_fix": "... or null",
    "files_likely_involved": ["src/components/Foo.tsx"]
  }
]

Return: path to walk-report.md + 1-2 sentence summary + count of findings by severity
```

### Step 2b: Triage Findings

After each walker sub-agent completes, the orchestrator reads `findings.json` and triages each finding into one of two buckets.

**Quick fix** (fix on the spot) -- ALL of these must be true:

- Touches 2 or fewer files
- Obvious fix (typo, CSS tweak, missing label, wrong color, spacing, padding)
- Low regression risk
- Severity: medium or lower

**Filed issue** (create GitHub issue) -- ANY of these is true:

- Touches 3+ files
- Requires design thought or rethinking a workflow
- Could break other features
- Severity: critical or high
- Involves component restructuring or state changes

**Severity overrides** (these take precedence over the rules above):

- **Critical findings** are always filed as GitHub issues, even if they touch only 1 file and appear easy to fix.
- **Suggestion findings** are never quick-fixed or filed as issues. They are logged in the report only.

**Quick fix limit**: A maximum of 10 quick fixes may be applied per run. Any findings beyond the 10-fix cap are filed as GitHub issues instead.

Reference: `references/triage-rubric.md` for the full triage decision tree.

### Step 2c: Spawn Fix Sub-agents (parallel, up to 3)

For each quick-fix finding, spawn a **general-purpose sub-agent** with `isolation: "worktree"`.

No two fix agents should touch the same file. If two findings involve the same file, batch them into a single fix agent.

**Prompt template**:

```
Fix UX finding {FINDING_ID} from STORY-{STORY_ID}.

## Finding
{FINDING_DESCRIPTION}
Expected: {EXPECTED}
Actual: {ACTUAL}
Screenshot: {SCREENSHOT_PATH}
Suggested fix: {SUGGESTED_FIX}
Files likely involved: {FILES_LIST}

## Instructions
1. Read the relevant source files
2. Make the minimal fix — do not refactor, do not "improve" adjacent code
3. Verify the fix compiles/builds: `npm run build` or `cargo build`
4. Commit with specific files (never `git add -A`):
   ```bash
   git add {specific files}
   git commit -m "fix(ux): {FINDING_ID} — {short description}"
   ```

## Output
Write fix report to docs/ux-walker/fixes/{FINDING_ID}.md:
- What was wrong
- What was changed (file paths + diff summary)
- Build verification result

Return: worktree branch name + 1-2 sentence summary
```

### Step 2d: File GitHub Issues

For each filed-issue finding, the orchestrator creates a GitHub issue:

```bash
gh issue create \
  --title "UX: {short description}" \
  --body "$(cat <<'EOF'
## Context
Found by ux-walker during STORY-{STORY_ID}: "{STORY_TITLE}"

## Finding
**Severity**: {severity}
**Category**: {category}

{description}

**Expected**: {expected}
**Actual**: {actual}

## Screenshot
![screenshot](docs/ux-walker/stories/STORY-{ID}/screenshots/{screenshot})

## Suggested Approach
{suggested_fix or "Needs design discussion"}

---
Auto-filed by `/ux-walker`
EOF
)" \
  --label "ux-walker,auto-filed,{severity}"
```

Log each issue to `docs/ux-walker/issues-filed.md`:

```markdown
| Issue | Story | Severity | Title | URL |
|-------|-------|----------|-------|-----|
| #123  | STORY-005 | high | Button overflow on mobile | https://github.com/.../issues/123 |
```

---

## Phase 3: Fix Merge & Verification

After all stories in the walk loop are completed and fix agents have finished:

### 3.1 Collect Worktree Branches

Gather branch names from all completed fix sub-agents.

### 3.2 Merge Sequentially

Merge each fix branch one at a time (to catch conflicts early):

```bash
git checkout main
git merge --no-ff {branch} -m "fix(ux-walker): {FINDING_ID} — {description}"
```

If a merge conflict occurs:
- **Stop immediately.** Do not force-resolve.
- Report the conflict to the user with full details (which files, which branches).
- Do not proceed with remaining merges until the user resolves it.

After each successful merge, clean up:

```bash
git worktree remove {worktree-path} 2>/dev/null
git branch -d {branch} 2>/dev/null
```

### 3.3 Rebuild

```bash
npm run build
# or the detected build command for this project
```

If the build fails, report the failure to the user and stop. Do not attempt to auto-fix build failures from merges.

### 3.4 Re-walk Fixed Stories

Spawn walker sub-agents for stories that had fixes applied. Verify the findings are resolved.

Use the same walker prompt from Step 2a, but scope the walk to only the steps that had findings. If all findings are resolved, mark the story as `pass`. If any persist, mark as `fail` and note the unresolved findings.

### 3.5 Update Run History

Update `docs/ux-walker/run-history.json`:

```json
{
  "runs": [
    {
      "timestamp": "2026-03-20T14:30:00Z",
      "url": "http://localhost:3000",
      "stories_walked": 15,
      "stories_skipped": 20,
      "stories_re_verified": 7,
      "findings_total": 23,
      "quick_fixes_applied": 8,
      "issues_filed": 5,
      "stories_passed": 12,
      "stories_failed": 3
    }
  ],
  "stories": {
    "STORY-001": {
      "last_walked": "2026-03-20T14:30:00Z",
      "status": "pass",
      "findings_count": 0,
      "source_files_hash": "abc123",
      "fixes_merged_since": false
    }
  }
}
```

---

## Phase 4: Report

Spawn **1 general-purpose sub-agent** to generate `docs/ux-walker/latest-report.md`.

**Template reference**: `templates/latest-report-template.md`

### Report Content

The report must include:

1. **Run Metadata** -- Date, target URL, session name, stories walked/skipped/re-verified
2. **Findings Summary Table** -- Breakdown by severity (critical/high/medium/low/suggestion) and category (simplicity/disclosure/layout/visual/happy-path/a11y/error-handling)
3. **Quick Fixes Applied** -- Table of each fix with before/after description, files changed, and FINDING_ID
4. **Issues Filed** -- Table with issue number, title, severity, story, and GitHub URL
5. **UX Audit Summary** -- Common patterns observed, systemic issues (e.g., "inconsistent spacing throughout sidebar"), overall UX quality assessment
6. **Top 5 Recommendations** -- Prioritized list of the most impactful improvements for the next iteration
7. **Stories Still Failing** -- List of stories that did not pass, with reasons and unresolved finding references
8. **Run Statistics** -- Total time, stories per minute, fix success rate

**Return to orchestrator**: Path to `latest-report.md` + summary.

---

## Execution Checklist

The orchestrator follows this checklist, updating it as phases complete:

```
[ ] Phase 0: Preflight passed
    [ ] URL responds (or dev server started)
    [ ] Catalog exists at docs/ux-paths/catalog.md
    [ ] Output directories created
    [ ] Run history loaded/initialized
    [ ] Browser session established
[ ] Phase 1: Walk plan created ({N} stories to walk, {M} to re-verify, {K} skipped)
[ ] Phase 2: Stories walked
    [ ] Walker agents completed ({passed}/{total})
    [ ] Findings triaged ({quick_fixes} fixes, {issues} issues to file)
    [ ] Fix agents completed ({merged}/{total} fixes)
    [ ] GitHub issues filed ({count})
[ ] Phase 3: Fixes merged and verified
    [ ] All branches merged without conflicts
    [ ] Build passes
    [ ] Re-walk confirms fixes resolved
    [ ] Run history updated
[ ] Phase 4: Report generated at docs/ux-walker/latest-report.md
[ ] Summary delivered to user
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| agent-browser fails to connect | Retry once. If still fails, ask user to verify Chrome is running with the agent-browser extension. |
| Story step fails (element not found, unexpected state) | Screenshot current state. Attempt recovery (go back, refresh). Continue remaining steps. Mark story as `fail`. |
| Fix agent fails (build broken, can't find file) | Log the error. Skip the fix. File a GitHub issue for the finding instead. |
| Merge conflict | Stop all merges. Report the conflict to the user. Do not force-resolve. |
| Build fails after merge | Report the failure to the user. Do not attempt auto-fix of merge-induced build failures. |
| Catalog not found | Stop execution. Instruct user to run `/ux-paths` first. |
| No stories to walk (all skipped) | Report that all stories are passing and no changes detected. Suggest `--full` to force a complete re-walk. |

---

## Commit Discipline

| When | Format |
|------|--------|
| Fix agent commits (in worktree) | `fix(ux): {FINDING_ID} — {short description}` |
| Merge fix to main | `fix(ux-walker): {FINDING_ID} — {description}` |
| Wave commit (if batching) | `fix(ux-walker): wave {N} — {description}` |

Never commit directly to `main` from a fix agent. Never use `git add -A`. Always stage specific files.

---

## Branch Naming

Fix agent branches follow this pattern:

```
ux-walker/{FINDING_ID}-{slug}
```

Example: `ux-walker/F-005-003-sidebar-overflow`

---

## Guidance

- **Stories are the script, not the limit.** If you notice something wrong that is not in the story steps, log it as a finding anyway. Stories guide the walk; they do not restrict what you can observe.
- **Sequential walking, parallel fixing.** Stories must be walked one at a time because they share browser state. But fixes are independent and run in parallel with worktree isolation.
- **Minimal fixes only.** Fix agents should make the smallest change that resolves the finding. No refactoring, no "while I'm here" improvements. Keep the diff small and reviewable.
- **Evidence for every finding.** Every finding needs at least a screenshot. Interactive issues need video. No exceptions.
- **Incremental output.** Walker agents write findings as they go, not at the end. If a walker crashes mid-story, partial findings are preserved.
- **Do not read source code during walks.** Walker agents test as a user, not as a developer. They observe the browser. Fix agents read source code -- walkers do not. (Exception: walkers may read `references/ux-audit-rubric.md` for audit criteria.)
- **Pace for humans.** During video recording, use `sleep 1` between actions and `sleep 2` before the final result. Videos should be watchable at 1x speed.
- **Type like a human.** When filling form fields during video recording, use `type` instead of `fill` for character-by-character input. Use `fill` outside of video recording when speed matters.
- **Be efficient with commands.** Batch independent `agent-browser` commands in a single shell call (e.g., `agent-browser ... screenshot ... && agent-browser ... console`). Use `agent-browser --session {SESSION} scroll down 300` for scrolling.
- **Check the console.** Many issues are invisible in the UI but show up as JS errors or failed network requests. Check periodically with `agent-browser --session {SESSION} errors` and `agent-browser --session {SESSION} console`.
- **Never delete output files.** Do not `rm` screenshots, videos, or reports mid-session. Work forward, not backward.

---

## References

| Reference | When to Read |
|-----------|--------------|
| [references/ux-audit-rubric.md](references/ux-audit-rubric.md) | Before walking -- calibrate what to look for in the UX audit |
| [references/triage-rubric.md](references/triage-rubric.md) | During triage -- decision tree for quick-fix vs. file-issue |
| [references/action-patterns.md](references/action-patterns.md) | During walks -- translate story steps to agent-browser commands |
| [references/issue-template.md](references/issue-template.md) | When filing issues -- detailed GitHub issue template with all fields |

## Templates

| Template | Purpose |
|----------|---------|
| [templates/latest-report-template.md](templates/latest-report-template.md) | Copy into output directory and fill in for the final report |
