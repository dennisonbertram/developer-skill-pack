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
