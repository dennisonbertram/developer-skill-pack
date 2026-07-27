---
name: ux-walker-native
description: "Walk a UX story catalog through a running native macOS app, testing each journey for correctness, visual quality, and UX excellence. Drives the app through the accessibility tree, inspects every window screenshot visually, measures alignment/spacing/sizing defects from element frames, and logs flow friction per story. Use when asked to 'walk the native app', 'ux walk the mac app', 'test the desktop app UX', or 'run ux-walker-native'. For web apps use ux-walker instead."
version: 0.1.0
user_invocable: true
---

# UX Walker (native macOS)

The native counterpart of `/ux-walker`. Same job — walk each story in a catalog
as a real user, find what is broken or confusing, log evidence — against a
SwiftUI/AppKit app instead of a web page.

The accessibility tree is this skill's DOM. Every control carries a role, a
label, a value and a frame, so the same three questions a web walk asks — what
is on screen, can I act on it, is the layout straight — all have answers.

## What is different from the web walker

| Web | Native | Consequence for the walk |
|-----|--------|--------------------------|
| `agent-browser snapshot -i` | `nativeui snapshot` | Same idea; roles are `AXButton`, `AXTextField`, … |
| CSS selectors | Element **label** or a snapshot **ref** | Prefer labels; refs go stale on every UI change |
| `eval geometry-audit.js` | `nativeui geometry` | Same checks, computed from frames instead of DOM rects |
| JS console + network log | App stderr and `log stream` | Read the app's own log; there is no console |
| Viewport resize for mobile | `nativeui resize` | Test small-window reflow, not phone layout |
| Page navigation | Window and pane switching | A new window means re-running `snapshot` |
| Session cookies keep login | The app process keeps state | Do not relaunch mid-catalog unless a story says to |

Two web checks have **no native equivalent** — say so in the report rather than
faking them:
- **Responsive breakpoints.** A Mac window resizes continuously; there are no
  breakpoints. Replace with a narrow-window reflow check.
- **Network waterfall.** Use the app's log output instead, and only when the
  app writes one.

---

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| **App name** | required | As shown in the menu bar, e.g. `GoCode`. `nativeui apps` lists candidates |
| **Catalog** | `docs/ux-paths/catalog.md` | Story catalog from `/ux-paths-native` or `/ux-paths` |
| **Output directory** | `docs/ux-walks/{timestamp}/` | Reports, screenshots, findings |
| **Launch command** | auto-detect | How to start the app if it is not running |
| **Stories** | all | Optional filter, e.g. `STORY-003` or a topic name |

---

## Phase 0: Preflight

**Do all of this before walking anything. A failure here invalidates every
finding that follows.**

### 0.1 Build the driver and check permission

```bash
bash {SKILL_DIR}/driver/install.sh
```

This compiles `~/.claude/bin/nativeui` (only when the source changed) and prints
the permission state.

**If `accessibility_trusted` is false, stop and tell the user.** Nothing can be
driven without it. The exact ask:

> Open System Settings › Privacy & Security › Accessibility, enable the terminal
> app you run Claude Code in, then fully quit and reopen that terminal. Verify
> with `~/.claude/bin/nativeui doctor`.

Do not attempt a screenshot-only walk as a silent substitute. If the user
declines the permission, offer it explicitly as a reduced mode and label every
resulting report as visual-only.

### 0.2 Start the app

If it is not in `nativeui apps`, launch it. Prefer the project's own run
recipe over guessing — check for a `run` skill, a `Makefile` target, or the
scheme in the README. Wait until the app appears in `nativeui apps` before
continuing; a walk started against a half-launched app produces false findings.

### 0.3 Establish the baseline

```bash
nativeui focus --app {APP}
nativeui window --app {APP}
nativeui snapshot --app {APP}
nativeui screenshot {OUT}/baseline.png --app {APP}
```

Read `baseline.png` with the Read tool. If the app is showing an error, an
empty state, or a login screen, resolve that first — otherwise every story
fails for the same unrelated reason and the report is worthless.

### 0.4 Catalog check

Read the catalog. If it does not exist, tell the user to run `/ux-paths-native`
first. Do not invent stories to walk.

---

## Phase 1: Walk each story

One sub-agent per story, in parallel batches of 3–4. More than that and the
agents fight over the keyboard and pointer: **the app has one focus and one
cursor, unlike browser tabs.** This is the single most important difference
from the web walker — do not raise the batch size.

If stories must share the app, run them sequentially and say so in the report.

### Sub-agent prompt

```
You are a UX walker testing STORY-{ID}: "{TITLE}" against the native macOS app {APP}.

## Story
{FULL_STORY_TEXT — Type, Topic, Persona, Goal, Preconditions, Steps, Variations, Edge Cases}

## Driver
Use `~/.claude/bin/nativeui`. Every command takes `--app {APP}`.

  nativeui snapshot --app {APP}              list interactive elements
  nativeui snapshot --all --app {APP}        whole tree, when something is missing
  nativeui click <ref|label> --app {APP}
  nativeui type <ref|label> "text" --app {APP}
  nativeui key <spec> --app {APP}            return, cmd+n, escape, tab…
  nativeui screenshot <path> --app {APP}     just the app window
  nativeui geometry --app {APP}              layout audit
  nativeui resize <w> <h> --app {APP}
  nativeui window --app {APP}

## Skill resources
Read {SKILL_DIR}/references/action-patterns-native.md before starting.
Read {SKILL_DIR}/references/native-inspection.md for what to look for.
The UX rubric and triage rules are shared with the web walker — read
../ux-walker/references/ux-audit-rubric.md and
../ux-walker/references/triage-rubric.md.

## Instructions

1. For each step in the story:
   a. `nativeui snapshot --app {APP}` — find the target by its label
   b. Act on it (click / type / key)
   c. `nativeui screenshot {OUT}/stories/STORY-{ID}/screenshots/step-{N}.png --app {APP}`
   d. **Open that screenshot with the Read tool and actually look at it.** The
      accessibility tree cannot show misalignment, uneven cards, clipped text or
      bad spacing. A step whose screenshot you did not view is a step you did
      not audit.
   e. Verify the step's expected result
   f. Run the UX audit on the current screen

2. Waiting. There is no `networkidle`. A native app finishes work whenever it
   finishes. Poll the tree instead of sleeping blindly:
   re-run `snapshot` until the element you expect appears, up to ~30s, then
   treat it as a failure and log what the screen showed instead. Record how long
   a step took to settle — an action with no immediate feedback is itself a
   finding.

3. Geometry audit at each DISTINCT screen state (a new pane, sheet, or window —
   not every micro-step):
   ```bash
   nativeui geometry --app {APP}
   ```
   It reports: elements spilling outside the window, sibling groups with uneven
   heights, stacked siblings that do not share a left edge, uneven vertical
   gaps, and controls far taller than their peers (a wrapped label).
   Confirm every reported violation against the screenshot before logging it.
   Trust the numbers for measurement and your eyes for whether it matters.

4. Narrow-window reflow — once per story, on the story's main screen:
   ```bash
   nativeui window --app {APP}          # note the current size first
   nativeui resize 700 600 --app {APP}
   nativeui screenshot {OUT}/stories/STORY-{ID}/screenshots/narrow.png --app {APP}
   nativeui geometry --app {APP}
   nativeui resize {ORIGINAL_W} {ORIGINAL_H} --app {APP}
   ```
   Look for controls that overlap, labels that clip, panes that collapse to
   nothing, or content that becomes unreachable. **Always restore the original
   size** — the next story inherits this window.

5. UX audit at each screen state (full rubric in the shared reference):
   simplicity, progressive disclosure, layout quality, visual correctness,
   visual consistency, visual hierarchy, happy-path clarity, the "take away"
   test, typography, interaction feedback, error states.

   Plus these native-specific checks:
   - **Keyboard**: can the story be completed without the mouse? Tab through and
     see. A desktop app that cannot be driven from the keyboard is a finding.
   - **Menu bar**: are the actions on this screen also in the menus, with the
     shortcuts they advertise?
   - **Window behaviour**: does resizing keep the layout sane? Does the window
     remember its size?
   - **Accessibility labels**: any interactive element whose snapshot entry has
     no label is invisible to VoiceOver — log it as `a11y`.
   - **Platform conventions**: standard shortcuts (⌘N, ⌘W, ⌘,), a real menu bar,
     sheets rather than custom modals, system colours that follow dark mode.

6. Flow log — track while walking, write as the final section of the report:
   steps the story specified vs. steps you actually needed; every hesitation
   (control not found on the first snapshot, ambiguous label, unexpected window);
   any data re-entered that the app already knows; anything duplicated across
   screens.

7. For each finding record: severity (critical/high/medium/low/suggestion),
   category (simplicity / disclosure / layout / visual / consistency /
   hierarchy / flow / happy-path / a11y / keyboard / platform / error-handling),
   description, expected, actual, screenshot path, suggested fix.

8. If a step fails: screenshot the current state, log it with full context, try
   to recover (escape, close the sheet, return to the main window), continue the
   remaining steps, and mark the story `fail`.

9. Read the app's own log for anything the UI hid:
   ```bash
   log show --predicate 'process == "{APP}"' --last 5m --style compact | tail -50
   ```
   plus the app's stderr if it was launched from a terminal. Crashes, exceptions
   and failed requests often leave no visible trace on screen.

## Honesty rules
- Never report a finding you did not see. Every finding names a screenshot.
- A geometry number is an observation; whether it matters is your judgement —
  keep the two separate in the write-up.
- If you could not reach a screen, say the story is blocked. Do not infer what
  the screen would have looked like.
- If a step's outcome was ambiguous, say so rather than picking the tidier story.

## Output
Write to {OUT}/stories/STORY-{ID}/:
- walk-report.md — what happened at each step; for each distinct screen one
  sentence on what the screenshot shows plus the geometry result ("clean" or the
  violations); ends with the Flow Log
- findings.json — array of finding objects
```

---

## Phase 2: Triage and fix

Identical to the web walker: read
`../ux-walker/references/triage-rubric.md`.

Small, obvious, low-risk fixes get applied directly. Anything structural,
ambiguous, or design-led becomes a GitHub issue instead.

Native-specific note: a fix that touches a SwiftUI view must keep the app
building and its tests passing. Run the project's test command after each fix,
and re-walk the affected story to confirm the fix — do not mark a finding fixed
on the strength of the diff alone.

---

## Phase 3: Report

Write `{OUT}/latest-report.md` using
`../ux-walker/templates/latest-report-template.md`, adding a
**Platform** section covering:
- keyboard reachability across the walked stories
- menu bar coverage and shortcut correctness
- narrow-window reflow results
- accessibility labelling gaps (unlabelled interactive elements)

State plainly at the top which checks did not run and why — especially if
accessibility permission was unavailable and the walk was visual-only.

---

## Failure modes

| Symptom | Cause and fix |
|---|---|
| `accessibility_trusted: false` | Permission not granted. Stop and ask; do not fake a walk. |
| `no element matches "…"` | The tree changed since the snapshot. Re-run `snapshot` and target by label. |
| Element visible in the screenshot but absent from `snapshot` | It is not exposed to accessibility — that is itself an `a11y` finding. Confirm with `snapshot --all`. |
| Click lands on the wrong control | Frames are stale after an animation. Re-snapshot immediately before clicking. |
| App has no accessible window | Minimised, or on another Space. `nativeui focus` first. |
| Parallel agents interfere | Batch size too high. Drop to sequential — one keyboard, one cursor. |
| Screenshot is all desktop | Wrong window id; the app was not frontmost. `nativeui focus` then re-capture. |

---

## Reference files

| File | When |
|---|---|
| `driver/nativeui.swift` | The driver source; `driver/install.sh` builds it |
| `references/action-patterns-native.md` | Translating story steps into driver commands |
| `references/native-inspection.md` | What to look for in a native screenshot and tree |
| `../ux-walker/references/ux-audit-rubric.md` | Shared UX rubric |
| `../ux-walker/references/triage-rubric.md` | Shared fix-vs-file rules |
| `../ux-walker/references/issue-template.md` | Shared issue format |
