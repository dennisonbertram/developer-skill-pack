# Visual & Interaction Heuristics — the norms battery

Read this before inspecting, proposing or judging. Every finding names the norm
it violates (use the IDs). "It's the default" or "it's an edge case" is never a
defense.

## L — Layout & viewport fit
- **L1 One screen for app surfaces.** Tools, editors, rooms, dashboards and
  consoles fit the viewport at ≥ 1280×800 with no page scroll; long content
  scrolls inside its panel. Measured: `layout-audit.js → viewport.pageScrollY`.
- **L2 Primary action always visible.** The main action of a screen (Send, Save,
  Create) is inside the viewport without scrolling at every target viewport.
- **L3 Nothing grows the page by accumulation.** Repeated events (notifications,
  approvals, toasts, logs) must not push layout; they dock, replace, collapse,
  or scroll inside a container.
- **L4 One grid.** Regions align to shared edges; outer gutters equal; no
  full-bleed panel beside inset panels.
- **L5 Stable layout.** No layout shift when data loads, states change, or
  hover toolbars appear (reserve space or overlay).
- **L6 Reflow, not overflow.** No horizontal scroll at any viewport ≥ 320px;
  components reflow (stack, wrap, collapse to menus) at breakpoints.
- **L7 Predictable regions.** Navigation where users expect it (top/left), the
  primary work area largest, secondary info at the side, actions near what they
  act on.

## D — Density & whitespace
- **D1 Density fits the surface.** Tools/dashboards: dense (body 13–14px,
  row height 28–36px, tight groups). Content/reading: comfortable (16px+,
  line-height 1.5–1.7, measure 45–80ch). Marketing: airy, generous sections.
- **D2 Whitespace is intentional.** No dead bands (large empty areas that carry
  no meaning, e.g. a mostly-empty panel reserving 40% of the screen), no cramped
  clusters. Empty states are compact on tool surfaces.
- **D3 Spacing scale.** All gaps/paddings come from the design system's scale
  (4/8-based); measured values off-scale or near-duplicates (e.g. 14 and 16
  side by side) are findings.
- **D4 Proximity encodes grouping.** Space within a group < space between
  groups (Gestalt proximity), consistently.
- **D5 Information per pixel.** Repeated chrome (avatars, names, timestamps,
  labels) is collapsed where repetition carries no new information (e.g.
  grouped chat messages).

## H — Hierarchy & visual design
- **H1 One focal point and one primary action per view.** Exactly one
  high-emphasis button per region; others secondary/tertiary.
- **H2 Weight matches importance.** Size, color, contrast and position follow
  the task's priority; destructive actions are distinct but not dominant.
- **H3 Type scale.** A small set of sizes/weights from the system; headings
  clearly stepped; no more than ~5 distinct sizes on a screen.
- **H4 Color with purpose.** Accent reserved for primary/active/live states;
  semantic colors only for their meaning; not one accent smeared everywhere.
- **H5 Consistency.** Same thing, same look, same place, same name across pages.
- **H6 Alignment.** Text baselines and left edges align within a group; icons
  centered with their labels; numeric columns right-aligned.

## C — Clarity & content
- **C1 Plain labels.** Verbs for actions, nouns for places; no jargon the
  persona lacks; one concept, one name (no driver/control/lock drift).
- **C2 No duplication.** The same fact appears once per screen unless a new
  context needs it.
- **C3 Status is legible.** System state (working, waiting, error, offline) in
  one predictable place, in words plus color (never color alone).
- **C4 Microcopy earns its place.** Hint text that repeats the placeholder or
  the obvious is removed; truncation shows full text on hover/focus.

## I — Interaction & usability
- **I1 Affordance.** Clickable things look clickable; non-clickable things
  don't; links vs buttons used correctly.
- **I2 Feedback within 100ms**, progress for >1s, completion/failure stated.
- **I3 Error prevention and recovery.** Destructive actions confirm or undo;
  errors say what happened and what to do; inputs keep their values on error.
- **I4 Fitts.** Targets ≥ 24×24px (≥ 44×44 on touch); frequent targets large
  and near the work; related actions adjacent.
- **I5 Hick.** Few choices at once; progressive disclosure for advanced
  options; defaults carry most decisions.
- **I6 Recognition over recall.** Visible options, remembered preferences,
  clear current location (active tab/nav).
- **I7 Keyboard and focus.** Logical tab order, visible focus rings, Escape
  closes overlays, Enter submits, focus returns after dialogs; hover-only UI
  reachable by keyboard and touch.
- **I8 States complete.** Every component has hover, focus, active, disabled
  (with reason), loading, empty, error, and long-content states designed.

## A — Accessibility baseline
- **A1 Contrast** ≥ 4.5:1 text, ≥ 3:1 large text and UI boundaries/icons.
- **A2 Names.** Every control has an accessible name; icon-only buttons have
  labels/tooltips.
- **A3 Motion.** Respects `prefers-reduced-motion`; no essential info only in
  animation.
- **A4 Zoom.** Usable at 200% zoom without loss of content.

## P — Platform & category conventions
- **P1 Follow the category's best-in-class patterns** (e.g. chat: grouped
  messages, composer pinned bottom, inline media; code tools: tabs for views,
  status bar, command palette; streaming: player-first layout, chat column,
  channel bar) unless a deliberate improvement is documented.
- **P2 Familiar controls** for familiar jobs (segmented controls for 2–4
  exclusive views, tabs for peer views, menus for overflow, toggles for
  instant settings, checkboxes for deferred settings).

## Severity guide
P0 blocks/misleads · P1 a human stumbles (L1, L2, L3, I3, C1 failures usually
land here) · P2 visibly below excellent (D3, H6, D5) · P3 polish.
