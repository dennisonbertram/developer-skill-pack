---
name: ux-flow
description: "Critique the app's user experience for simplicity, clarity, and redundancy. For each core journey asks 'how could this be simpler, how could this be clearer' — measures friction (actual vs. ideal steps), hunts duplicated features/paths/information, and audits visual hierarchy and information architecture. Use when asked to 'simplify the ux', 'audit the flows', 'find redundancy', 'ux critique', 'is this too complicated', 'flow audit', or 'run ux-flow'."
version: 0.1.0
user_invocable: true
---

# UX Flow — Simplicity & Redundancy Critique

Where `/ux-walker` asks *"does each journey work and look right?"*, `/ux-flow`
asks *"should each journey exist in this shape at all?"* It is a critique pass,
not a test pass: it measures friction per journey, hunts redundancy across
journeys, and produces ranked simplification proposals. The guiding stance:
**simplify, simplify, simplify** — every step, screen, choice, and repeated
piece of information must earn its place.

## Trigger Phrases

"simplify the ux", "audit the flows", "find redundancy", "ux critique",
"is this too complicated", "flow audit", "how could this be simpler",
"run ux-flow"

## Usage

```
/ux-flow [url] [--journeys N] [--no-issues] [--focus topic]
```

| Parameter | Default | Notes |
|-----------|---------|-------|
| **url** | Auto-detect (only needed for a live pass) | Target app URL |
| **--journeys N** | 8 | Number of core journeys to critique in depth |
| **--no-issues** | Off | Report only; do not file GitHub issues |
| **--focus topic** | All topics | Restrict critique to journeys matching this topic |

## Overview

```
User invokes /ux-flow [url] [flags]
└── Top-level agent (you — orchestrator only)
    ├── Phase 0: Preflight (orchestrator directly)
    │   └── Catalog check, walker-artifact freshness, URL/live-pass decision
    ├── Phase 1: Journey Selection (orchestrator directly)
    │   └── Pick N core journeys covering every major feature area
    ├── Phase 2: Critics (parallel)
    │   ├── Journey critics (one general-purpose agent per journey)
    │   │   └── Friction scorecard + take-away pass + "simpler version" proposal
    │   └── Redundancy critic (one general-purpose agent, cross-cutting)
    │       └── Duplicate paths/info/features + hierarchy & IA audit
    ├── Phase 3: Synthesis (orchestrator)
    │   └── Merge, rank by impact/effort → docs/ux-flow/report.md
    └── Phase 4: File issues (orchestrator, unless --no-issues)
```

## Output Directory

```
docs/ux-flow/
├── report.md                  # The critique — friction scorecards, redundancy map, ranked proposals
├── journeys/
│   └── {JOURNEY_ID}.md        # Per-journey critique from each journey critic
└── redundancy.md              # Cross-cutting redundancy & hierarchy findings
```

---

## Phase 0: Preflight

The orchestrator performs these checks directly.

### 0.1 Catalog Check

`docs/ux-paths/catalog.md` must exist. If not, stop:

```
No UX story catalog found. Run /ux-paths first, then re-run /ux-flow.
```

### 0.2 Evidence Source

Critics need to SEE the app, not just read stories. Decide the evidence source:

1. **Fresh walker artifacts** — if `docs/ux-walker/run-history.json` exists and the
   last run is recent (no significant commits to UI source since), reuse
   `docs/ux-walker/stories/*/screenshots/` and `walk-report.md` files. No browser needed.
2. **Live pass** — otherwise, detect the URL exactly as `/ux-walker` Phase 0 does
   (curl check, dev-server detection from package.json) and open an agent-browser
   session `ux-flow-{domain}`. Journey critics will traverse their journey live,
   capturing screenshots as they go (traversal only — no step-by-step verification;
   that is walker's job).

Always use `agent-browser` directly — never `npx agent-browser`.

### 0.3 Output Directories

```bash
mkdir -p docs/ux-flow/journeys
```

---

## Phase 1: Journey Selection

The orchestrator reads `docs/ux-paths/catalog.md` and selects `--journeys N`
(default 8) journeys, favoring:

1. **Core jobs** — the journeys a real user runs most (create the primary entity,
   consume the primary content, the money path)
2. **Coverage** — collectively touch every major feature area at least once
3. **The long stories** — end-to-end journeys expose cross-screen friction that
   short stories hide
4. Anything matching `--focus` when provided

Also extract the catalog's **Redundancy Candidates** section (if present) — it is
handed to the redundancy critic as its starting lead list.

---

## Phase 2: Critics (parallel)

Spawn all critics **in a single message**. Journey critics are independent of
each other and of the redundancy critic. If running a live pass, journey critics
share one browser session — run them sequentially instead, or give each its own
session via `--session ux-flow-{JOURNEY_ID}` when parallelism matters more than
login-state reuse.

### Journey Critic (one general-purpose agent per journey)

**Prompt template** (`{SKILL_DIR}` is this skill's base directory):

```
You are a UX flow critic. Your question is NOT "does it work?" — it is
"how could this be simpler, and how could this be clearer?"

## Journey
{FULL_STORY_TEXT — including Ideal path and Alternate paths fields}

## Evidence
{EITHER: "Walker artifacts: docs/ux-walker/stories/STORY-{ID}/ — read walk-report.md
and open every screenshot with the Read tool."
OR: "Live app at {URL}, agent-browser session {SESSION}. Traverse the journey,
screenshot each distinct screen into docs/ux-flow/journeys/{ID}-screens/, and
open each screenshot with the Read tool."}

## Method
Read {SKILL_DIR}/references/simplification-heuristics.md first, then:

1. **Friction scorecard** — count for the journey as a whole:
   - Steps: actual clicks/inputs/screens vs. the story's Ideal path count
   - Decisions: every point where the user must choose; which could a default carry?
   - Re-entry: data the user provides that the app already knows
   - Confirmations: which guard nothing destructive?
   - Dead ends: screens with no obvious next step
   - Hesitations: where a first-time user would stall (ambiguous label, hidden
     control, unexpected navigation)
2. **Take-away pass, per screen** — for each visible element ask: if removed,
   would the user still succeed? List everything removable, collapsible, or
   deferrable. Check visual hierarchy: exactly one primary action? Does visual
   weight match importance? Is any information stated more than once?
3. **The simpler version** — write the journey as it SHOULD be: the same goal in
   the fewest steps a well-designed UI needs. Number the steps. Then list the
   concrete changes to get from here to there (merge screens X+Y, default field Z,
   remove confirmation W, demote sidebar block V).
4. **Clarity pass** — labels or copy that assume knowledge the persona lacks;
   jargon; naming inconsistent with the rest of the app.

## Honesty rules
- Every claim points at evidence: a screenshot, a step number, a label. No
  invented UI, no assumed behavior.
- If the journey is already minimal, SAY SO. "No simplification found" is a
  valid, valuable verdict — do not manufacture friction to look thorough.
- Distinguish "measured" (counted steps, seen screenshot) from "suspected"
  (would need a live check).

## Output
Write docs/ux-flow/journeys/{JOURNEY_ID}.md with sections: Friction Scorecard,
Take-away Pass, The Simpler Version, Clarity Issues.
Return: 2-3 sentence summary + friction verdict (minimal | acceptable | convoluted).
```

### Redundancy Critic (one general-purpose agent, cross-cutting)

**Prompt template**:

```
You are a redundancy and information-architecture critic for this app.

## Evidence
- docs/ux-paths/catalog.md — all stories, Alternate paths fields, and the
  Redundancy Candidates section (your lead list)
- {All available screenshots: docs/ux-walker/stories/*/screenshots/ and/or
  docs/ux-flow/journeys/*-screens/} — open them with the Read tool; you are
  looking across screens, which no single-journey critic can do
- Read {SKILL_DIR}/references/simplification-heuristics.md first

## Hunt for
1. **Duplicate paths** — the same goal reachable multiple ways. For each: are the
   routes deliberate (shortcut + discoverable menu) or drift (two teams built the
   same thing)? Do they produce identical results? Recommend: keep both / mark one
   canonical / remove one.
2. **Duplicate information** — the same fact rendered on multiple screens or twice
   on one screen. For each repeat: does the second occurrence serve a new context,
   or is it noise? Recommend the single canonical surface.
3. **Overlapping features/tools** — two features whose capabilities substantially
   overlap. Recommend merge, differentiate, or remove.
4. **Hierarchy & IA** — does navigation structure match user priorities? Anything
   important buried 3+ levels deep? Anything trivial at top level? Is the same
   concept named consistently everywhere (one concept, one name)?

## Honesty rules
Evidence for every claim (screenshot or catalog reference). If the app is clean,
say so — an empty redundancy map is a pass, not a failure to find.

## Output
Write docs/ux-flow/redundancy.md with sections: Duplicate Paths, Duplicate
Information, Overlapping Features, Hierarchy & IA.
Return: 2-3 sentence summary + counts per section.
```

---

## Phase 3: Synthesis

The orchestrator reads all journey critiques and `redundancy.md`, then writes
`docs/ux-flow/report.md`:

```markdown
# UX Flow Critique — {DATE}

## Run Summary
| Metric | Value |
|--------|-------|
| Journeys critiqued | {N} |
| Evidence source | {walker artifacts (run of {DATE}) / live pass} |
| Verdicts | {X} minimal · {Y} acceptable · {Z} convoluted |

## Friction Scorecard
| Journey | Steps (actual/ideal) | Needless decisions | Re-entry | Dead ends | Verdict |
|---------|----------------------|--------------------|----------|-----------|---------|
| {title} | {a}/{i} | {n} | {n} | {n} | {verdict} |

## Redundancy Map
{Condensed from redundancy.md: duplicate paths, duplicate info, overlapping features — each with its recommendation}

## Simplification Proposals (ranked)
{Ordered by (journeys improved × steps/elements removed) ÷ effort. For each:}
### {N}. {Title}
- **Now**: {current flow/screen, with evidence pointer}
- **Proposed**: {the simpler version}
- **Saves**: {steps/screens/decisions removed; journeys improved}
- **Effort**: {S/M/L}
- **Evidence**: {journey file + screenshot refs}

## Already Minimal
{Journeys/areas that passed clean — credit where due, so re-runs skip them}
```

Ranking rule: a proposal that removes one step from the most-used journey beats
one that removes three steps from a rarely-used settings flow. Weight by how
central the journey is, not just raw step count.

## Phase 4: File Issues

Unless `--no-issues`: file a GitHub issue for each top proposal (max 10).

```bash
# Dedupe first — never re-file an open proposal
gh issue list --label ux-flow --state open
gh issue create \
  --title "UX-flow: {proposal title}" \
  --body "{Now / Proposed / Saves / Effort / Evidence sections from the report}" \
  --label "ux-flow,needs-design,{S|M|L}"
```

These are design-level changes — never auto-fix them. `/ux-flow` proposes;
humans (or a later scoped implementation task) decide.

## Report to User

- Verdict counts (minimal / acceptable / convoluted) and the friction table
- Top 3 simplification proposals in one line each
- Redundancy count by type
- Issues filed (numbers + links)
- Path to `docs/ux-flow/report.md`

---

## Guidance

- **Critique, don't test.** Broken buttons and misaligned cards are `/ux-walker`'s
  job. If a critic trips over a functional bug, note it in one line and move on.
- **The ideal path is the benchmark, not a fantasy.** "Fewer steps" that hides
  necessary information or removes user control is not simpler. Simplicity that
  costs clarity loses.
- **No manufactured findings.** A journey that is already minimal gets praised and
  skipped. The report's credibility rests on "Already Minimal" being non-empty
  when the app deserves it.
- **Look at screens, not just stories.** Redundancy and hierarchy problems are
  visible, not textual — critics must open screenshots with the Read tool.
- **One concept, one name.** Naming drift ("workspace" here, "project" there) is
  a redundancy finding even when the feature isn't duplicated.

## References

| Reference | When to Read |
|-----------|--------------|
| [references/simplification-heuristics.md](references/simplification-heuristics.md) | Every critic reads this before starting — the question battery and detection methods |
