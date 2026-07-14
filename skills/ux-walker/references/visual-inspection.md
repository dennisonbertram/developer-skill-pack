# Visual Inspection Protocol

How walker agents catch what accessibility snapshots cannot: misalignment,
uneven shapes, bad spacing, broken wrapping. Two instruments, used together:

- **Eyes** (Read tool on the screenshot) — judge gestalt: does this look
  designed, balanced, intentional? Eyes are bad at "is this 14px or 18px?"
- **Geometry script** (`geometry-audit.js` via `agent-browser eval`) — measure:
  exact heights, gaps, drift, spill. Numbers don't hallucinate, but they can't
  tell whether a variance is intentional. The screenshot decides that.

A violation is only a finding when both agree it matters: the script (or your
own measurement) shows the defect, and the screenshot shows a user would see it.

## The LOOK pass — run on every screenshot you take

Open the PNG with the Read tool. Do not audit from memory of the snapshot.
Answer each question by pointing at the image:

1. **Siblings**: Find every group of repeated elements (cards, tiles, rows,
   nav items, form fields). Within each group — same height? same width? same
   corner radius? same internal padding? One odd member ruins the group.
2. **Edges**: Trace the left edge of the content column top to bottom. Does
   everything that should start at the same x actually start there? Trace the
   tops of side-by-side items. Check label/input pairs and nested indentation —
   is each nesting level indented by the same amount?
3. **Gaps**: Are gaps between siblings equal? Is section padding consistent
   across sections? Any orphan whitespace (a large empty region with no purpose)?
4. **Text**: Any button/tab/chip/nav label wrapped onto two lines? Any mid-word
   break? Any truncation cutting off meaning? Any long value (name, email, title)
   visibly pushing its container or neighbors out of shape?
5. **Containment**: Anything spilling, clipping, or overlapping — text outside
   its card, a dropdown cut off, elements stacked wrongly?
6. **Hierarchy**: Squint (mentally blur the image). What pops first? It should
   be the primary action or the key information — not a border, a badge, or
   three equally-loud buttons. Exactly one element should read as "do this next."
7. **Repetition**: Is the same fact shown more than once on this screen (title
   in header AND breadcrumb AND card AND sidebar)? Repeated info is hierarchy
   debt — note it.

Record one sentence per screenshot in walk-report.md: what the screen shows and
what (if anything) failed the LOOK pass.

## The MEASURE pass — geometry-audit.js

Run at each distinct page state:

```bash
agent-browser --session {SESSION} eval "$(cat {SKILL_DIR}/references/geometry-audit.js)"
```

Returns JSON:

| Field | Meaning | Typical finding |
|-------|---------|-----------------|
| `pageOverflowX` | px of horizontal page scroll | `layout` — something is wider than the viewport |
| `unevenRows[]` | similar siblings in one visual row with mismatched `heights`/`widths`/`gaps` or `topDriftPx` | `consistency` — cards with different shapes, uneven gutters, misaligned tops |
| `overflowSpills[]` | content escaping a container with `overflow: visible` | `layout` — text/element spilling out |
| `wrappedControls[]` | short labels on button-like controls forced onto 2+ lines | `layout` — wrapped button/tab labels |

Rules:
- Confirm every script hit in the screenshot before logging it. If the screenshot
  shows the variance is intentional (a featured card deliberately larger), skip it.
- Thresholds are tuned to skip sub-pixel noise (>8px shape variance, >4px gap
  variance, >3px top drift). Do not report drift below the script's thresholds.
- One systemic defect ≠ N findings. If the same card component is uneven on five
  screens, log ONE finding listing all occurrences — the fix is in one component.

## Ad-hoc measurements

When you suspect a specific defect the script doesn't cover:

```bash
# Exact bounding box of one element
agent-browser --session {SESSION} get box "selector"

# Computed styles (padding, margin, font-size, line-height)
agent-browser --session {SESSION} get styles "selector"
```

Compare two elements' boxes to prove a misalignment before logging it — findings
with measured pixel numbers ("left edges differ by 7px: 24px vs 31px") get fixed;
findings that say "looks slightly off" get ignored.

## Responsive spot-check

Once per story at the primary screen:

```bash
agent-browser --session {SESSION} set viewport 390 844   # iPhone-class width
agent-browser --session {SESSION} screenshot {dir}/mobile-check.png
# Read the PNG: wrapped controls? horizontal scroll? overlapping/stacked breakage?
agent-browser --session {SESSION} set viewport 1280 800  # restore
```

Optionally re-run geometry-audit.js at the narrow width — wrap and overflow
defects usually appear there first.

## Theme spot-check (when the app has dark/light modes)

```bash
agent-browser --session {SESSION} set media dark
agent-browser --session {SESSION} screenshot {dir}/dark-check.png
agent-browser --session {SESSION} set media light
```

Look for: unreadable text, hard-coded light backgrounds, invisible borders.
