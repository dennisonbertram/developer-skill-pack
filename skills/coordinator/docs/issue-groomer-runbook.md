# Issue Groomer Runbook

Authoritative how-to for the `issue-groomer` autonomous backlog agent.

---

## Overview

The issue-groomer is the producer counterpart to `issue-implementer`. It sweeps a repo's GitHub issue backlog and turns under-specified issues into fully-specified, implementer-ready issues — unattended, with no human interaction mid-run.

For each status-less issue, the groomer:

1. **Claims** the issue (adds `status:grooming`, self-assigns).
2. **Grounds itself** against the codebase, product docs, and external API docs — reading real file paths, integration points, and user intent.
3. **Drafts** an exhaustive issue body that follows the target repo's issue template: testable behavior contract, verified file paths, integration spec, in/out-of-scope, regression risks, DoD checklist, documented assumptions, alternatives considered, UI/UX notes.
4. **Applies** `status:ready` (clear implementation path — claimable by the implementer immediately) or `status:blocked` (exhaustively groomed, a genuine product/path decision needs a human).
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
| `attempt_budget` | `3` | Total delegate cycles per issue across all phases. If exhausted, the issue is marked `status:blocked` (with budget-exhaustion reason) and the run continues to the next issue. |
| `poll_interval` | `15m` | Time between re-checks in WATCH mode after the backlog is exhausted. |
| `target_repo` | _(current repo)_ | Path or GitHub slug of the repo to work in. |
| `watch` | `false` | If true, enter WATCH mode after backlog exhaustion — sleep `poll_interval`, then re-check for new issues. |

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
| `status:kill` | Human or any agent | Emergency stop — the groomer will not claim this issue or any subsequent one. |

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

**`status:blocked`** means the issue is **fully groomed** — not half-done. It means a genuine strategic product/path decision remains that requires human input. The issue body contains the complete analysis, all alternatives with pros/cons, and the groomer's recommendation. The blocked issue is as ready as it can be without that decision.

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

When the groomable backlog is empty, behavior depends on whether WATCH mode is active:

**One-shot mode (default, `watch=false`):**
The groomer emits a permanent terminal output with `run_stop_reason: "no_status_less_issues"` and exits. No re-check is scheduled.

**WATCH mode (`watch=true`):**
The groomer emits a transient terminal output with `run_stop_reason: "watch_poll_wait"` (this is NOT a permanent stop), sleeps `poll_interval` (default: 15m), then returns to `select` to check for new issues.

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
| `kill_switch` | Candidate issue carried `status:kill`; stopping cleanly. Human intervention required before re-run. |
| `no_status_less_issues` | **Permanent terminal (one-shot mode):** backlog is exhausted — no more status-less issues to groom. No re-check scheduled. |
| `watch_poll_wait` | **Transient terminal (WATCH mode):** groomer is entering a sleep cycle. Re-check will run after `poll_interval`. This is NOT a permanent stop. |

A per-issue attempt budget exhaustion (`attempt_budget` exceeded for a single issue) is NOT a run-stop event. The groomer marks that issue `status:blocked` with the budget-exhaustion reason and immediately continues to the next issue.

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

**Kill switch as emergency stop:** if the agent is mid-run and you need it to stop after the current issue completes, apply the `status:kill` label to any issue in the queue. The agent checks for it at the next `select` phase and exits cleanly.

---

## Deferred / Not in V1

- **Parallel runs:** running multiple issue-groomer instances concurrently against the same repo requires a distributed lock. This is a v2 concern. V1 is sequential / single-instance only.
- **External cron as first-class invocation mode:** the v1 in-process sleep is sufficient; external cron is documented above as the recommended production alternative but not built-in to the agent.
