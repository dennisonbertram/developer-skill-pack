# Issue Implementer Runbook

Authoritative how-to for the `issue-implementer` autonomous backlog agent.

---

## Overview

The issue-implementer is an autonomous control-plane agent that works a groomed GitHub backlog unattended. It claims issues labeled `status:ready` one at a time, drives each through a full TDD implementation cycle (red → green → regression commits), opens a PR whose body is self-contained proof of the work done, then immediately loops to the next ready issue. It repeats until the backlog is clear, a configurable budget is reached, or a stop condition trips. The agent never asks for human confirmation mid-run — the issue's behavior contract, agent-todo checklist, and Definition of Done are the sole authority. The only human gate is invocation.

---

## How to Start

```
--agent issue-implementer
```

The agent is invoked from the coordinator. After invocation it runs unattended.

### Invocation Arguments

All arguments are optional. Defaults are shown.

| Argument | Default | Description |
|----------|---------|-------------|
| `max_issues_per_run` | `5` | Maximum goals completed before the run stops cleanly. |
| `ci_retry_budget` | `2` | Retry attempts per issue when `pnpm verify` fails on the feature branch. |
| `attempt_budget` | `3` | Total delegate cycles per issue across all re-delegation (review, test, validate, CI). |
| `consecutive_ci_block_threshold` | `3` | Circuit-breaker threshold: if this many issues in a row block due to CI exhaustion, the entire run stops. |
| `target_repo` | _(current repo)_ | Path or GitHub slug of the repo to work in. |

### Examples

**Default run — work up to 5 ready issues:**

```
--agent issue-implementer
```

**Cautious first run — work exactly one issue, then stop:**

```
--agent issue-implementer max_issues_per_run=1
```

**Point at a different repo:**

```
--agent issue-implementer target_repo=owner/repo max_issues_per_run=1
```

---

## Preconditions

Before starting the agent, verify:

1. **`gh` is authenticated** — `gh auth status` must show an active account with repo write access.

2. **The four required labels exist** in the target repo. Create them with:

   ```bash
   gh label create "status:ready"       --color "0E8A16" --description "Groomed and ready for autonomous implementation"
   gh label create "status:in-progress" --color "E4E669" --description "Currently being worked by issue-implementer"
   gh label create "status:blocked"     --color "D93F0B" --description "Blocked — groomer action required"
   gh label create "status:kill"        --color "000000" --description "Kill switch — stop issue-implementer at this issue"
   ```

3. **Issues are groomed** — each `status:ready` issue must have a behavior contract, a Definition of Done checklist, and an agent-todo checklist. An ungroomed issue will be blocked by the agent when it cannot derive a task contract.

4. **SEQUENTIAL / SINGLE-INSTANCE ONLY** — never run two issue-implementer instances against the same repo at the same time. The claim operation (label swap + self-assign) is not truly atomic. Two concurrent instances can double-pick the same issue and produce conflicting branches. V1 is sequential only; distributed locking is a v2 concern.

---

## The Label Contract

Labels are the handshake between the grooming agent and the issue-implementer.

| Label | Applied by | Meaning |
|-------|-----------|---------|
| `status:ready` | Grooming agent | Claimable — behavior contract, DoD, and agent-todo are complete. |
| `status:in-progress` | issue-implementer (claim phase) | Currently being implemented; issue is assigned to the agent. |
| `status:blocked` | issue-implementer (blocked path) | Groomer action required before this issue can proceed. Agent left a comment explaining exactly what is missing. |
| `status:kill` | Human or groomer | Emergency stop — the agent will not claim this issue or any subsequent one. |

**Flow:** `status:ready` → (claimed) → `status:in-progress` → (PR opened, `Closes #N`) → issue closed by GitHub on merge.

**Blocked path:** `status:in-progress` → `status:blocked` → agent loops to next ready issue. The issue stays open for the groomer to fix.

**Kill switch:** Apply `status:kill` to any issue in the ready queue. The agent checks for this label both at `select` time and immediately before issuing the claim mutation; it stops cleanly at the next candidate check.

---

## What You Get

For each completed goal the agent opens a pull request that is self-contained proof of the work done. The PR body contains:

- **Human-readable summary**: one-line what + why; Definition of Done rendered as ticked markdown checkboxes; list of behavioral tests and regression tests added.
- **Audit-trail commits**: red (failing tests) → green (implementation) → regression (regression coverage), linked by hash.
- `Closes #<issue_number>` so GitHub closes the issue on merge.
- **Collapsible raw report**: the full machine-readable goal output JSON in a `<details>` block at the bottom for tooling consumption.

The PR itself is the durable record. The `.coord/` state directory is ephemeral and gitignored; nothing durable lives there.

---

## Stop Conditions and Termination

The run ends and emits `loop_status: "terminal"` when any of the following trip:

| `run_stop_reason` | When |
|-------------------|------|
| `max_issues_reached` | Completed `max_issues_per_run` goals; stopping cleanly. |
| `kill_switch` | Next candidate carried `status:kill`; stopping cleanly. |
| `no_ready_issues` | No `status:ready` issues remain; stopping cleanly. |
| `ci_retry_budget_exhausted` | **Circuit breaker**: the number of consecutive issues blocked by CI/`pnpm verify` exhaustion reached `consecutive_ci_block_threshold` (default: 3). Signals a systemic problem such as a broken base branch. Per-issue CI exhaustion alone does NOT stop the run — it marks that issue `status:blocked` and continues. |

A blocked individual issue emits `loop_status: "blocked"` for that goal and immediately returns to `select` for the next ready issue. It is not a run-stop event.

---

## First-Run Guidance

1. Create one hand-labeled `status:ready` issue in a test repo. Give it a minimal behavior contract and DoD.
2. Invoke with `max_issues_per_run=1` so the agent works exactly that one issue and stops.
3. Watch the full cycle: startup → select → claim → ground → plan → delegate → integrate → review → test → validate → close.
4. Inspect the opened PR — verify the red → green → regression commit links, the ticked DoD checkboxes, and the collapsible raw report.
5. Once you are satisfied with the output quality, remove the `max_issues_per_run=1` override and let the agent loop a real backlog.

**Kill switch as emergency stop**: if the agent is mid-run and you need it to stop after the current issue completes, apply the `status:kill` label to any issue in the ready queue. The agent checks for it at the next `select` phase and exits cleanly.

---

## Deferred / Not in V1

- **Refactor and test issue types**: the agent currently routes only `feature` and `bugfix` issues to TDD workers. Standalone refactor (`worker-refactor`) and coverage-uplift (`worker-test`) routing is deferred. Target repos built with `setup-repo` do not produce these issue types in their templates.
- **Parallel runs**: running multiple issue-implementer instances concurrently against the same repo requires a distributed lock (e.g., a lock file or GitHub-based mutex). This is a v2 concern. V1 is sequential / single-instance only.
