#!/usr/bin/env bash
# issue-implementer-schema.test.sh — per-variant schema validation tests.
#
# Tests the issue-implementer-output schema enforces per-loop_status variant
# requirements: completed, blocked, terminal each have distinct required fields
# and cross-field constraints (blocked const, pr_url null/non-null).
#
# Run from any directory — the script resolves its own location.
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORD_DIR="$(cd "$SELF_DIR/.." && pwd)"
FIXTURES_DIR="$COORD_DIR/schemas/fixtures"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

echo ""
echo "issue-implementer schema variant tests"
echo "======================================="

# --- BT-S01: existing completed fixture still validates (exit 0) ---
# The completed fixture is the canonical happy path. It must continue to pass
# after any schema rework.
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$FIXTURES_DIR/issue-implementer-output-example.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-S01: completed fixture (loop_status:completed) validates -> exit 0"
else
  fail "BT-S01: completed fixture (loop_status:completed) validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-S02: blocked fixture with behavioral_tests:[] validates (exit 0) ---
# A blocked goal has no implemented tests (empty array). The schema MUST allow
# behavioral_tests:[] for loop_status:blocked (F1 bug fix).
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$FIXTURES_DIR/issue-implementer-output-blocked.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-S02: blocked fixture (blocked:true, behavioral_tests:[]) validates -> exit 0"
else
  fail "BT-S02: blocked fixture (blocked:true, behavioral_tests:[]) validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-S03: terminal fixture with no claimed-issue fields validates (exit 0) ---
# A terminal goal has no issue_number, issue_url, claim_evidence, behavioral_tests.
# The schema MUST allow these to be absent for loop_status:terminal (F1 bug fix).
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$FIXTURES_DIR/issue-implementer-output-terminal.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-S03: terminal fixture (no claimed-issue fields) validates -> exit 0"
else
  fail "BT-S03: terminal fixture (no claimed-issue fields) validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-S04: blocked goal missing blocked_reason fails (exit 1) ---
# When loop_status:blocked, blocked_reason is required. Omitting it must fail.
BLOCKED_NO_REASON="$TMPDIR_TEST/blocked-no-reason.json"
cat > "$BLOCKED_NO_REASON" <<'ENDJSON'
{
  "goal_id": "goal-invalid-01",
  "issue_number": 10,
  "issue_url": "https://github.com/acme/myapp/issues/10",
  "loop_status": "blocked",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "blocked": true,
  "pr_url": null,
  "recommended_next_step": "Investigate the blocker."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$BLOCKED_NO_REASON" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-S04: blocked goal missing blocked_reason -> exit 1 (validation failure)"
else
  fail "BT-S04: blocked goal missing blocked_reason -> exit 1 (validation failure)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-S05: completed goal with pr_url:null fails (exit 1) ---
# For loop_status:completed, pr_url MUST be a non-null URI (F8 cross-field fix).
COMPLETED_NULL_PR="$TMPDIR_TEST/completed-null-pr.json"
cat > "$COMPLETED_NULL_PR" <<'ENDJSON'
{
  "goal_id": "goal-invalid-02",
  "issue_number": 20,
  "issue_url": "https://github.com/acme/myapp/issues/20",
  "loop_status": "completed",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "files_changed": ["/abs/path/file.ts"],
  "audit_trail_commits": {
    "red":        { "hash": "aaa1111", "subject": "test(red): failing tests" },
    "green":      { "hash": "bbb2222", "subject": "feat: implement feature" },
    "regression": { "hash": "ccc3333", "subject": "test(regression): regression coverage" }
  },
  "tdd_evidence": {
    "failing_before_implementation": "FAIL: test failed",
    "passing_after_implementation": "PASS: test passed",
    "full_suite_at_regression": "Tests: 5 passed, 5 total"
  },
  "behavioral_tests": [
    { "spec_id": "BT-001", "description": "feature works", "status": "pass" }
  ],
  "dod_checklist_results": [
    { "item": "Tests pass", "status": "pass" }
  ],
  "blocked": false,
  "pr_url": null,
  "recommended_next_step": "Review the PR."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$COMPLETED_NULL_PR" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-S05: completed goal with pr_url:null -> exit 1 (cross-field validation failure)"
else
  fail "BT-S05: completed goal with pr_url:null -> exit 1 (cross-field validation failure)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-S06: completed goal with behavioral_tests:[] fails (exit 1) ---
# For loop_status:completed, behavioral_tests minItems:1 must be enforced.
COMPLETED_EMPTY_BT="$TMPDIR_TEST/completed-empty-bt.json"
cat > "$COMPLETED_EMPTY_BT" <<'ENDJSON'
{
  "goal_id": "goal-invalid-03",
  "issue_number": 30,
  "issue_url": "https://github.com/acme/myapp/issues/30",
  "loop_status": "completed",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "files_changed": ["/abs/path/file.ts"],
  "audit_trail_commits": {
    "red":        { "hash": "aaa1111", "subject": "test(red): failing tests" },
    "green":      { "hash": "bbb2222", "subject": "feat: implement feature" },
    "regression": { "hash": "ccc3333", "subject": "test(regression): regression coverage" }
  },
  "tdd_evidence": {
    "failing_before_implementation": "FAIL: test failed",
    "passing_after_implementation": "PASS: test passed",
    "full_suite_at_regression": "Tests: 5 passed, 5 total"
  },
  "behavioral_tests": [],
  "dod_checklist_results": [
    { "item": "Tests pass", "status": "pass" }
  ],
  "blocked": false,
  "pr_url": "https://github.com/acme/myapp/pull/31",
  "recommended_next_step": "Review the PR."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$COMPLETED_EMPTY_BT" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-S06: completed goal with behavioral_tests:[] -> exit 1 (minItems enforcement)"
else
  fail "BT-S06: completed goal with behavioral_tests:[] -> exit 1 (minItems enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-S07: terminal goal with a pr_url string fails (exit 1) ---
# For loop_status:terminal, pr_url MUST be null (F8 cross-field fix).
TERMINAL_WITH_PR="$TMPDIR_TEST/terminal-with-pr.json"
cat > "$TERMINAL_WITH_PR" <<'ENDJSON'
{
  "goal_id": "goal-invalid-04",
  "loop_status": "terminal",
  "run_stop_reason": "no_ready_issues",
  "pr_url": "https://github.com/acme/myapp/pull/99",
  "recommended_next_step": "Backlog is exhausted."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-implementer "$TERMINAL_WITH_PR" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-S07: terminal goal with pr_url set -> exit 1 (cross-field validation failure)"
else
  fail "BT-S07: terminal goal with pr_url set -> exit 1 (cross-field validation failure)" \
       "expected exit 1, got exit $rc — output: $out"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
