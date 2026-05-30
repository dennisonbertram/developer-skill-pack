# Regression Notes: issue-groomer-output.schema.json

Mutation checks run against all three groomer fixtures using
`ajv` (the coord-validate preferred backend) via `bash test/issue-groomer-schema.test.sh`.

These checks verify that the schema enforces per-`groom_status` variant constraints
and would catch future regressions if field requirements, enum values, or conditional
blocks were loosened or removed.

## Results (all verified, 2026-05-30; updated with failed-variant, 2026-05-30)

| Check | Mutation | Expected | Result |
|-------|----------|----------|--------|
| PASS-1 | Valid ready fixture (no mutation) | exit 0 | OK, Exit 0 |
| PASS-2 | Valid blocked fixture (no mutation) | exit 0 | OK, Exit 0 |
| PASS-3 | Valid terminal fixture (no mutation) | exit 0 | OK, Exit 0 |
| PASS-4 | Minimal skipped shape (goal_id, groom_status, issue_number, issue_url, skip_reason, recommended_next_step) | exit 0 | OK, Exit 0 |
| PASS-5 | Valid failed fixture (goal_id, groom_status, issue_number, issue_url, failure_reason, recommended_next_step — no alternatives/codebase_grounding) | exit 0 | OK, Exit 0 |
| FAIL-1 | blocked output missing `escalation_reason` | exit 1 | FAIL `escalation_reason` is required |
| FAIL-2 | blocked output with `alternatives_considered: []` | exit 1 | FAIL minItems: 1 |
| FAIL-3 | terminal output missing `run_stop_reason` | exit 1 | FAIL `run_stop_reason` is required |
| FAIL-4 | ready output missing `codebase_grounding` | exit 1 | FAIL `codebase_grounding` is required |
| FAIL-5 | `run_stop_reason: "unknown_stop_reason_value"` | exit 1 | FAIL not one of enum values |
| FAIL-6 | skipped output missing `skip_reason` | exit 1 | FAIL `skip_reason` is required |
| FAIL-7 | `groom_status: "unknown_value"` | exit 1 | FAIL not one of [ready,blocked,skipped,terminal,failed] |
| FAIL-8 | blocked output with `escalation_reason: ""` | exit 1 | FAIL minLength: 1 |
| FAIL-9 | failed output missing `failure_reason` | exit 1 | FAIL `failure_reason` is required |
| FAIL-10 | failed output with `failure_reason: ""` | exit 1 | FAIL minLength: 1 |
| FAIL-11 | failed output missing `issue_number` | exit 1 | FAIL `issue_number` is required |

## The F1 lesson: flat required lists break terminal/skipped emittability

The original issue-implementer schema shipped with a flat top-level `required` list
that included claimed-issue fields (`issue_number`, `issue_url`, `claim_evidence`).
This made the `terminal` variant unemittable because those fields are absent when
no issue was claimed.

The groomer schema applies this lesson from the start:

- Top-level `required` is exactly `[goal_id, groom_status, recommended_next_step]`.
- Per-variant required sets are enforced via `allOf` + `if/then` blocks keyed on `groom_status`.
- Terminal emittability: BT-G03 proves terminal validates with ONLY `goal_id`, `groom_status`,
  `run_stop_reason`, and `recommended_next_step` — no `issue_number`, no `claim_evidence`.
- Skipped emittability: BT-G07 proves skipped validates with ONLY `goal_id`, `groom_status`,
  `issue_number`, `issue_url`, `skip_reason`, and `recommended_next_step` — no `codebase_grounding`.

## Per-variant required field sets (canonical reference for TASK-G2 handoff)

### groom_status: "ready"
```
goal_id, groom_status, issue_number, issue_url, claim_evidence, template_used,
codebase_grounding, dor_checklist_results, assumptions_made, alternatives_considered,
ui_ux_notes, recommended_next_step
```

### groom_status: "blocked"
All of "ready" PLUS:
```
escalation_reason (minLength:1), alternatives_considered (minItems:1)
```

### groom_status: "skipped"
```
goal_id, groom_status, issue_number, issue_url, skip_reason, recommended_next_step
```

### groom_status: "terminal"
```
goal_id, groom_status, run_stop_reason (enum: max_issues_reached|kill_switch|no_status_less_issues|watch_poll_wait), recommended_next_step
```

### groom_status: "failed" (canonical reference for TASK-G5 handoff)
```
goal_id, groom_status, issue_number, issue_url, failure_reason (minLength:1), recommended_next_step
```
NOT required (and must not be required): alternatives_considered, codebase_grounding,
claim_evidence, template_used, dor_checklist_results, assumptions_made, ui_ux_notes,
escalation_reason, skip_reason, run_stop_reason.

The `failed` variant is for operational/budget exhaustion ONLY — it is not a product
decision. Use `blocked` when a genuine human product decision is needed (that variant
requires alternatives_considered minItems:1 to prove exhaustive grooming happened).

## run_stop_reason semantics

- `no_status_less_issues` — permanent terminal: backlog exhausted in one-shot mode. No more issues.
- `watch_poll_wait` — transient terminal: groomer is entering a WATCH-mode sleep cycle. Re-check scheduled after `poll_interval`. Downstream consumers must distinguish this from `no_status_less_issues`.
- `max_issues_reached` — `max_issues_per_run` limit hit. Run again to continue.
- `kill_switch` — `status:kill` label detected. Human intervention required before re-running.

## Note on `format: uri` enforcement

The `format: uri` annotation on `issue_url` is not enforced as a hard constraint by
the Python `jsonschema` library (the coord-validate fallback backend). This is per the
JSON Schema spec: `format` is optional/informational unless the validator is explicitly
configured to enforce it. When `ajv` is available (preferred), it enforces `format: uri`.
