# Developer Skill Pack

**A complete development toolkit for AI-assisted coding — UX testing, multi-agent coordination, TDD workflow, GitHub templates, research spikes, and repo scaffolding.**

Works with **Claude Code** and **OpenAI Codex CLI**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What's Inside

### UX Testing (from [ux-toolkit](https://github.com/dennisonbertram/ux-toolkit))

| Skill | Description |
|-------|-------------|
| **ux-paths** | Generate exhaustive user journey stories by analyzing the codebase. Produces short, medium, and long stories with a swarm of parallel sub-agents. |
| **ux-walker** | Walk the UX story catalog through a real browser, testing each journey for correctness, visual quality, and UX excellence. Auto-fixes small issues, files GitHub issues for larger ones. |
| **walk-the-issues** | Groom all open GitHub issues, then loop through them — branching, researching, implementing with swarms, testing, and creating PRs until all issues are complete. |

### Coordination (from [claude-coordinator](https://github.com/dennisonbertram/claude-coordinator))

| Skill | Description |
|-------|-------------|
| **coordinator** | Pure-delegation control plane with a 10-phase state machine. Plans, delegates, reviews, and learns. 14 specialized agents with JSON Schema output contracts. |
| **issue-groomer** | Autonomous backlog groomer. Claims open status-less issues, researches each deeply (codebase + product docs + external APIs), fills the target repo's issue template exhaustively, and applies `status:ready` (clear path) or `status:blocked` (exhaustively groomed, path-decision needed). Loops; WATCH mode re-checks every `poll_interval`. Sequential v1 — one instance per repo. |
| **issue-implementer** | Autonomous backlog agent. Claims `status:ready` issues, drives each to a tested PR (red → green → regression commits), then loops until the backlog is clear or a stop condition trips. Sequential v1 — one instance per repo. |
| **mine-transcripts** | Sweep sub-agent JSONL transcripts for novel learnings and promote the strongest to durable docs. Parallel mining with dedupe baseline. |

### Development Process (from [partyline](https://github.com/dennisonbertram/partyline) + [synthetix](https://github.com/dennisonbertram/synthetix))

| Skill | Description |
|-------|-------------|
| **setup-repo** | Scaffold a repo with GitHub issue templates, PR template, TDD hooks, process docs, and CI configuration. |
| **debug** | Deterministic 7-phase debugging workflow — symptom capture through regression test commit. |
| **regression-guard** | Post-fix test-coverage analysis — generates unit and regression tests, audits how the bug could have been caught earlier. |
| **research-spike** | Time-boxed research with Context7 integration — produces structured findings in `docs/research/`. |

### Hooks

| Hook | Event | Description |
|------|-------|-------------|
| **tdd-reminder** | PreToolUse (Edit/Write) | Warns when modifying `src/` without a failing test first |
| **session-start** | SessionStart | Announces TDD-first requirement |

---

## Installation

### Claude Code (recommended)

```bash
npx skills add dennisonbertram/developer-skill-pack
```

Or install specific skills:

```bash
npx skills add dennisonbertram/developer-skill-pack --skill coordinator debug setup-repo
```

### OpenAI Codex CLI

```bash
# Clone and copy skills to your project
git clone https://github.com/dennisonbertram/developer-skill-pack
cp -r developer-skill-pack/skills/ .agents/skills/
cp developer-skill-pack/codex/AGENTS.md AGENTS.md
cp developer-skill-pack/codex/config.toml .codex/config.toml
cp developer-skill-pack/hooks/ .codex/hooks/
```

### Manual (any agent)

```bash
git clone https://github.com/dennisonbertram/developer-skill-pack
# Copy skills/ to your agent's skill directory
# Copy hooks/ for TDD enforcement
# Copy docs/process/ for development workflow documentation
```

---

## Quick Start

### 1. Scaffold a new repo

```
/setup-repo
```

Creates GitHub issue templates, PR template, hooks, and process docs.

### 2. Plan and coordinate work

```
/coordinator
```

Enters the 10-phase state machine: intake → plan → delegate → integrate → review → test → validate → close.

### 3. Groom the backlog

```
--agent issue-groomer
```

Claims open status-less issues one at a time → researches each deeply → fills the issue template exhaustively → applies `status:ready` or `status:blocked` → loops until the backlog is groomed (or `max_issues_per_run` is reached). Unattended after invocation. See the [issue-groomer runbook](skills/coordinator/docs/issue-groomer-runbook.md) for preconditions, label setup, stop conditions, and first-run guidance.

### 4. Work the backlog autonomously

```
--agent issue-implementer
```

Claims `status:ready` issues one at a time → TDD implementation → tested PR → loops until the backlog is clear (or `max_issues_per_run` is reached). Unattended after invocation. See the [issue-implementer runbook](skills/coordinator/docs/issue-implementer-runbook.md) for preconditions, label setup, stop conditions, and first-run guidance.

### 5. Generate UX stories

```
/ux-paths
```

Analyzes the codebase and produces a catalog of user journey stories.

### 6. Walk the stories through a browser

```
/ux-walker http://localhost:3000
```

Tests each story for correctness, visual quality, and UX excellence.

### 7. Research before adopting

```
/research-spike "Should we use Prisma or Drizzle for the ORM?"
```

### 8. Debug a bug

```
/debug
```

7-phase deterministic workflow: symptom → archaeology → reproduce → logs → hypothesis → fix → regression test.

### 9. Mine session transcripts for learnings

```
/mine-transcripts
```

Discovers sub-agent JSONLs, mines them in parallel for dead ends, silently-recovered errors, and design sub-decisions, then promotes high-confidence findings to durable docs.

### 10. Guard against regressions

```
/regression-guard
```

Generates unit and regression tests for the last fix.

---

## Autonomous Backlog Implementation (issue-groomer + issue-implementer)

Two autonomous agents form a continuous pipeline from raw idea to merged, tested PR — with no human involvement between invocation and completion.

### Pipeline: Groomer → Implementer

```
open (no status)
  → [issue-groomer]     status:grooming
  → [issue-groomer]     status:ready         ← HANDOFF LABEL
                     OR status:blocked        (exhaustively groomed, path-decision needed)

status:ready
  → [issue-implementer] status:in-progress
  → PR (Closes #N)      → merged
```

`status:ready` is the handoff label between the two agents. The groomer writes it; the implementer reads it.

| Agent | Trigger | Output |
|-------|---------|--------|
| `issue-groomer` | Open issues with no `status:*` label | `status:ready` (claimable) or `status:blocked` (groomed, decision pending) |
| `issue-implementer` | Issues labeled `status:ready` | Tested PR with red → green → regression audit trail; issue closed on merge |

**Blocked path:** `status:blocked` means the issue is fully groomed — not half-done. A genuine product/path decision needs a human (or review agent) before implementation can proceed. Once resolved, the issue transitions back to `status:ready` and the implementer picks it up.

### issue-groomer

Claims status-less issues one at a time → researches each deeply (codebase + product docs + external APIs) → fills the issue template exhaustively with behavior contract, verified file paths, assumptions, and alternatives → applies `status:ready` or `status:blocked` → loops until the backlog is groomed. Unattended after invocation.

```
--agent issue-groomer
```

For a cautious first run (one issue only):

```
--agent issue-groomer max_issues_per_run=1
```

**V1 constraint:** sequential and single-instance only. Never run two issue-groomer instances against the same repo simultaneously.

For the full runbook — preconditions, exact `gh label create` commands, stop conditions, WATCH mode, kill switch, and first-run guidance — see [`skills/coordinator/docs/issue-groomer-runbook.md`](skills/coordinator/docs/issue-groomer-runbook.md).

### issue-implementer

Claims the oldest `status:ready` issue → grounds itself against the codebase → delegates a TDD worker (red → green → regression commits) → runs review and test passes → opens a PR whose body contains the full DoD checklist, audit-trail commit links, and a collapsible machine-readable report → closes the issue → loops to the next ready issue. Stops when the backlog is clear, `max_issues_per_run` is reached, or a stop condition trips.

```
--agent issue-implementer
```

For a cautious first run (one issue only):

```
--agent issue-implementer max_issues_per_run=1
```

**V1 constraint:** sequential and single-instance only. Never run two issue-implementer instances against the same repo simultaneously.

For the full runbook — preconditions, label setup with exact `gh label create` commands, stop conditions, kill switch, and first-run guidance — see [`skills/coordinator/docs/issue-implementer-runbook.md`](skills/coordinator/docs/issue-implementer-runbook.md).

---

## Codex CLI Coordinator

The coordinator pattern works with Codex CLI via its MCP server mode. Codex supports:

- **Hooks**: Same lifecycle events as Claude Code (SessionStart, PreToolUse, PostToolUse, Stop)
- **Skills**: First-class `SKILL.md` support with progressive disclosure
- **AGENTS.md**: Hierarchical instructions (equivalent to CLAUDE.md)
- **Subagents**: Native spawning with `max_threads` and `max_depth` config
- **MCP Server**: `codex mcp-server` exposes `codex` and `codex-reply` tools for external orchestration

See `codex/` directory for Codex-specific configuration files.

### Known Codex Limitations

- `type: "agent"` hook handlers are parsed but not yet functional
- `async: true` on hooks is parsed but skipped
- Automatic delegation (`delegation_mode = "skill_auto"`) is not yet implemented (tracked in openai/codex#18193)
- Project-local hook discovery may require global config in some versions

---

## GitHub Issue Templates

The `setup-repo` skill installs three structured issue templates:

### Feature Slice
Behavior contracts, design specs, TDD audit trail, agent todo checklist, regression risks, deploy impact, documentation handoff.

### Bug Regression
Reproduction steps, regression test plan (smallest test + behavior proof), blast radius, TDD audit trail.

### Research Spike
Question, options to compare, Context7 documentation sources, agent todo checklist, expected output.

---

## Development Process

The skill pack enforces a behavior-first TDD workflow:

1. **RED** — Write a failing test that defines the desired behavior
2. **GREEN** — Write the minimum code to make the test pass
3. **REFACTOR** — Clean up while keeping tests green

Every feature/bugfix produces three auditable commits:
```
test(red): TASK-042 failing tests for rate-limit
feat: TASK-042 implement per-IP rate limiting
test(regression): TASK-042 regression coverage
```

See `docs/process/` for the full workflow documentation.

---

## Directory Structure

```
developer-skill-pack/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── skills/
│   ├── ux-paths/                      # User journey story generator
│   │   ├── SKILL.md
│   │   └── references/
│   ├── ux-walker/                     # Browser-based UX testing
│   │   ├── SKILL.md
│   │   ├── references/
│   │   └── templates/
│   ├── walk-the-issues/               # Issue grooming + implementation loop
│   │   ├── SKILL.md
│   │   └── references/
│   ├── coordinator/                   # Multi-agent orchestration
│   │   ├── SKILL.md
│   │   ├── agents/                    # 14 agent definitions
│   │   ├── schemas/                   # JSON Schema output contracts
│   │   └── templates/
│   ├── mine-transcripts/               # Session transcript mining
│   │   └── SKILL.md
│   ├── setup-repo/                    # Repo scaffolding
│   │   ├── SKILL.md
│   │   └── references/               # GitHub templates, hooks, PR template
│   ├── debug/                         # 7-phase debugging workflow
│   │   └── SKILL.md
│   ├── regression-guard/              # Post-fix test coverage
│   │   └── SKILL.md
│   └── research-spike/               # Structured research
│       └── SKILL.md
├── hooks/                             # TDD enforcement hooks
│   ├── tdd-reminder.sh
│   └── session-start.sh
├── codex/                             # OpenAI Codex CLI configuration
│   ├── AGENTS.md
│   └── config.toml
├── docs/
│   └── process/                       # Development workflow documentation
│       ├── development-workflow.md
│       ├── github-build-process.md
│       ├── behavior-tdd.md
│       └── regression-discipline.md
├── skills.sh.json                     # skills.sh display configuration
├── README.md
└── LICENSE
```

---

## Sources

This skill pack combines and extends:

- **[ux-toolkit](https://github.com/dennisonbertram/ux-toolkit)** — UX story generation, browser testing, issue implementation
- **[claude-coordinator](https://github.com/dennisonbertram/claude-coordinator)** — Multi-agent orchestration with JSON Schema contracts
- **[partyline](https://github.com/dennisonbertram/partyline)** — GitHub templates, TDD hooks, development process, learning system
- **[synthetix](https://github.com/dennisonbertram/synthetix)** — Behavior-first TDD, issue templates with agent checklists
- **[agent-university](https://github.com/dennisonbertram/agent-university)** — Hook architecture research, fleet-bus substrate, Codex compatibility

---

## License

MIT — see [LICENSE](LICENSE).
