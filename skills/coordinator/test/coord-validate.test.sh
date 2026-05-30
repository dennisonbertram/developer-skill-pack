#!/usr/bin/env bash
# coord-validate.test.sh — behavioral tests for the coord-validate script.
#
# Run from any directory — the script resolves its own location.
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -uo pipefail

# Resolve the directory containing this test file so tests run from anywhere.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORD_DIR="$(cd "$SELF_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

run_validate() {
  # run_validate <agent> <input>
  # Runs coord-validate from COORD_DIR, returns exit code.
  local agent="$1"
  local input="$2"
  (cd "$COORD_DIR" && ./coord-validate "$agent" "$input" 2>&1)
}

run_validate_stdin() {
  # run_validate_stdin <agent> <json_string>
  # Passes JSON via stdin to coord-validate, returns exit code.
  local agent="$1"
  local json="$2"
  (cd "$COORD_DIR" && printf '%s' "$json" | ./coord-validate "$agent" - 2>&1)
}

echo ""
echo "coord-validate tests"
echo "===================="

# --- BT-001: valid issue-implementer fixture exits 0 ---
# When coord-validate is given the known-valid fixture for issue-implementer,
# it must exit 0 (validation success, schema found and data valid).
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer schemas/fixtures/issue-implementer-output-example.json 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-001: valid issue-implementer fixture exits 0"
else
  fail "BT-001: valid issue-implementer fixture exits 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-002: invalid JSON (missing required field pr_url) exits 1 ---
# When given JSON that is syntactically valid but missing a required field
# (pr_url), coord-validate must exit 1 (schema validation failure), not 2
# (schema not found). Exit 2 here would indicate the path-not-found bug.
BROKEN_JSON='{"goal_id":"g1","issue_number":1,"issue_url":"https://example.com/issues/1","loop_status":"completed","claim_evidence":{},"files_changed":[],"audit_trail_commits":{"red":{"hash":"aaa1111","subject":"s"},"green":{"hash":"bbb2222","subject":"s"},"regression":{"hash":"ccc3333","subject":"s"}},"tdd_evidence":{"failing_before_implementation":"x","passing_after_implementation":"x","full_suite_at_regression":"x"},"behavioral_tests":[],"regression_tests":[],"dod_checklist_results":[],"blocked":false,"recommended_next_step":"done"}'
# Note: pr_url is intentionally omitted to trigger a schema validation failure.
out=$(cd "$COORD_DIR" && printf '%s' "$BROKEN_JSON" | ./coord-validate issue-implementer - 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-002: invalid doc (missing pr_url) exits 1"
else
  fail "BT-002: invalid doc (missing pr_url) exits 1" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-003: unknown agent exits 2 ---
# When given an agent name with no corresponding schema file, coord-validate
# must exit 2 (schema not found), not 0 or 1.
out=$(cd "$COORD_DIR" && ./coord-validate nonexistent-agent /dev/null 2>&1); rc=$?
if [ "$rc" -eq 2 ]; then
  pass "BT-003: unknown agent exits 2"
else
  fail "BT-003: unknown agent exits 2" \
       "expected exit 2, got exit $rc — output: $out"
fi

# --- BT-004: valid worker JSON exits 0 (not issue-implementer-specific) ---
# Verify schema resolution works for the worker agent — proves the fix is
# not hard-coded to issue-implementer but resolves any schema correctly.
VALID_WORKER_JSON='{
  "task_id": "TASK-001",
  "task_type": "feature",
  "scope_completed": ["Added feature X"],
  "audit_trail_commits": {
    "red":        {"hash": "aaa1111", "subject": "test(red): failing tests"},
    "green":      {"hash": "bbb2222", "subject": "feat: implement feature"},
    "regression": {"hash": "ccc3333", "subject": "test(regression): regression coverage"}
  },
  "tdd_evidence": {
    "failing_before_implementation": "FAIL: expected X got Y",
    "passing_after_implementation": "PASS: 1 test passed",
    "full_suite_at_regression": "Tests: 5 passed, 5 total"
  },
  "behavioral_tests": [
    {"spec_id": "BT-001", "description": "feature works", "status": "pass"}
  ],
  "regression_tests": [
    {"test_name": "regression-1", "catches": "Would fail if feature reverted"}
  ],
  "files_changed": ["/abs/path/src/feature.ts"],
  "invariants_or_assumptions": ["stateless"],
  "risks_or_blockers": [],
  "recommended_next_step": "Ship it"
}'
out=$(cd "$COORD_DIR" && printf '%s' "$VALID_WORKER_JSON" | ./coord-validate worker - 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-004: valid worker JSON exits 0 (schema resolution is agent-agnostic)"
else
  fail "BT-004: valid worker JSON exits 0 (schema resolution is agent-agnostic)" \
       "expected exit 0, got exit $rc — output: $out"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
