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

### 3. Generate UX stories

```
/ux-paths
```

Analyzes the codebase and produces a catalog of user journey stories.

### 4. Walk the stories through a browser

```
/ux-walker http://localhost:3000
```

Tests each story for correctness, visual quality, and UX excellence.

### 5. Research before adopting

```
/research-spike "Should we use Prisma or Drizzle for the ORM?"
```

### 6. Debug a bug

```
/debug
```

7-phase deterministic workflow: symptom → archaeology → reproduce → logs → hypothesis → fix → regression test.

### 7. Mine session transcripts for learnings

```
/mine-transcripts
```

Discovers sub-agent JSONLs, mines them in parallel for dead ends, silently-recovered errors, and design sub-decisions, then promotes high-confidence findings to durable docs.

### 8. Guard against regressions

```
/regression-guard
```

Generates unit and regression tests for the last fix.

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
