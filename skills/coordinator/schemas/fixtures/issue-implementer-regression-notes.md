# Regression Notes: issue-implementer-output.schema.json

Mutation checks run against `issue-implementer-output-example.json` using
`python3 jsonschema.Draft202012Validator` (the coord-validate fallback backend).

These checks verify that the schema enforces its constraints and would catch
future regressions if field requirements or enum values were loosened.

## Results (all verified, 2026-05-30)

| Check | Mutation | Expected | Result |
|-------|----------|----------|--------|
| PASS-1 | Valid fixture (no mutation) | exit 0 | OK, Exit 0 |
| FAIL-1 | Remove `pr_url` | exit 1 | FAIL `pr_url` is required |
| FAIL-2 | `loop_status: "done"` | exit 1 | FAIL not one of [completed,blocked,terminal] |
| FAIL-3 | `blocked: true`, no `blocked_reason` | exit 1 | FAIL `blocked_reason` is required |
| PASS-2 | `blocked: false`, no `blocked_reason` | exit 0 | OK, Exit 0 |
| FAIL-4 | `behavioral_tests[0].status: "pending"` | exit 1 | FAIL not one of [pass,fail] |
| PASS-3 | `blocked: true` WITH `blocked_reason` | exit 0 | OK, Exit 0 |
| PASS-4 | `pr_url: null` (blocked case) | exit 0 | OK, Exit 0 |
| PASS-5 | `run_stop_reason: "max_issues_reached"` | exit 0 | OK, Exit 0 |
| FAIL-5 | `run_stop_reason: "timeout"` (invalid) | exit 1 | FAIL not valid under any given schemas |

## Note on `format: uri` enforcement

The `format: uri` annotation on `pr_url` and `issue_url` is not enforced as a
hard constraint by the python `jsonschema` library (the validator used by
`coord-validate` when `ajv` is unavailable). This is per the JSON Schema spec:
`format` is optional/informational unless the validator is explicitly configured
to enforce it. The `required` constraint on `pr_url` IS enforced (FAIL-1 above).

If `ajv` is available, it enforces `format: uri` by default via `--strict=false`
in the coord-validate invocation.

## coord-validate path resolution (fixed)

`coord-validate` correctly resolves `SCHEMAS_DIR` as `$SCRIPT_DIR/../schemas`
which points to `skills/coordinator/schemas/` — where the schemas live.
This was fixed in commit 76bc0fe (TASK-001b): the script now derives its path
from its own location so it works from any working directory. The stale note
claiming this was broken and out-of-scope is no longer accurate.
