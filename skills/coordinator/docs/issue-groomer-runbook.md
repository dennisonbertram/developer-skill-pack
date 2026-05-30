# Issue Groomer Runbook

Authoritative how-to for the `issue-groomer` autonomous backlog agent.

---

## Overview

The issue-groomer is the producer counterpart to `issue-implementer`. It sweeps a repo's GitHub issue backlog and turns under-specified issues into fully-specified, implementer-ready issues — unattended, with no human interaction mid-run.

For each status-less issue, the groomer:

1. **Claims** the issue (adds `status:grooming`, self-assigns).
2. **Grounds itself** against the codebase, product docs, and external API docs — reading real file paths, integration points, and user intent.
3. **Drafts** an exhaustive issue body that follows the target repo's issue template: testable behavior contract, verified file paths, integration spec, in/out-of-scope, regression risks, DoD checklist, documented assumptions, alternatives considered, UI/UX notes.
4. **Applies** `status:ready` (clear implementation path — claimable by the implementer immediately), `status:blocked` (exhaustively groomed, a genuine product/path decision needs a human), or on operational failure: releases the claim (`status:grooming` removed, unassigned) and emits `groom_status:failed` so the issue is auto-retried next run.
5. **Loops** — returns to select the next status-less issue.

In WATCH mode the groomer re-checks for new issues every `poll_interval` after the backlog is exhausted.

The only human gate is invocation. After that, the groomer runs unattended until the backlog is clear or a stop condition trips.

---

## How to Start

```
--agent issue-groomer
```

The agent is invoked from the coordinator. After invocation it runs unattended.

### Invocation Arguments

All arguments are optional. Defaults are shown.

| Argument | Default | Description |
|----------|---------|-------------|
| `max_issues_per_run` | `5` | Maximum goals completed before the run stops cleanly. |
| `attempt_budget` | `3` | Maximum RETRY/re-delegation cycles per issue. Counts only retries after a failure — the normal happy-path (claim → ground → draft → readiness-gate → write) does NOT consume it. If exhausted, the groomer executes the FAILURE/ROLLBACK path (`groom_status:failed`), releases the claim, and continues to the next issue. |
| `poll_interval` | `15m` | Time between re-checks in WATCH mode after the backlog is exhausted. |
| `target_repo` | _(current repo)_ | Path or GitHub slug of the repo to work in. When set, every `gh issue list / view / edit / comment` invocation carries `--repo "$target_repo"` (for slugs) or `cd`s into the path (for local paths). All gh operations are scoped to `target_repo` — a slug invocation acts on that repo, not the current working directory. |
| `watch` | `false` | WATCH mode activates ONLY when `watch: true` is explicitly passed. The default is one-shot/terminating. If true, after backlog exhaustion the groomer sleeps `poll_interval` and re-checks for new issues. |

### Examples

**Default run — work up to 5 status-less issues:**

```
--agent issue-groomer
```

**Cautious first run — work exactly one issue, then stop:**

```
--agent issue-groomer max_issues_per_run=1
```

**Point at a different repo:**

```
--agent issue-groomer target_repo=owner/repo max_issues_per_run=1
```

**Run in WATCH mode (re-check every 15 minutes for new issues):**

```
--agent issue-groomer watch=true
```

---

## Preconditions

Before starting the agent, verify:

1. **`gh` is authenticated** — `gh auth status` must show an active account with repo write access.

2. **The four required labels exist** in the target repo. Create them with:

   ```bash
   gh label create "status:grooming" --color "BFD4F2" --description "Currently being groomed"
   gh label create "status:ready"    --color "0E8A16" --description "Groomed and ready for autonomous implementation"
   gh label create "status:blocked"  --color "D93F0B" --description "Exhaustively groomed but a path-decision needs a human"
   gh label create "status:kill"     --color "000000" --description "Kill switch — stop issue-groomer at this issue"
   ```

   Note: `status:in-progress` belongs to the implementer, not the groomer. The groomer never applies that label.

3. **`.github/ISSUE_TEMPLATE/` is present** in the target repo — the groomer reads the template(s) to know the required output format. If no template directory exists, the groomer falls back to the canonical feature-ticket format (behavior contract + integration spec + DoD + in/out-of-scope + regression risks + deploy/doc impact) and records `template_used: "fallback: feature-ticket-format"`. A missing template is NOT a blocked reason.

4. **SEQUENTIAL / SINGLE-INSTANCE ONLY** — never run two issue-groomer instances against the same repo at the same time. The claim operation (`status:grooming` label + self-assign) is not truly atomic. Two concurrent instances can double-pick the same issue and produce conflicting groomed bodies. V1 is sequential only; distributed locking is a v2 concern.

---

## The Label Contract / Full Pipeline

Labels are the handshake between the groomer and the implementer.

```
open (no status)
  → [GROOMER claims]    status:grooming
  → [GROOMER writes]    status:ready        (clear path — claimable by implementer)
                     OR status:blocked      (exhaustively groomed, path-decision needed)
                     OR status:grooming removed + unassigned   (failed — operational error, retryable next run)

status:ready
  → [IMPLEMENTER claims] status:in-progress
  → PR (Closes #N)       → issue closed by GitHub on merge

status:blocked
  → human or review-agent resolves → may transition back to status:ready
```

`status:ready` is the **handoff label** between the groomer and the implementer.

| Label | Applied by | Meaning |
|-------|-----------|---------|
| `status:grooming` | issue-groomer (claim phase) | Currently being groomed; issue is assigned to the agent. |
| `status:ready` | issue-groomer (write phase) | Claimable by the implementer — behavior contract, DoD, and full spec are complete. |
| `status:blocked` | issue-groomer (write phase) | Exhaustively groomed but a genuine product/path decision needs a human before implementation can proceed. The issue body contains full analysis and a recommendation. |
| `status:in-progress` | issue-implementer | Currently being implemented (applied by the implementer, not the groomer). |
| `status:kill` | Human or any agent | Emergency stop — a repo-wide precheck at the start of each `select` cycle halts the run immediately if ANY open issue carries this label. Apply to any issue to stop the groomer cleanly. |

---

## What You Get

For each groomed issue the agent rewrites the issue body to include:

- **Testable Given/When/Then behavior contract** — specific and implementer-actionable, not vague.
- **Verified file paths and integration spec** — real paths confirmed against the actual codebase, with what calls what and what data flows where.
- **In-scope / out-of-scope** — explicit boundaries so the implementer knows exactly what to build and what to defer.
- **Regression risks and deploy/doc impact** — what could break, what docs need updating.
- **Checkable Definition of Done** — each item verifiable, not aspirational.
- **`assumptions_made`** — for every gap in the original issue: what was assumed and why (rationale required).
- **`alternatives_considered`** — for every significant design choice: options analyzed, recommended path stated with rationale.
- **`ui_ux_notes`** — how the change should feel to the user, error states, loading states, non-breaking UX invariants, accessibility notes.

**`status:ready`** means the implementer can pick up the issue without any human interaction. The groomer has made every resolvable decision.

**`status:blocked`** means the issue is **fully groomed** — not half-done. It means a genuine strategic product/path decision remains that requires human input. The issue body contains the complete analysis, all alternatives with pros/cons, and the groomer's recommendation. The blocked issue is as ready as it can be without that decision. `blocked` is RARE and reserved for genuine strategic choices — never for technical gaps, incomplete specs, or operational failures.

**`groom_status:failed`** (fifth outcome) means an operational or tooling failure occurred — a tool error, network failure, or `attempt_budget` (retry cycle) exhaustion. This is NOT a product decision. On `failed`, the groomer releases the claim: it removes `status:grooming` and unassigns the issue, returning it to status-less so the next run can retry it automatically. `failed` issues are NOT human-gated. The key distinction:

| Outcome | Cause | Human gate? | Issue state after |
|---------|-------|-------------|-------------------|
| `status:ready` | Clear implementation path | No | Claimable by implementer |
| `status:blocked` | Genuine product/path DECISION needed | Yes | Awaits human resolution |
| `groom_status:failed` | Operational failure or retry exhaustion | No | Returns to status-less; auto-retried next run |

---

## Autonomy Posture

The groomer operates with **maximum autonomy**. It resolves technical gaps by reading the codebase, filling spec gaps with documented assumptions, and researching external APIs. It never stops to ask the user for confirmation mid-run.

The groomer's escalation path (`status:blocked`) is **rare and reserved for genuine strategic decisions** — a real choice between multiple valid but conflicting directions where the product direction is unknown (for example, "store user data in DO SQLite vs R2 — different persistence tradeoffs, product direction unclear"). It is NOT for:

- Technical gaps the groomer can resolve by reading the code deeper.
- Incomplete specs — fill them with documented assumptions.
- Multiple valid implementation approaches — document them, recommend one, mark `status:ready`.
- Missing file paths — verify against the actual codebase.

If uncertain whether to block, the groomer defaults to `status:ready` with thoroughly documented assumptions. The goal is a backlog of claimable issues, not a backlog in human review.

---

## WATCH Mode

WATCH mode activates **ONLY when `watch: true` is explicitly passed** at invocation. It does NOT activate implicitly. The default is one-shot/terminating.

When the groomable backlog is empty, behavior depends on whether WATCH mode is active:

**One-shot mode (default, `watch=false`):**
The groomer emits a permanent terminal output with `run_stop_reason: "no_status_less_issues"` and exits. No re-check is scheduled.

**WATCH mode (`watch=true`):**
The groomer emits a transient terminal output with `run_stop_reason: "watch_poll_wait"` (this is NOT a permanent stop), sleeps `poll_interval` (default: 15m), then **resets per-run state** (`reviewed_ready_this_run` to empty, `issues_completed_this_run` to 0), and returns to `select` to check for new issues. Each wake-up cycle is a fresh cycle — state reset ensures ready tickets that may have changed are re-reviewed and prevents within-cycle spin.

Downstream consumers must distinguish `watch_poll_wait` (transient — re-check coming) from `no_status_less_issues` (permanent — backlog exhausted in one-shot mode).

**In-process sleep is the v1 mechanism.** The Claude Code agent loop is reliable for this purpose at typical `poll_interval` values.

**External cron / scheduled re-invocation is the recommended production alternative.** For unattended long-running deployments, schedule `--agent issue-groomer` via an external cron job or GitHub Actions scheduled workflow. Each run terminates cleanly with `no_status_less_issues` or `max_issues_reached` after processing available issues. This avoids in-process sleep entirely and is more robust at scale:

```yaml
# Example: GitHub Actions scheduled groomer
on:
  schedule:
    - cron: '*/15 * * * *'  # every 15 minutes
```

---

## Stop Conditions

The run ends and emits `groom_status: "terminal"` when any of the following trip:

| `run_stop_reason` | When |
|-------------------|------|
| `max_issues_reached` | Completed `max_issues_per_run` goals (default: 5); stopping cleanly. Re-run to continue. |
| `kill_switch` | A repo-wide precheck at the START of each `select` cycle found an open issue carrying `status:kill` — OR a TOCTOU re-fetch before claim found `status:kill`. Stops immediately, terminally. Human intervention required before re-run. The precheck runs before any candidate is fetched, so `status:kill` on ANY open issue halts the run — not only the next candidate. |
| `no_status_less_issues` | **Permanent terminal (one-shot mode):** backlog is exhausted — no more status-less issues to groom. No re-check scheduled. |
| `watch_poll_wait` | **Transient terminal (WATCH mode):** groomer is entering a sleep cycle. Re-check will run after `poll_interval`. This is NOT a permanent stop. |

### `groom_status: "failed"` — per-issue operational failure (NOT a run-stop event)

`groom_status: "failed"` is emitted when an OPERATIONAL or tooling failure occurs for a single issue — a tool error, network failure, or `attempt_budget` (retry cycle) exhaustion. This is distinct from `blocked` (which requires a genuine product decision) and from `terminal` (which stops the whole run).

On `failed`, the groomer executes the FAILURE/ROLLBACK path:
1. Removes `status:grooming` and unassigns the issue — returning it to status-less.
2. Posts a comment explaining the failure.
3. Emits `groom_status: "failed"` with a `failure_reason`.
4. Continues to the next issue (NOT a run-stop event).

The issue is automatically retried on the next run without human intervention.

### `attempt_budget` — retry cycles only

`attempt_budget` (default: 3) counts ONLY retry/re-delegation cycles per issue — not first-pass phase delegations. The normal happy path (claim → ground → draft → readiness-gate → write) does NOT consume it. The budget increments only when the agent returns to a prior phase after a failure. If exhausted: execute the FAILURE/ROLLBACK path, emit `groom_status: "failed"`, and continue to the next issue. Do NOT emit `groom_status: "blocked"` for budget exhaustion — `blocked` requires a genuine product decision, not an operational limit.

---

## First-Run Guidance

1. Create one open issue (no status labels) in a test repo. Give it a minimal title and a one-line description — intentionally under-specified, to see what the groomer produces.
2. Verify the required labels exist in that repo (see Preconditions above).
3. Invoke with `max_issues_per_run=1` so the agent works exactly that one issue and stops:
   ```
   --agent issue-groomer max_issues_per_run=1
   ```
4. Watch the full cycle: startup → select → claim (`status:grooming` appears) → ground → draft → readiness-gate → write (`status:ready` or `status:blocked` appears).
5. Inspect the groomed issue body — verify the behavior contract, assumptions, alternatives, DoD checklist, and verified file paths.
6. Once satisfied with the output quality, remove the `max_issues_per_run=1` override and let the agent sweep the full backlog.

**Kill switch as emergency stop:** if the agent is mid-run and you need it to stop, apply the `status:kill` label to any open issue in the repo. At the start of the **next `select` cycle** (before any candidate is fetched), the agent runs a repo-wide precheck for any open `status:kill` issue and stops immediately with `run_stop_reason: "kill_switch"`. The kill switch applies to the whole run — not just the next candidate — because the precheck scans all open issues in the repo, not just the pending queue.

---

## Startup Behavior

At startup, before processing any issues, the groomer performs a **stale-claim sweep**: it queries for open issues labeled `status:grooming` that are assigned to the agent and older than a threshold (e.g., 30 minutes). For each stale claim found, it removes the `status:grooming` label, unassigns the issue, and posts a comment noting "Released stale grooming claim from prior interrupted run." This sweep prevents transient failures (network errors, interrupted runs) from permanently stranding issues in the `status:grooming` state.

---

## Known Limitations (V1)

- **Pagination:** the `select` phase uses `--limit 200` (or `--limit 9999` for larger backlogs), but very large repos with more than 200 open issues may not see all issues in a single run. This is a documented v1 constraint. For backlogs exceeding 200 open issues, raise the `--limit` value or document the limitation explicitly. The agent will process the oldest issues within the limit first.

---

## Deferred / Not in V1

- **Parallel runs:** running multiple issue-groomer instances concurrently against the same repo requires a distributed lock. This is a v2 concern. V1 is sequential / single-instance only.
- **External cron as first-class invocation mode:** the v1 in-process sleep is sufficient; external cron is documented above as the recommended production alternative but not built-in to the agent.
