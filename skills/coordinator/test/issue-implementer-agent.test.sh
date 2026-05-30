#!/usr/bin/env bash
# issue-implementer-agent.test.sh — structural tests for the issue-implementer agent definition.
#
# Asserts that:
#   1. agents/issue-implementer.md frontmatter contains required fields
#   2. The body names every state-machine phase
#   3. The body documents the non-atomic-claim / sequential-only caveat
#   4. The body documents stop conditions
#   5. SKILL.md contains an issue-implementer registration row
#
# Run from any directory — the script resolves its own location.
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORD_DIR="$(cd "$SELF_DIR/.." && pwd)"
AGENT_FILE="$COORD_DIR/agents/issue-implementer.md"
SKILL_FILE="$COORD_DIR/SKILL.md"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

echo ""
echo "issue-implementer agent structural tests"
echo "========================================="

# ---------------------------------------------------------------------------
# BT-001: frontmatter — name: issue-implementer
# ---------------------------------------------------------------------------
if grep -q '^name: issue-implementer$' "$AGENT_FILE" 2>/dev/null; then
  pass "BT-001: frontmatter contains 'name: issue-implementer'"
else
  fail "BT-001: frontmatter contains 'name: issue-implementer'" \
       "expected line 'name: issue-implementer' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-002: frontmatter — tools: Agent
# ---------------------------------------------------------------------------
if grep -q '^tools: Agent$' "$AGENT_FILE" 2>/dev/null; then
  pass "BT-002: frontmatter contains 'tools: Agent'"
else
  fail "BT-002: frontmatter contains 'tools: Agent'" \
       "expected line 'tools: Agent' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-003: frontmatter — model: opus
# ---------------------------------------------------------------------------
if grep -q '^model: opus$' "$AGENT_FILE" 2>/dev/null; then
  pass "BT-003: frontmatter contains 'model: opus'"
else
  fail "BT-003: frontmatter contains 'model: opus'" \
       "expected line 'model: opus' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-004: frontmatter — user_invocable: true
# ---------------------------------------------------------------------------
if grep -q '^user_invocable: true$' "$AGENT_FILE" 2>/dev/null; then
  pass "BT-004: frontmatter contains 'user_invocable: true'"
else
  fail "BT-004: frontmatter contains 'user_invocable: true'" \
       "expected line 'user_invocable: true' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-005: state machine — all required phases present in the body
# ---------------------------------------------------------------------------
MISSING_PHASES=()
for phase in startup select claim ground plan delegate integrate review test validate close loop; do
  if ! grep -qi "\b${phase}\b" "$AGENT_FILE" 2>/dev/null; then
    MISSING_PHASES+=("$phase")
  fi
done
if [ ${#MISSING_PHASES[@]} -eq 0 ]; then
  pass "BT-005: body names every state-machine phase (startup, select, claim, ground, plan, delegate, integrate, review, test, validate, close, loop)"
else
  fail "BT-005: body names every state-machine phase" \
       "missing phases: ${MISSING_PHASES[*]}"
fi

# ---------------------------------------------------------------------------
# BT-006: non-atomic-claim / sequential-only caveat documented
# ---------------------------------------------------------------------------
# The file must document that the claim is NOT truly atomic and that v1 is sequential.
if grep -qi "not.*atomic\|non-atomic\|sequential.*only\|single.*agent.*only\|sequential.*single" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-006: body documents non-atomic-claim / sequential-only caveat"
else
  fail "BT-006: body documents non-atomic-claim / sequential-only caveat" \
       "expected text about non-atomic claim and sequential-only constraint in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-007: stop conditions documented — max_issues_per_run
# ---------------------------------------------------------------------------
if grep -qi "max_issues_per_run\|max.issues.per.run" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-007: body documents stop condition 'max_issues_per_run'"
else
  fail "BT-007: body documents stop condition 'max_issues_per_run'" \
       "expected 'max_issues_per_run' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-008: stop conditions documented — ci_retry_budget
# ---------------------------------------------------------------------------
if grep -qi "ci_retry_budget\|ci.retry.budget" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-008: body documents stop condition 'ci_retry_budget'"
else
  fail "BT-008: body documents stop condition 'ci_retry_budget'" \
       "expected 'ci_retry_budget' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-009: stop conditions documented — status:kill kill switch
# ---------------------------------------------------------------------------
if grep -qi "status:kill\|kill.switch\|kill switch" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-009: body documents kill switch (status:kill)"
else
  fail "BT-009: body documents kill switch (status:kill)" \
       "expected 'status:kill' or 'kill switch' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-010: SKILL.md contains an issue-implementer registration row
# ---------------------------------------------------------------------------
if grep -q 'issue-implementer' "$SKILL_FILE" 2>/dev/null; then
  pass "BT-010: SKILL.md contains an 'issue-implementer' row"
else
  fail "BT-010: SKILL.md contains an 'issue-implementer' row" \
       "expected 'issue-implementer' entry in $SKILL_FILE"
fi

# ===========================================================================
# REGRESSION TESTS — added in regression commit.
# These tests would FAIL if the full implementation in the green commit were
# reverted to the stub, or if individual required attributes were removed.
# ===========================================================================

# ---------------------------------------------------------------------------
# RT-001: tools field must specifically be 'Agent' (not a broader toolset)
# If tools: were changed to 'Read, Edit, Write, Bash' (like a worker),
# this test would fail — ensuring the pure-delegation contract is preserved.
# ---------------------------------------------------------------------------
tools_line=$(grep '^tools:' "$AGENT_FILE" 2>/dev/null | head -1)
if [ "$tools_line" = "tools: Agent" ]; then
  pass "RT-001: tools field is exactly 'tools: Agent' (pure-delegation, not a worker toolset)"
else
  fail "RT-001: tools field is exactly 'tools: Agent'" \
       "expected 'tools: Agent', got: '$tools_line' — pure-delegation contract broken"
fi

# ---------------------------------------------------------------------------
# RT-002: model field must specifically be 'opus' (not sonnet or haiku)
# If model: were changed to sonnet (as for workers), this catches the drift.
# ---------------------------------------------------------------------------
model_line=$(grep '^model:' "$AGENT_FILE" 2>/dev/null | head -1)
if [ "$model_line" = "model: opus" ]; then
  pass "RT-002: model field is exactly 'model: opus'"
else
  fail "RT-002: model field is exactly 'model: opus'" \
       "expected 'model: opus', got: '$model_line'"
fi

# ---------------------------------------------------------------------------
# RT-003: settings file exists and denies Edit/Write/Bash
# A pure-delegation agent must have a settings file that denies direct I/O
# tools. If the settings file is deleted or Edit is un-denied, this fails.
# ---------------------------------------------------------------------------
SETTINGS_FILE="$COORD_DIR/issue-implementer-settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  if grep -q '"Edit"' "$SETTINGS_FILE" && grep -q '"Write"' "$SETTINGS_FILE" && grep -q '"Bash"' "$SETTINGS_FILE"; then
    pass "RT-003: issue-implementer-settings.json exists and denies Edit, Write, Bash"
  else
    fail "RT-003: issue-implementer-settings.json denies Edit, Write, Bash" \
         "settings file exists but is missing one of: Edit, Write, Bash in deny list"
  fi
else
  fail "RT-003: issue-implementer-settings.json exists" \
       "file not found: $SETTINGS_FILE"
fi

# ---------------------------------------------------------------------------
# RT-004: SKILL.md registration includes model and tools columns for issue-implementer
# Catches a registration row that exists but is missing critical metadata.
# ---------------------------------------------------------------------------
if grep -q 'issue-implementer' "$SKILL_FILE" 2>/dev/null && \
   grep 'issue-implementer' "$SKILL_FILE" | grep -q 'Opus\|opus'; then
  pass "RT-004: SKILL.md issue-implementer row includes model reference"
else
  fail "RT-004: SKILL.md issue-implementer row includes model reference" \
       "row exists but is missing opus model reference in $SKILL_FILE"
fi

# ---------------------------------------------------------------------------
# RT-005: non-atomic claim caveat is specific enough to mention v2 or concurrent
# A vague mention of "sequential" is not enough — the caveat must specifically
# address concurrency so future readers understand WHY it's sequential.
# ---------------------------------------------------------------------------
if grep -qi "concurrent\|concurren\|v2\|two.*run\|double.pick\|double-pick" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-005: non-atomic claim caveat specifically addresses concurrent runs / v2"
else
  fail "RT-005: non-atomic claim caveat specifically addresses concurrent runs" \
       "expected 'concurrent', 'v2', 'two runs', or 'double-pick' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
