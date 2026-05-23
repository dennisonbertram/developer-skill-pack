---
name: ux-paths
description: "Generate exhaustive user journey stories by analyzing the codebase. Creates realistic UX paths (short feature exercises and long end-to-end flows) using a swarm of parallel sub-agents. Use when asked to 'create stories', 'walk the app', 'map user journeys', 'generate ux paths', 'create user flows', 'map the app', 'what can users do', 'generate test scenarios', 'create e2e stories', or 'exercise the app'."
version: 0.1.0
user_invocable: true
---

# UX Paths — User Journey Story Generator

Generate an exhaustive, realistic catalog of user journeys through any application by analyzing its codebase. Produces short stories (exercise one feature) and long stories (complete multi-step workflows) that reflect how real users would actually use the app.

## Overview

```
User invokes /ux-paths [optional focus area]
└── Top-level agent (you — orchestrator only)
    ├── Phase 1: Discovery Agent (Explore)
    │   └── Deep codebase scan → topic list + app map
    ├── Phase 2: Story Swarm (8-12 Explore agents in parallel)
    │   ├── Agent: Authentication & Onboarding paths
    │   ├── Agent: Core Feature A paths
    │   ├── Agent: Core Feature B paths
    │   ├── Agent: Settings & Configuration paths
    │   ├── Agent: Error & Edge Case paths
    │   ├── Agent: Data Management paths
    │   ├── Agent: Navigation & Discovery paths
    │   ├── Agent: Integration & External Service paths
    │   ├── Agent: Multi-step Workflow paths
    │   ├── Agent: Power User & Advanced paths
    │   ├── Agent: First-time User / Onboarding paths
    │   └── Agent: Destructive & Cleanup paths
    └── Phase 3: Consolidation Agent (general-purpose)
        └── Merge, deduplicate, organize → final catalog
```

---

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| **Focus area** | Entire app | Optional `$ARGUMENTS` to scope (e.g., "authentication", "checkout flow") |
| **Output directory** | `docs/ux-paths/` | Where the final catalog and per-topic files land |
| **Depth** | `deep` | `quick` = fewer agents, shorter paths. `deep` = full swarm |

---

## Phase 1: Discovery

Spawn a single **Explore sub-agent** (read-only, no worktree) to produce an application map.

### Discovery Agent Prompt

The discovery agent must:

1. **Identify the application type** — web app, mobile app, desktop app, CLI tool, API, library, etc.
2. **Map all entry points** — routes, pages, screens, commands, endpoints
3. **Catalog all features** — what can a user actually DO? List every interactive capability.
4. **Identify user roles** — are there different user types (admin, member, guest, free, paid)?
5. **Map navigation structure** — how does the user move between features?
6. **Identify state transitions** — login/logout, onboarding, setup flows, subscription changes
7. **Find data entities** — what objects does the user create, read, update, delete?
8. **Detect integrations** — external services, OAuth providers, APIs, webhooks
9. **Note error states** — error boundaries, fallback UI, empty states, loading states
10. **Check for feature flags / conditional UI** — features behind toggles or permissions

The agent should search broadly across whatever framework/stack the project uses:
- **Routes / entry points**: React Router, Next.js pages/app dir, Express/Hono routes, Flask/Django URLs, SwiftUI NavigationStack, CLI command definitions, etc.
- **Page / screen components**: Whatever the UI layer is — React components, Vue views, SwiftUI views, Android Activities, CLI command handlers
- **Navigation structure**: Sidebars, tab bars, menus, breadcrumbs, command palettes, routing config
- **Forms / user input**: What data does the user provide? Forms, prompts, file pickers, CLI arguments
- **Modals / confirmations**: Dialogs, confirmation prompts, overlays, CLI interactive prompts
- **API endpoints**: REST routes, GraphQL schema, tRPC routers, gRPC services
- **Auth / guards**: Middleware, route guards, permission checks, role-based access
- **State management**: Stores, contexts, reducers, databases, config files
- **Config / feature flags**: Environment vars, feature toggles, permissions, roles
- **Read `references/path-categories.md`** from this skill's directory for the full taxonomy of categories to look for

### Discovery Output

The agent writes to `docs/ux-paths/discovery.md`:

```markdown
# App Discovery: {App Name}

## Application Type
{web app / desktop app / mobile app / CLI / API}

## Tech Stack
{framework, router, state management, auth system}

## User Roles
- {role 1}: {what they can do}
- {role 2}: {what they can do}

## Feature Map
### {Feature Area 1}
- {capability 1}
- {capability 2}

### {Feature Area 2}
- ...

## Navigation Structure
{how users move between features}

## Data Entities
- {entity}: create / read / update / delete
- ...

## Integrations
- {service}: {what it does}

## Recommended Story Topics
1. {Topic 1} — {brief rationale}
2. {Topic 2} — {brief rationale}
...
(aim for 8-12 topics that collectively cover the entire app)
```

The **Recommended Story Topics** list is critical — it becomes the assignment list for Phase 2.

---

## Phase 2: Story Swarm

After the discovery agent completes, spawn **one Explore sub-agent per topic** — all in parallel.

### How Many Agents?

- Use however many topics the discovery agent identified (typically 8-12)
- Each topic gets its own agent
- All agents run simultaneously

### Story Agent Prompt Template

Each story agent receives:

1. The discovery document (`docs/ux-paths/discovery.md`) for context
2. Its assigned topic
3. Instructions to produce realistic user journey stories

Each agent must:

1. **Read the discovery document** for app context
2. **Deep-dive into the codebase** for their assigned topic area — read the actual components, routes, handlers, and logic
3. **Generate stories** — each story is a numbered sequence of concrete user actions

### Story Format

Each story follows this structure:

```markdown
## STORY-{NNN}: {Descriptive Title}

**Type**: short | medium | long
**Topic**: {assigned topic}
**Persona**: {who is doing this — new user, power user, admin, etc.}
**Goal**: {what the user is trying to accomplish}
**Preconditions**: {what state must exist before this story starts}

### Steps
1. {User action} → {Expected result}
2. {User action} → {Expected result}
3. ...

### Variations
- {Variation A}: {what changes and why}
- {Variation B}: {what changes and why}

### Edge Cases
- {Edge case}: {what happens}
```

### Story Guidelines for Each Agent

**Short stories** (2-5 steps): Exercise a single feature in isolation.
- Log in with valid credentials
- Change a setting
- Delete an item
- Search for something
- Toggle a feature on/off

**Medium stories** (5-15 steps): Complete a meaningful workflow.
- Sign up and configure initial settings
- Create a resource and verify it appears correctly
- Start a task, encounter an error, recover, complete the task
- Use search to find something, then take action on it

**Long stories** (15-40 steps): Full end-to-end user journeys.
- First-time user: discover app → sign up → onboard → use core feature → customize → invite others
- Power user: log in → navigate to advanced feature → configure → execute workflow → review results → export
- Admin: manage users → configure system → handle edge case → audit activity

**Realism rules:**
- Steps must reference actual UI elements, routes, and features found in the codebase
- Don't invent features that don't exist
- Include realistic data (not "test123" — use plausible names, emails, values)
- Consider what the user is THINKING at each step, not just clicking
- Include moments where the user might hesitate, make a mistake, or change their mind
- Reference actual button labels, menu items, and page titles from the code

**Each agent should produce 5-15 stories** for their topic, mixing short/medium/long.

### Story Agent Output

Each agent writes to `docs/ux-paths/topics/{topic-slug}.md`.

---

## Phase 3: Consolidation

After all story agents complete, spawn a **general-purpose sub-agent** (no worktree needed) to:

1. **Read all topic files** from `docs/ux-paths/topics/`
2. **Read the discovery document** for context
3. **Assign sequential STORY IDs** across all topics (STORY-001, STORY-002, ...)
4. **Deduplicate** — merge stories that are substantially similar
5. **Cross-reference** — note where stories from different topics overlap (e.g., "authentication" stories connect to "onboarding" stories)
6. **Add a dependency graph** — which stories should be run before others (e.g., "create account" before "use feature X")
7. **Verify coverage** — check that every feature from the discovery document is exercised by at least one story
8. **Flag gaps** — list any features or flows NOT covered by any story
9. **Produce the final catalog**

### Final Catalog Format

Write to `docs/ux-paths/catalog.md`:

```markdown
# UX Path Catalog: {App Name}

Generated: {date}
Total Stories: {count}
Coverage: {features covered} / {total features} ({percentage})

## Summary

| Type | Count |
|------|-------|
| Short | {n} |
| Medium | {n} |
| Long | {n} |

## Coverage Matrix

| Feature Area | Stories | Gaps |
|-------------|---------|------|
| {area} | STORY-001, STORY-005, STORY-012 | {any uncovered aspects} |
| ... | ... | ... |

## Story Dependency Graph

```text
STORY-001 (Create Account)
├── STORY-005 (Configure Settings)
│   └── STORY-012 (Advanced Configuration)
├── STORY-008 (Create First Project)
│   ├── STORY-015 (Collaborate on Project)
│   └── STORY-020 (Export Project)
└── STORY-003 (Browse as New User)
```

## All Stories

### Authentication & Onboarding
{stories from this topic}

### {Next Topic}
{stories from this topic}

...

## Gaps & Recommendations
- {feature/flow not covered and why}
- {suggested additional stories}
```

---

## Execution Checklist

When invoked, follow these steps exactly:

### Step 0: Setup

```bash
mkdir -p docs/ux-paths/topics
```

If `$ARGUMENTS` contains a focus area, note it — the discovery agent should prioritize that area but still map the full app for context.

### Step 1: Spawn Discovery Agent

Spawn one Explore sub-agent with the Phase 1 prompt above. Wait for it to complete. Read the output summary — you need the topic list for Phase 2.

### Step 2: Spawn Story Swarm

Read the recommended topics from `docs/ux-paths/discovery.md`. For each topic, spawn an Explore sub-agent — **all in parallel in a single message**. Each agent gets:
- The discovery document path
- Its assigned topic name
- The output path: `docs/ux-paths/topics/{topic-slug}.md`
- The story format and guidelines from Phase 2 above

### Step 3: Wait for Swarm Completion

All agents must finish before consolidation. As each completes, note the summary.

### Step 4: Spawn Consolidation Agent

Spawn one general-purpose sub-agent with the Phase 3 prompt. Wait for completion.

### Step 5: Report to User

Print a summary:
- Total stories generated
- Breakdown by type (short/medium/long)
- Coverage percentage
- Any notable gaps
- Path to the catalog: `docs/ux-paths/catalog.md`

---

## Tips

- **The discovery phase is the foundation.** If the discovery agent misses a major feature area, the whole catalog will have gaps. Better to spend more time in Phase 1 than to rush into Phase 2.
- **Don't over-constrain topics.** Let the discovery agent determine natural topic boundaries based on the actual codebase, not a predetermined list.
- **Stories should be opinionated.** A good story has a specific persona with a specific goal — not "a user does some things." Bad: "User clicks settings." Good: "Maria, a team lead, needs to add her 3 new hires to the project before standup tomorrow."
- **Variations matter.** The happy path is one story. The error path, the edge case, the mobile viewport, the slow connection — these are all variations worth capturing.
- **Cross-topic stories are valuable.** Some of the best test scenarios span multiple feature areas. The consolidation agent should explicitly look for and create these.
- **Re-run periodically.** As the app evolves, re-run this skill to catch new features and deprecated flows. The catalog is a living document.
