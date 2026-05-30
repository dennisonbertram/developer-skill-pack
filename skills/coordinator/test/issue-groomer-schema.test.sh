#!/usr/bin/env bash
# issue-groomer-schema.test.sh — per-variant schema validation tests.
#
# Tests the issue-groomer-output schema enforces per-groom_status variant
# requirements: ready, blocked, skipped, and terminal each have distinct
# required fields and cross-field constraints.
#
# The F1 lesson applied here: terminal and skipped must be emittable without
# claimed-issue fields (issue_number, claim_evidence, codebase_grounding, etc.).
# If the schema used a flat top-level required list that included those fields,
# terminal and skipped would be unemittable — this test suite catches that bug.
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
echo "issue-groomer schema variant tests"
echo "===================================="

# --- BT-G01: ready fixture validates (exit 0) ---
# The ready fixture is the canonical happy path — a fully groomed issue with
# clear implementation path. Must pass schema validation.
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FIXTURES_DIR/issue-groomer-output-ready.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-G01: ready fixture (groom_status:ready) validates -> exit 0"
else
  fail "BT-G01: ready fixture (groom_status:ready) validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-G02: blocked fixture validates (exit 0) ---
# A blocked goal is exhaustively groomed with escalation_reason and at least
# one documented alternative. Must pass schema validation.
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FIXTURES_DIR/issue-groomer-output-blocked.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-G02: blocked fixture (groom_status:blocked) validates -> exit 0"
else
  fail "BT-G02: blocked fixture (groom_status:blocked) validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-G03: terminal fixture with no claimed-issue fields validates (exit 0) ---
# The F1 lesson: terminal has no issue_number, issue_url, claim_evidence,
# codebase_grounding, or other claimed-issue fields. If the schema had a flat
# required list including those fields, this test would fail (exit 1 or exit 2).
# Terminal must be emittable with ONLY goal_id, groom_status, run_stop_reason,
# and recommended_next_step.
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FIXTURES_DIR/issue-groomer-output-terminal.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-G03: terminal fixture (no claimed-issue fields) validates -> exit 0"
else
  fail "BT-G03: terminal fixture (no claimed-issue fields) validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-G04: blocked output missing escalation_reason fails (exit 1) ---
# When groom_status:blocked, escalation_reason is required and must have
# minLength:1. Omitting it must fail schema validation.
BLOCKED_NO_ESCALATION="$TMPDIR_TEST/blocked-no-escalation.json"
cat > "$BLOCKED_NO_ESCALATION" <<'ENDJSON'
{
  "goal_id": "goal-invalid-01",
  "groom_status": "blocked",
  "issue_number": 10,
  "issue_url": "https://github.com/acme/myapp/issues/10",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "template_used": "feature-slice",
  "codebase_grounding": {
    "verified_paths": ["apps/api/src/routes/auth.ts"],
    "docs_read": ["docs/context/product-vision.md"]
  },
  "dor_checklist_results": [
    { "item": "Behavior contract written", "status": "pass" }
  ],
  "assumptions_made": [
    { "assumption": "Cookie-based auth is the pattern.", "rationale": "Read from middleware." }
  ],
  "alternatives_considered": [
    { "option": "Option A", "analysis": "Good option.", "recommended": true }
  ],
  "ui_ux_notes": "No breaking UX changes.",
  "recommended_next_step": "Decide the path."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$BLOCKED_NO_ESCALATION" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-G04: blocked output missing escalation_reason -> exit 1 (validation failure)"
else
  fail "BT-G04: blocked output missing escalation_reason -> exit 1 (validation failure)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-G05: blocked output with alternatives_considered:[] fails (exit 1) ---
# When groom_status:blocked, alternatives_considered must have minItems:1.
# A blocked issue is exhaustively groomed and documents alternatives.
# An empty array is unacceptable.
BLOCKED_EMPTY_ALT="$TMPDIR_TEST/blocked-empty-alternatives.json"
cat > "$BLOCKED_EMPTY_ALT" <<'ENDJSON'
{
  "goal_id": "goal-invalid-02",
  "groom_status": "blocked",
  "issue_number": 11,
  "issue_url": "https://github.com/acme/myapp/issues/11",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "template_used": "feature-slice",
  "codebase_grounding": {
    "verified_paths": ["apps/api/src/routes/auth.ts"],
    "docs_read": ["docs/context/product-vision.md"]
  },
  "dor_checklist_results": [
    { "item": "Behavior contract written", "status": "pass" }
  ],
  "assumptions_made": [
    { "assumption": "Cookie-based auth is the pattern.", "rationale": "Read from middleware." }
  ],
  "alternatives_considered": [],
  "ui_ux_notes": "No breaking UX changes.",
  "escalation_reason": "A genuine product decision is needed.",
  "recommended_next_step": "Decide the path."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$BLOCKED_EMPTY_ALT" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-G05: blocked output with alternatives_considered:[] -> exit 1 (minItems enforcement)"
else
  fail "BT-G05: blocked output with alternatives_considered:[] -> exit 1 (minItems enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-G06: terminal output missing run_stop_reason fails (exit 1) ---
# When groom_status:terminal, run_stop_reason is required.
# Omitting it must fail schema validation.
TERMINAL_NO_STOP="$TMPDIR_TEST/terminal-no-stop.json"
cat > "$TERMINAL_NO_STOP" <<'ENDJSON'
{
  "goal_id": "goal-invalid-03",
  "groom_status": "terminal",
  "recommended_next_step": "Backlog exhausted."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$TERMINAL_NO_STOP" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-G06: terminal output missing run_stop_reason -> exit 1 (validation failure)"
else
  fail "BT-G06: terminal output missing run_stop_reason -> exit 1 (validation failure)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-G07: skipped output with minimal required fields validates (exit 0) ---
# The F1 lesson applied to skipped: a skipped output must be emittable with
# ONLY goal_id, groom_status, issue_number, issue_url, skip_reason, and
# recommended_next_step. No codebase_grounding, claim_evidence, or other
# claimed-issue fields are required.
SKIPPED_MINIMAL="$TMPDIR_TEST/skipped-minimal.json"
cat > "$SKIPPED_MINIMAL" <<'ENDJSON'
{
  "goal_id": "goal-valid-skip-01",
  "groom_status": "skipped",
  "issue_number": 99,
  "issue_url": "https://github.com/acme/myapp/issues/99",
  "skip_reason": "Issue already has status:in-progress label — skipping to avoid double-pickup.",
  "recommended_next_step": "No action needed. Issue is already in progress."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$SKIPPED_MINIMAL" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-G07: skipped output with only required fields validates -> exit 0"
else
  fail "BT-G07: skipped output with only required fields validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-G08: failed fixture validates (exit 0) ---
# A failed goal is an operational failure (budget/infra exhaustion) that must NOT
# be forced into blocked (which requires alternatives_considered minItems:1 and
# signals a product decision). The failed variant requires goal_id, groom_status,
# issue_number, issue_url, failure_reason, recommended_next_step — and NO
# alternatives_considered or codebase_grounding.
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FIXTURES_DIR/issue-groomer-output-failed.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-G08: failed fixture (groom_status:failed) validates -> exit 0"
else
  fail "BT-G08: failed fixture (groom_status:failed) validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-G09: failed output missing failure_reason fails (exit 1) ---
# When groom_status:failed, failure_reason is required (minLength:1).
# Omitting it must fail schema validation.
FAILED_NO_REASON="$TMPDIR_TEST/failed-no-reason.json"
cat > "$FAILED_NO_REASON" <<'ENDJSON'
{
  "goal_id": "goal-invalid-failed-01",
  "groom_status": "failed",
  "issue_number": 42,
  "issue_url": "https://github.com/acme/myapp/issues/42",
  "recommended_next_step": "Retry grooming."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FAILED_NO_REASON" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-G09: failed output missing failure_reason -> exit 1 (validation failure)"
else
  fail "BT-G09: failed output missing failure_reason -> exit 1 (validation failure)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-G10: failed output with empty failure_reason fails (exit 1) ---
# When groom_status:failed, failure_reason must have minLength:1.
# An empty string must be rejected.
FAILED_EMPTY_REASON="$TMPDIR_TEST/failed-empty-reason.json"
cat > "$FAILED_EMPTY_REASON" <<'ENDJSON'
{
  "goal_id": "goal-invalid-failed-02",
  "groom_status": "failed",
  "issue_number": 42,
  "issue_url": "https://github.com/acme/myapp/issues/42",
  "failure_reason": "",
  "recommended_next_step": "Retry grooming."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FAILED_EMPTY_REASON" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "BT-G10: failed output with failure_reason:\"\" -> exit 1 (minLength enforcement)"
else
  fail "BT-G10: failed output with failure_reason:\"\" -> exit 1 (minLength enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- BT-G11: skipped standalone fixture validates (exit 0) ---
# The standalone skipped fixture (not an inline tmpfile) must pass schema validation.
# Validates the file path approach: coord-validate accepts file paths directly.
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FIXTURES_DIR/issue-groomer-output-skipped.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-G11: skipped standalone fixture validates -> exit 0"
else
  fail "BT-G11: skipped standalone fixture validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# --- BT-G12: failed output without alternatives_considered validates (exit 0) ---
# The failed variant must NOT require alternatives_considered. Budget/operational
# exhaustion is not a product decision — there is no viable alternative to
# document. This test proves the if/then for failed does NOT impose that field.
FAILED_NO_ALT="$TMPDIR_TEST/failed-no-alternatives.json"
cat > "$FAILED_NO_ALT" <<'ENDJSON'
{
  "goal_id": "goal-valid-failed-01",
  "groom_status": "failed",
  "issue_number": 55,
  "issue_url": "https://github.com/acme/myapp/issues/55",
  "failure_reason": "Attempt budget exhausted (3/3 attempts used) without successfully grooming the issue.",
  "recommended_next_step": "Increase attempt_budget and retry."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FAILED_NO_ALT" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "BT-G12: failed output without alternatives_considered validates -> exit 0"
else
  fail "BT-G12: failed output without alternatives_considered validates -> exit 0" \
       "expected exit 0, got exit $rc — output: $out"
fi

# =============================================================================
# REGRESSION TESTS — added in regression commit.
# These tests would FAIL if the if/then/else blocks were collapsed into a flat
# required list, or if per-variant constraints were removed.
# =============================================================================

# --- RT-G01: ready output missing codebase_grounding fails (exit 1) ---
# For groom_status:ready, codebase_grounding is required. If the if/then were
# removed, this missing field would not be caught.
READY_NO_GROUNDING="$TMPDIR_TEST/ready-no-grounding.json"
cat > "$READY_NO_GROUNDING" <<'ENDJSON'
{
  "goal_id": "goal-regression-01",
  "groom_status": "ready",
  "issue_number": 50,
  "issue_url": "https://github.com/acme/myapp/issues/50",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "template_used": "feature-slice",
  "dor_checklist_results": [
    { "item": "Behavior contract written", "status": "pass" }
  ],
  "assumptions_made": [
    { "assumption": "Cookie-based auth.", "rationale": "From middleware." }
  ],
  "alternatives_considered": [
    { "option": "Option A", "analysis": "Solid.", "recommended": true }
  ],
  "ui_ux_notes": "No UX breaking changes.",
  "recommended_next_step": "Implement the feature."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$READY_NO_GROUNDING" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "RT-G01: ready output missing codebase_grounding -> exit 1 (if/then enforcement)"
else
  fail "RT-G01: ready output missing codebase_grounding -> exit 1 (if/then enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- RT-G02: terminal output must NOT include claim_evidence (exit 1 if present) ---
# Terminal means no issue was claimed. A terminal output including claim_evidence
# is a schema violation — terminal variant must not allow claimed-issue fields.
# This test would pass incorrectly if additionalProperties:false enforcement
# were removed from the terminal variant's then clause.
# NOTE: In JSON Schema Draft 2020-12, additionalProperties on the top-level object
# (with additionalProperties:false) blocks extra properties from the whole object.
# Since claim_evidence IS declared in top-level properties (it is an allowed
# optional property), this test instead checks that the terminal if/then does NOT
# require claim_evidence — it is already covered by BT-G03 verifying terminal
# is emittable WITHOUT it. This regression test instead validates the inverse:
# an output with groom_status:terminal that has an INVALID run_stop_reason enum
# value fails (proving enum enforcement is active on the terminal variant).
TERMINAL_BAD_STOP="$TMPDIR_TEST/terminal-bad-stop.json"
cat > "$TERMINAL_BAD_STOP" <<'ENDJSON'
{
  "goal_id": "goal-regression-02",
  "groom_status": "terminal",
  "run_stop_reason": "unknown_stop_reason_value",
  "recommended_next_step": "Nothing to do."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$TERMINAL_BAD_STOP" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "RT-G02: terminal output with invalid run_stop_reason enum -> exit 1 (enum enforcement)"
else
  fail "RT-G02: terminal output with invalid run_stop_reason enum -> exit 1 (enum enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- RT-G03: skipped output missing skip_reason fails (exit 1) ---
# For groom_status:skipped, skip_reason is required. If the skipped if/then
# were removed or the flat required list used, this field would not be enforced.
SKIPPED_NO_REASON="$TMPDIR_TEST/skipped-no-reason.json"
cat > "$SKIPPED_NO_REASON" <<'ENDJSON'
{
  "goal_id": "goal-regression-03",
  "groom_status": "skipped",
  "issue_number": 100,
  "issue_url": "https://github.com/acme/myapp/issues/100",
  "recommended_next_step": "Skip this issue."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$SKIPPED_NO_REASON" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "RT-G03: skipped output missing skip_reason -> exit 1 (skipped if/then enforcement)"
else
  fail "RT-G03: skipped output missing skip_reason -> exit 1 (skipped if/then enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- RT-G04: output with unknown groom_status enum value fails (exit 1) ---
# The groom_status enum only allows: ready, blocked, skipped, terminal.
# An unknown value must be rejected. This test catches a regression where
# the enum constraint is removed, allowing arbitrary strings.
UNKNOWN_STATUS="$TMPDIR_TEST/unknown-status.json"
cat > "$UNKNOWN_STATUS" <<'ENDJSON'
{
  "goal_id": "goal-regression-04",
  "groom_status": "unknown_value",
  "recommended_next_step": "This should fail."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$UNKNOWN_STATUS" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "RT-G04: output with unknown groom_status value -> exit 1 (enum enforcement)"
else
  fail "RT-G04: output with unknown groom_status value -> exit 1 (enum enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- RT-G05: blocked escalation_reason empty string fails (exit 1) ---
# For groom_status:blocked, escalation_reason must have minLength:1.
# An empty string must be rejected — proving minLength is enforced, not just
# field presence.
BLOCKED_EMPTY_ESCALATION="$TMPDIR_TEST/blocked-empty-escalation.json"
cat > "$BLOCKED_EMPTY_ESCALATION" <<'ENDJSON'
{
  "goal_id": "goal-regression-05",
  "groom_status": "blocked",
  "issue_number": 12,
  "issue_url": "https://github.com/acme/myapp/issues/12",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "template_used": "feature-slice",
  "codebase_grounding": {
    "verified_paths": ["apps/api/src/routes/auth.ts"],
    "docs_read": ["docs/context/product-vision.md"]
  },
  "dor_checklist_results": [
    { "item": "Behavior contract written", "status": "pass" }
  ],
  "assumptions_made": [
    { "assumption": "Cookie-based auth.", "rationale": "From middleware." }
  ],
  "alternatives_considered": [
    { "option": "Option A", "analysis": "Solid.", "recommended": true }
  ],
  "ui_ux_notes": "No UX changes.",
  "escalation_reason": "",
  "recommended_next_step": "Decide the path."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$BLOCKED_EMPTY_ESCALATION" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "RT-G05: blocked output with escalation_reason:\"\" -> exit 1 (minLength enforcement)"
else
  fail "RT-G05: blocked output with escalation_reason:\"\" -> exit 1 (minLength enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- RT-G06: failed output missing issue_number fails (exit 1) ---
# When groom_status:failed, issue_number is required by the if/then block.
# If the failed if/then were removed or its required list shortened, this
# missing field would not be caught. Tests that the failed variant's required
# set includes issue_number (operational failures occur against a specific issue).
FAILED_NO_ISSUE_NUM="$TMPDIR_TEST/failed-no-issue-number.json"
cat > "$FAILED_NO_ISSUE_NUM" <<'ENDJSON'
{
  "goal_id": "goal-regression-06",
  "groom_status": "failed",
  "issue_url": "https://github.com/acme/myapp/issues/77",
  "failure_reason": "Budget exhausted.",
  "recommended_next_step": "Retry."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FAILED_NO_ISSUE_NUM" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "RT-G06: failed output missing issue_number -> exit 1 (failed if/then enforcement)"
else
  fail "RT-G06: failed output missing issue_number -> exit 1 (failed if/then enforcement)" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- RT-G07: failed is NOT accepted as a blocked substitute (blocked still needs alternatives) ---
# A failed output cannot sneak past blocked constraints by using groom_status:blocked
# without alternatives_considered. This test re-validates BT-G05 from the other direction:
# the failed variant's existence must not relax blocked's minItems:1 enforcement.
# If the enum were collapsed or the blocked if/then removed, this would incorrectly pass.
BLOCKED_NO_ALT_2="$TMPDIR_TEST/blocked-no-alt-regression.json"
cat > "$BLOCKED_NO_ALT_2" <<'ENDJSON'
{
  "goal_id": "goal-regression-07",
  "groom_status": "blocked",
  "issue_number": 33,
  "issue_url": "https://github.com/acme/myapp/issues/33",
  "claim_evidence": { "label_swap_confirmed": true, "self_assign_confirmed": true },
  "template_used": "feature-slice",
  "codebase_grounding": {
    "verified_paths": ["apps/api/src/routes/auth.ts"],
    "docs_read": ["docs/context/product-vision.md"]
  },
  "dor_checklist_results": [{ "item": "DOR check", "status": "pass" }],
  "assumptions_made": [{ "assumption": "Assumption.", "rationale": "Reason." }],
  "alternatives_considered": [],
  "ui_ux_notes": "None.",
  "escalation_reason": "A real decision is needed.",
  "recommended_next_step": "Escalate to product."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$BLOCKED_NO_ALT_2" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  pass "RT-G07: blocked still requires alternatives_considered minItems:1 after failed variant added -> exit 1"
else
  fail "RT-G07: blocked still requires alternatives_considered minItems:1 after failed variant added -> exit 1" \
       "expected exit 1, got exit $rc — output: $out"
fi

# --- RT-G08: failed variant in groom_status enum (not unknown) validates -> exit 0 ---
# Directly tests that 'failed' was added to the enum. If the enum were reverted to
# [ready, blocked, skipped, terminal], this test would fail (exit 1) because 'failed'
# would be an invalid enum value. This is the pure enum-membership regression test.
FAILED_ENUM_CHECK="$TMPDIR_TEST/failed-enum-only.json"
cat > "$FAILED_ENUM_CHECK" <<'ENDJSON'
{
  "goal_id": "goal-regression-08",
  "groom_status": "failed",
  "issue_number": 99,
  "issue_url": "https://github.com/acme/myapp/issues/99",
  "failure_reason": "Infrastructure timeout after 60 seconds.",
  "recommended_next_step": "Retry after investigating infra connectivity."
}
ENDJSON
out=$(cd "$COORD_DIR" && ./coord-validate issue-groomer "$FAILED_ENUM_CHECK" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  pass "RT-G08: groom_status:failed is a valid enum value -> exit 0 (enum membership)"
else
  fail "RT-G08: groom_status:failed is a valid enum value -> exit 0 (enum membership)" \
       "expected exit 0, got exit $rc — output: $out"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
