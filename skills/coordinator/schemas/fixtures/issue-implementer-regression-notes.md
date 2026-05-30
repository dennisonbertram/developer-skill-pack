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

## Known limitation: coord-validate path resolution

`coord-validate` resolves `SCHEMAS_DIR` as `$SCRIPT_DIR/../schemas`
(`skills/schemas/`), but schemas live at `skills/coordinator/schemas/`. This
means `coord-validate` cannot find the schema when run as documented. Validation
was performed via `python3 jsonschema` (the same backend coord-validate uses as
its third-priority fallback). This is a pre-existing issue in the coord-validate
script and is out of scope for TASK-001.
