---
name: coordinator
description: "Launch the coordinator — a pure-delegation control plane that plans, delegates, reviews, and learns. Use when asked to 'coordinate', 'plan and delegate', 'run the coordinator', 'use the state machine', 'start a structured session', or 'plan this work'."
version: 1.0.0
user_invocable: true
---

# Coordinator

Launch a structured orchestration session using a 10-phase state machine. The coordinator delegates ALL work to specialized subagents — it never reads or writes files directly.

## Usage

```
/coordinator [task description]
```

If invoked with no arguments, the coordinator enters the `intake` phase and asks what you want to work on.

## Agent Team

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| **briefer** | Haiku | Read, Glob, Grep | Reads context files, returns structured briefings |
| **planner** | Sonnet | Read, Glob, Grep, Agent | Produces task breakdowns with behavioral test specs |
| **worker** | Sonnet | Full toolset | Strict TDD implementation (feature/bugfix). Red → green → regression commits. |
| **worker-refactor** | Sonnet | Full toolset | Behavior-preserving refactors. Existing tests must pass before and after. |
| **worker-test** | Sonnet | Full toolset | Adds tests to existing untested code. Mutation-checks its own tests. |
| **worker-investigation** | Sonnet | Read, Bash, Glob, Grep | Read-only research. Returns structured findings. |
| **reviewer** | Opus | Read, Bash, Glob, Grep | Code review with severity ratings. |
| **ui-tester** | Sonnet | Read, Bash, Glob, Grep | Visual quality inspector via browser automation. |
| **ux-tester** | Opus | Read, Bash, Glob, Grep | Usability evaluator via browser automation. |
| **system-tester** | Sonnet | Read, Bash, Glob, Grep | Full test suites, regression coverage, integration. |
| **intent-validator** | Opus | Read, Glob, Grep | Validates work matches user's original intent. Foreground. |
| **learning-extractor** | Opus | Read, Glob, Grep, Bash | Surfaces learnings from task artifacts and transcripts. |
| **scribe** | Haiku | Read, Write | Writes all state files. |
| **issue-implementer** | Opus | Agent | Autonomous groomed-backlog → tested-PR loop. Claims status:ready issues, implements each via TDD workers in dedicated worktrees, opens a PR, then loops to the next ready issue. Started via `--agent issue-implementer`; runs unattended after invocation. See [docs/issue-implementer-runbook.md](docs/issue-implementer-runbook.md) for preconditions, label setup, stop conditions, and first-run guidance. |
| **issue-groomer** | Opus | Agent | Autonomous backlog groomer. Claims open status-less issues, researches each deeply (codebase + product docs + external APIs), fills the target repo's issue template exhaustively with behavior contracts, assumptions, and alternatives, then applies status:ready (clear implementation path) or status:blocked (exhaustively groomed, genuine product/path decision needed). Loops; in WATCH mode re-checks every poll_interval for new issues. Started via `--agent issue-groomer`; runs unattended after invocation. See [docs/issue-groomer-runbook.md](docs/issue-groomer-runbook.md) for preconditions, label setup, stop conditions, and first-run guidance. |

## State Machine

```
startup → intake → plan → delegate → integrate → review → test → promote-learnings → validate → close
```

### Hard Gates (require user approval)

- **intake → plan**: User must confirm the intent document.
- **plan → delegate**: User must approve the plan before work begins.

## Worker Selection

| Task type | Agent | TDD enforced? |
|-----------|-------|---------------|
| `feature` | worker | Yes — red/green/regression commits |
| `bugfix` | worker | Yes — red commit reproduces bug |
| `refactor` | worker-refactor | No — existing tests must pass before & after |
| `test` | worker-test | No — tests must be meaningful (mutation-checked) |
| `investigation` | worker-investigation | N/A (no code written) |

## Task Contract

Every delegated task includes:

```json
{
  "title": "Clear task name",
  "type": "feature | bugfix | refactor | test | investigation",
  "scope": "Precise description",
  "allowed_files": ["list of files/directories"],
  "forbidden_files": ["files NOT to touch"],
  "dependencies": ["task IDs"],
  "behavioral_tests": ["When [condition], then [result]"],
  "regression_test_requirements": "What regression tests must exist"
}
```

## State Layers

### `.coord/` — Machine State (ephemeral, gitignored)

| File | Purpose |
|------|---------|
| `task-ledger.json` | All tasks and statuses |
| `learning-inbox.jsonl` | Candidate learnings |
| `context-packet.md` | Session continuity |
| `tasks/TASK-XXX.json` | Per-task artifacts |
| `reviews/REVIEW-XXX.json` | Review artifacts |

### `docs/` — Durable Human-Readable Memory

| File | Purpose |
|------|---------|
| `docs/context/command-intent.md` | Captured user intent |
| `docs/context/repo-practices.md` | Conventions and patterns |
| `docs/context/known-issues.md` | Known problems |
| `docs/plans/active-plan.md` | Current plan |

## Instructions

When this skill is invoked, load and follow the full coordinator agent definition at `agents/coordinator.md` in this skill's directory. The agent definitions for all subagents are in `agents/`. Output schemas are in `schemas/`.

## References

| Reference | Purpose |
|-----------|---------|
| [agents/coordinator.md](agents/coordinator.md) | Full coordinator system prompt |
| [agents/](agents/) | All agent definitions |
| [schemas/](schemas/) | JSON Schema contracts for agent outputs |
| [coordinator-settings.json](coordinator-settings.json) | Permission deny list |
| [templates/.worktreeinclude](templates/.worktreeinclude) | Files to copy into worktrees |
