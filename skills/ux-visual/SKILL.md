---
name: ux-visual
description: "Exhaustive visual and hands-on design critique of every component, component group, page and layout — judged against excellent UI/UX norms with zero tolerance. Screenshots and measures each surface, interacts with it like a human, recursively evaluates logic, standards, usability, clarity, density and whitespace, then fans out solution designers, judges competing proposals, documents and defends the winner, implements it, and verifies it with tests and fresh screenshots. Use when asked to 'review the visual design', 'run ux-visual', 'audit the layout', 'make it look excellent', 'design critique', 'check density/whitespace', or 'why does this page scroll'."
version: 0.1.0
user_invocable: true
---

# UX Visual — Recursive Visual Design Audit, Solve, Implement

`/ux-paths` maps journeys, `/ux-walker` checks that they work, `/ux-flow` asks
whether they should exist in that shape. `/ux-visual` asks: **does every surface
look and behave like the work of a world-class product team?** It examines the
interface from the smallest component up to the whole layout, by looking at it
and by using it, and accepts nothing less than excellent. Then it fixes what it
finds — through competing proposals, a judged winner, a defended decision, an
implementation, and proof.

The stance: a demanding senior product designer and a first-time user at once.
No excuses ("it's an edge case", "it's the framework's default", "it's only on
small screens", "nobody will notice"). If a human would hesitate, squint,
scroll for what should be one screen, hunt for a control, or misread a label,
it is a finding.

## Trigger Phrases

"run ux-visual", "visual design audit", "review the layout", "design critique",
"make this look excellent", "check density and whitespace", "this page
scrolls/it should be one page", "audit every component"

## Usage

```
/ux-visual [url] [--scope page|route-glob|component] [--viewports list] [--no-implement] [--max-fixes N]
```

| Parameter | Default | Notes |
|-----------|---------|-------|
| **url** | Auto-detect dev server (curl check; `package.json` dev script) | Target app |
| **--scope** | Whole app | One route (`/projects/*/settings`), a page name, or a component |
| **--viewports** | `1440x900,1920x1080,768x1024,375x812` | Every surface is judged at each |
| **--no-implement** | Off | Stop after the decision documents (Phase 5) |
| **--max-fixes N** | 12 | Max problem clusters carried through solve → implement per run |
| **--session name** | `ux-visual-{domain}` | agent-browser session to reuse (keeps login) |
| **--no-second-opinion** | Off | Skip the external MUSE Wonder / Gemini Argon reviews (saves about 15 cents per screenshot set) |

Always use `agent-browser` directly — never `npx agent-browser`. When the user
asks to use their own Chrome, use the `mcp__claude-in-chrome__*` tools for the
manual-interaction pass instead (load them in one ToolSearch call).

## Overview

```
/ux-visual
└── Orchestrator (you — plan, dispatch, judge, integrate; never the implementer)
    ├── Phase 0: Preflight — URL, auth, design system, inventory inputs, output dirs
    ├── Phase 1: Inventory (1 agent) — pages × layouts × component groups × components
    ├── Phase 2: Inspect (fan-out, one agent per page) — recursive audit, bottom-up then top-down
    │   └── per page: screenshots @ every viewport + layout-audit.js + geometry-audit.js
    │       + manual interaction pass + component → group → page → layout critique
    │       + second opinions: Meta MUSE Wonder + Google Gemini 4 Argon (max reasoning)
    ├── Phase 3: Consolidate (1 agent) — dedupe, cluster by root cause, rank → problems.md
    ├── Phase 4: Propose (fan-out, 3 designers per cluster, distinct strategies)
    ├── Phase 5: Judge (panel per cluster + MUSE Wonder + Gemini Argon) — score, pick, defend → decisions/
    ├── Phase 6: Implement (fan-out, worktree per cluster) — design system first, tests first
    ├── Phase 7: Verify (independent agent per cluster) — re-inspect, measure, regressions
    └── Phase 8: Report — before/after, what changed, what remains
```

## Output Directory

```
docs/ux-visual/
├── inventory.md                 # pages, layouts, groups, components (+ where each renders)
├── pages/{page-slug}/
│   ├── shots/{viewport}-{state}.png
│   ├── audit.json               # layout-audit.js + geometry-audit.js output per viewport/state
│   ├── second-opinion.json      # MUSE Wonder + Gemini Argon critiques of the page's screenshots
│   └── findings.md              # recursive critique for this page (own + external, attributed)
├── problems.md                  # consolidated, clustered, ranked problem register
├── proposals/{cluster-id}/{A,B,C}.md
├── decisions/{cluster-id}.md    # chosen solution, scores, why it beats the others
├── verification/{cluster-id}.md # after screenshots, measurements, test output
├── run-history.json             # clusters fixed, deferred, rejected; dates; commits
└── report.md                    # final before/after summary
```

---

## Phase 0: Preflight (orchestrator)

1. **App URL**: curl the URL; if down, detect and start the dev server the way
   `/ux-walker` does, and record the PID so you only stop what you started.
2. **Auth**: find how the app signs in (test users, seeded fixtures, Clerk/Auth
   testing helpers in the e2e folder). Sign in once in the agent-browser session.
   Multi-user apps: prepare 2–3 sessions so multiplayer states can be shown.
3. **Design system**: locate tokens, component library, catalog, and enforcement
   (e.g. `design-system/`, `components/ui`, an audit script). Every fix must land
   in the design system first; record the rules in `inventory.md`.
4. **Inputs**: reuse `docs/ux-paths/catalog.md` (journeys → states to visit),
   `docs/ux-flow/report.md` (already-decided simplifications — don't re-litigate),
   and `docs/ux-visual/run-history.json` (skip clusters fixed since last run
   unless their surfaces changed).
5. `mkdir -p docs/ux-visual/{pages,proposals,decisions,verification}`

## Phase 1: Inventory (1 Explore/general-purpose agent)

Produce `docs/ux-visual/inventory.md`:
- **Pages** (every route) with how to reach each **state**: empty, loading,
  populated, long-content, error, permission-denied, each role (owner / member /
  viewer / signed-out), multiplayer (2+ users present), and transient UI
  (dialogs, menus, toasts, hover/focus toolbars, approvals, banners).
- **Layouts** (shells, frames, split views) and which pages use each.
- **Component groups** (toolbars, cards, forms, panels, headers, lists).
- **Components** (every design-system component) and where each renders.
This is the work list for Phase 2; nothing gets audited that isn't listed, and
the consolidator checks coverage against it.

## Phase 2: Inspect (fan out — one general-purpose agent per page; ≤ 10 parallel)

Each inspector gets its page, the states to reach, the viewports, its own
agent-browser session (`--session ux-visual-{page-slug}`, signed in), and reads
`{SKILL_DIR}/references/visual-heuristics.md` first.

**Inspector prompt (template):**

```
You are a ruthless senior product designer and a first-time user at once,
auditing {PAGE} of {APP}. Accept nothing less than excellent; no excuses.

Read {SKILL_DIR}/references/visual-heuristics.md first.
Session: agent-browser --session {SESSION}. Viewports: {VIEWPORTS}.
States to reach: {STATES} (how: {HOW}).

For EVERY viewport × state:
1. Capture: set the viewport, reach the state, wait for a known element of
   that state to render plus fonts and animations (realtime apps never reach
   network idle; cap waits at ~15s), take a full-page AND a viewport screenshot into
   docs/ux-visual/pages/{slug}/shots/{viewport}-{state}.png (+ -full.png).
   Open every screenshot with the Read tool and look at it properly.
2. Measure: run {SKILL_DIR}/references/layout-audit.js and
   {SKILL_DIR}/../ux-walker/references/geometry-audit.js via
   `agent-browser --session {SESSION} eval "$(cat <file>)"`; append both JSON
   results to docs/ux-visual/pages/{slug}/audit.json keyed by viewport/state.
3. Interact manually like a human: hover every control, tab through the page
   (focus order, visible focus), click every action (in a safe state — never
   destructive against real data; use seeded/test data), open every menu and
   dialog, type into every field (long text, emoji, paste), resize between
   breakpoints, scroll every scroll container, trigger errors (offline, invalid
   input), and in multiplayer apps do it while a second session acts.
   Note every hesitation, surprise, layout shift, dead end, and slow feedback.
4. Critique RECURSIVELY, bottom-up then top-down:
   a. Each component: purpose obvious? correct pattern for the job (industry
      norm)? states complete (hover/focus/active/disabled/loading/empty/error)?
      label clear and consistent? size/touch target adequate? alignment to its
      neighbors and the grid?
   b. Each group: belongs together (Gestalt proximity/similarity)? one primary
      action? order matches the task? spacing consistent and on the scale?
      redundant with another group?
   c. The page: one clear purpose and focal point? does it fit the viewport when
      it should be one screen (app-like surfaces must not page-scroll; only
      inner panels scroll)? density appropriate for the task (dense for tools,
      airy for marketing) — measured, not guessed? whitespace intentional
      (no dead bands, no cramped clusters)? visual hierarchy matches importance?
      anything stated twice? anything a user must hunt for?
   d. The layout: consistent across pages that share it? regions on one grid
      with aligned edges? predictable navigation and back paths? behaves well
      at every breakpoint (reflow, not overflow)?
   Judge each against the heuristics file's norms and name the norm violated.
5. Second opinions (unless --no-second-opinion): write a short brief
   (app purpose, page, persona, states shown, viewports) to
   docs/ux-visual/pages/{slug}/brief.md, then run
   `node {SKILL_DIR}/references/second-opinion.mjs --mode inspect --brief <brief>
   --out docs/ux-visual/pages/{slug}/second-opinion.json <up to 8 screenshots>`
   (needs OPENROUTER_API_KEY; models meta/muse-wonder and google/gemini-4-argon at
   maximum reasoning effort; they see images, not the DOM). Read both results.
   Fold their findings into yours with attribution ([own], [muse], [argon]):
   verify each external claim against the screenshot or the live page before
   accepting it (they cannot interact and can misread); keep disagreements and
   say who is right and why. A problem found independently by 2–3 reviewers
   gets a confidence boost.
6. Severity: P0 blocks or misleads (can't complete, wrong result, unreadable,
   critical control off-screen); P1 a human would stumble (scroll for what
   should be one page, buried primary action, confusing label, layout jump,
   inconsistent pattern); P2 visibly below excellent (uneven spacing, density
   off, weak hierarchy, misalignment, redundant info); P3 polish.

Honesty: every finding cites a screenshot path and/or an audit.json metric and
the norm it violates. Mark "measured" vs "observed" vs "suspected". If a
surface is excellent, say so — praise is data. Do not edit code.

Write docs/ux-visual/pages/{slug}/findings.md:
- Per viewport×state: one-paragraph verdict + screenshot refs
- Findings table: id | level (component/group/page/layout) | element | problem |
  norm violated | evidence | severity | found by (own/muse/argon) | verified
- "Excellent as is" list
Return: counts by severity and level, and the 5 worst findings in one line each.
```

## Phase 3: Consolidate (1 general-purpose agent)

Read all `findings.md` and `audit.json`. Produce `docs/ux-visual/problems.md`:
1. **Deduplicate** the same problem seen on several pages/viewports and by
   several reviewers (keep the "found by" list; agreement raises rank).
2. **Cluster by root cause** — e.g. "room grid doesn't constrain height" causes
   five findings; "no spacing scale on cards" causes twelve. One cluster = one
   design decision. Prefer fixing a shared component/layout/token over patching
   pages.
3. **Rank** clusters: severity × reach (how many surfaces/journeys) × centrality
   (core journey vs rare settings page) ÷ effort. P0 first regardless.
4. **Coverage check** against `inventory.md` — list any page/state not audited.
5. For each cluster: id, title, root cause, every finding id it covers, affected
   surfaces, evidence, severity, reach, and the acceptance criteria a fix must
   meet (measurable where possible: "no page scroll at 1440x900 on /room",
   "all card paddings use --space-4", "primary action in viewport").
Carry the top `--max-fixes` clusters forward; the rest are listed as deferred.

## Phase 4: Propose (fan out — 3 designer agents per cluster, in parallel)

Each designer gets the cluster (findings, evidence, acceptance criteria), the
design-system rules, `{SKILL_DIR}/references/visual-heuristics.md`, and a
**distinct strategy** so proposals genuinely differ:
- **A — Minimal**: the smallest change to existing components/tokens that meets
  the criteria.
- **B — Restructure**: rethink the layout/grouping/pattern (e.g. tabs instead of
  stacked panels, a docked strip instead of inline cards).
- **C — Convention**: what the best-in-class products in this category do
  (name them and the pattern; do not copy brand assets).

Each writes `docs/ux-visual/proposals/{cluster}/{A|B|C}.md`: the change, a
before/after description, a quick visual (ASCII wireframe or a static HTML
mock using the design system in a scratch path, screenshotted), the exact
components/tokens/files touched, effort, risks, and how it meets each
acceptance criterion. Proposals must stay inside the design system (new
patterns are added to it, never ad hoc).

## Phase 5: Judge (panel per cluster)

Spawn 3 judges per cluster with different lenses — **usability** (first-time
user, task speed, error-proneness), **visual craft** (hierarchy, rhythm,
density, consistency with the system), **engineering** (risk, scope,
reuse, testability). Each scores every proposal 1–5 on: meets acceptance
criteria, simplicity, consistency with the rest of the app, usability, visual
quality, effort/risk; and may graft a better idea from a runner-up.
Then, unless --no-second-opinion, get two external judges: write the cluster (problem, criteria, the three
proposals in full) to `proposals/{cluster}/judge-brief.md` and run
`node {SKILL_DIR}/references/second-opinion.mjs --mode judge --brief <that file>
--out proposals/{cluster}/external-judges.json <proposal mock screenshots>`.
MUSE Wonder and Gemini Argon score with the same rubric. Treat them as two more
votes with their own reasoning: a winner that both external judges reject needs
an explicit rebuttal in the decision document.
The orchestrator then writes `docs/ux-visual/decisions/{cluster}.md`:
- The chosen solution (possibly A with C's grafted idea), stated precisely
- Score table across judges (3 internal lenses + MUSE Wonder + Gemini Argon)
- **Defense**: why it beats each alternative, which norms it satisfies, what
  it costs, what it rules out
- Final acceptance criteria and the test plan
If `--no-implement`, stop here and report.

## Phase 6: Implement (fan out — one agent per cluster, worktree isolation)

Each implementer (general-purpose, `isolation: worktree` or its own named
worktree/branch `ux-visual/{cluster}`) gets the decision document and:
1. Changes the **design system first** (tokens → component CSS → component
   library → catalog), then pages — no ad-hoc styles; run the project's design
   system audit.
2. Writes a **failing test first** for behavior/layout changes: e.g. a
   Playwright assertion that `document.scrollingElement.scrollHeight <=
   innerHeight` on the page, that the primary action's bounding box is inside
   the viewport, that sibling cards share height, that focus order is correct.
3. Implements the decision exactly; deviations must be justified in the handoff.
4. Runs typecheck, lint, unit tests, the design-system audit, and the affected
   e2e specs; updates specs whose expectations changed (honestly, never
   weakening assertions to pass).
5. Commits with a message naming the cluster and decision; no push.
Clusters touching the same files run sequentially; others in parallel (≤ 4).

## Phase 7: Verify (independent agent per cluster)

A fresh agent (not the implementer) re-runs Phase 2's capture + measure +
manual pass on every affected surface at every viewport, compares before/after
screenshots side by side (Read both), checks each acceptance criterion with a
measurement, and hunts regressions on neighboring surfaces. Writes
`docs/ux-visual/verification/{cluster}.md` with pass/fail per criterion.
Fail → send the gaps back to the implementer (max 2 rounds), then escalate to
the orchestrator with evidence.

## Phase 8: Merge & Report (orchestrator)

Merge verified branches (resolve conflicts in the design system carefully),
re-run the full checks once, update `run-history.json`, and write
`docs/ux-visual/report.md` from `{SKILL_DIR}/templates/report-template.md`:
before/after screenshots per cluster, criteria met, what was deferred and why,
remaining P0/P1, and the "excellent as is" list. File GitHub issues for
deferred clusters (`gh issue create --label ux-visual`), deduping first.

## Report to User

- Surfaces audited (pages × states × viewports) and coverage gaps
- Findings by severity and level; top clusters with their root causes
- Each implemented cluster: decision in one line, why it won, verified result
- Deferred clusters (issue links) and anything still failing
- Path to `docs/ux-visual/report.md`

## Rules

- **Look and touch, then measure.** Every page is screenshotted and read,
  interacted with by hand, and measured by script. Numbers settle evenness and
  fit; eyes settle hierarchy and clarity.
- **Recursion is mandatory**: component → group → page → layout, then back down
  — a component that is fine alone can be wrong in its group.
- **One screen means one screen.** App surfaces (editors, rooms, dashboards,
  consoles) must fit the viewport at ≥ 1280×800 with inner panels scrolling;
  content pages may scroll but their primary action stays visible.
- **Density is a decision**, measured with layout-audit.js against the norms
  for the surface type (tool vs content vs marketing), not a feeling.
- **No manufactured findings; no excuses either.** Praise what is excellent.
- **Fix at the root, in the design system.** One token or component change
  beats ten page patches.
- **Different architectures catch different things.** External reviewers
  (MUSE Wonder, Gemini Argon) see only screenshots: verify their claims, credit
  them when right, overrule them with evidence when wrong.
- **Wait for content, not the network.** Pages with live connections
  (websockets, realtime) never reach network idle — wait for a known element
  and for fonts/animations, with a timeout.
- **Proof before claims.** A fix is done when the verifier's measurements and
  screenshots show it, tests pass, and nothing regressed.

## References

| File | Use |
|------|-----|
| [references/visual-heuristics.md](references/visual-heuristics.md) | The norms battery every inspector, designer and judge reads first |
| [references/layout-audit.js](references/layout-audit.js) | Viewport fit, scroll containers, density, whitespace, spacing scale, alignment, type scale, targets, contrast |
| `../ux-walker/references/geometry-audit.js` (sibling skill in this pack) | Sibling unevenness, spills, wrapped controls |
| [references/solution-rubric.md](references/solution-rubric.md) | Judge scoring and the defense template |
| [references/second-opinion.mjs](references/second-opinion.mjs) | External critiques/judging by Meta MUSE Wonder and Google Gemini 4 Argon via OpenRouter (max reasoning, images in, JSON out) |
| [templates/report-template.md](templates/report-template.md) | Final report layout |
