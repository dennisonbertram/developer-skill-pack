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

# Create a temp directory that is cleaned up on exit.
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

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
BROKEN_FILE="$TMPDIR_TEST/broken.json"
cat > "$BROKEN_FILE" <<'ENDJSON'
{
  "goal_id": "g1",
  "issue_number": 1,
  "issue_url": "https://example.com/issues/1",
  "loop_status": "completed",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "files_changed": ["/abs/path/file.ts"],
  "behavioral_tests": [
    { "spec_id": "BT-001", "description": "works", "status": "pass" }
  ],
  "blocked": false,
  "recommended_next_step": "done"
}
ENDJSON
# Note: pr_url is intentionally omitted to trigger a schema validation failure (exit 1).
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$BROKEN_FILE" 2>&1); rc=$?
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
VALID_WORKER_FILE="$TMPDIR_TEST/valid-worker.json"
cat > "$VALID_WORKER_FILE" <<'ENDJSON'
{
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
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate worker "$VALID_WORKER_FILE" 2>&1); rc=$?
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
