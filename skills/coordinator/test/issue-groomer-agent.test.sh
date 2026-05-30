#!/usr/bin/env bash
# issue-groomer-agent.test.sh — structural tests for the issue-groomer agent definition.
#
# Asserts that:
#   1. agents/issue-groomer.md frontmatter contains required fields
#   2. The body names every state-machine phase (startup/select/claim/ground/draft/readiness-gate/write)
#   3. The body documents the non-atomic-claim / sequential-only caveat
#   4. The body documents stop conditions (max_issues_per_run, attempt_budget, status:kill)
#   5. SKILL.md contains an issue-groomer registration row
#   6. Three-tier select priority + anti-infinite-enrichment guard
#   7. Kill-switch re-check before claim mutation
#   8. All four groom_status output variants documented
#   9. blocked-is-still-exhaustively-groomed + escalation-is-RARE language
#  10. UNTRUSTED + --body-file pattern
#  11. --limit flag on gh queries + client-side sort
#  12. WATCH mode + poll_interval + run_stop_reason distinctions
#  13. issue-groomer-settings.json denies Edit/Write/Bash
#
# Run from any directory — the script resolves its own location.
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORD_DIR="$(cd "$SELF_DIR/.." && pwd)"
AGENT_FILE="$COORD_DIR/agents/issue-groomer.md"
SKILL_FILE="$COORD_DIR/SKILL.md"
SETTINGS_FILE="$COORD_DIR/issue-groomer-settings.json"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

echo ""
echo "issue-groomer agent structural tests"
echo "======================================"

# ---------------------------------------------------------------------------
# BT-001: frontmatter — name: issue-groomer
# ---------------------------------------------------------------------------
if grep -q '^name: issue-groomer$' "$AGENT_FILE" 2>/dev/null; then
  pass "BT-001: frontmatter contains 'name: issue-groomer'"
else
  fail "BT-001: frontmatter contains 'name: issue-groomer'" \
       "expected line 'name: issue-groomer' in $AGENT_FILE"
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
# BT-005: state machine — all required groomer phases appear as labeled headings/steps
# Phases: startup, select, claim, ground, draft, readiness-gate, write
# ---------------------------------------------------------------------------
MISSING_PHASES=()
for phase in startup select claim ground draft write; do
  if ! grep -qiE "^#+[[:space:]].*\b${phase}\b|^[[:space:]]*[0-9]+\.[[:space:]]+\`${phase}\`" "$AGENT_FILE" 2>/dev/null; then
    MISSING_PHASES+=("$phase")
  fi
done
# readiness-gate has a hyphen — match it specially
if ! grep -qiE "^#+[[:space:]].*readiness.gate|^[[:space:]]*[0-9]+\.[[:space:]]+\`readiness-gate\`|readiness-gate|readiness.gate" "$AGENT_FILE" 2>/dev/null; then
  MISSING_PHASES+=("readiness-gate")
fi
if [ ${#MISSING_PHASES[@]} -eq 0 ]; then
  pass "BT-005: every state-machine phase appears as a heading or labeled step (startup/select/claim/ground/draft/readiness-gate/write)"
else
  fail "BT-005: every state-machine phase appears as a heading or labeled step" \
       "missing phases: ${MISSING_PHASES[*]}"
fi

# ---------------------------------------------------------------------------
# BT-006: non-atomic-claim / sequential-only caveat documented
# ---------------------------------------------------------------------------
if grep -qi "not.*atomic\|non-atomic\|sequential.*only\|single.*instance.*only\|sequential.*single" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-006: body documents non-atomic-claim / sequential-only caveat"
else
  fail "BT-006: body documents non-atomic-claim / sequential-only caveat" \
       "expected text about non-atomic claim and sequential-only constraint in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-007: stop conditions — max_issues_per_run
# ---------------------------------------------------------------------------
if grep -qi "max_issues_per_run\|max.issues.per.run" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-007: body documents stop condition 'max_issues_per_run'"
else
  fail "BT-007: body documents stop condition 'max_issues_per_run'" \
       "expected 'max_issues_per_run' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-008: stop conditions — attempt_budget
# ---------------------------------------------------------------------------
if grep -qE "attempt_budget|total_attempt_budget" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-008: body documents stop condition 'attempt_budget'"
else
  fail "BT-008: body documents stop condition 'attempt_budget'" \
       "expected 'attempt_budget' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-009: stop conditions — status:kill kill switch
# ---------------------------------------------------------------------------
if grep -qi "status:kill\|kill.switch\|kill switch" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-009: body documents kill switch (status:kill)"
else
  fail "BT-009: body documents kill switch (status:kill)" \
       "expected 'status:kill' or 'kill switch' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-010: SKILL.md contains an issue-groomer registration row
# ---------------------------------------------------------------------------
if grep -q 'issue-groomer' "$SKILL_FILE" 2>/dev/null; then
  pass "BT-010: SKILL.md contains an 'issue-groomer' row"
else
  fail "BT-010: SKILL.md contains an 'issue-groomer' row" \
       "expected 'issue-groomer' entry in $SKILL_FILE"
fi

# ---------------------------------------------------------------------------
# BT-011: three-tier select priority — status-less first
# The select phase must document (1) oldest open status-less issue as highest priority.
# ---------------------------------------------------------------------------
if grep -qiE "status.less|status-less|no.*status.*label|without.*status" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-011: select documents status-less issues as highest priority"
else
  fail "BT-011: select documents status-less issues as highest priority" \
       "expected status-less / no-status-label language in select phase of $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-012: three-tier select priority — status:ready review as tier 2
# The select phase must document reviewing status:ready issues as a fallback tier.
# ---------------------------------------------------------------------------
if grep -qiE "status:ready.*review|review.*status:ready|tier.*2|priority.*2|second.*priority|if none.*ready\|status:ready.*at most once" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-012: select documents status:ready review as tier-2 fallback"
else
  fail "BT-012: select documents status:ready review as tier-2 fallback" \
       "expected status:ready review as secondary/tier-2 select priority in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-013: anti-infinite-enrichment guard — at most once per run per issue
# The select phase must prevent infinite re-grooming of status:ready issues.
# ---------------------------------------------------------------------------
if grep -qiE "at most once.*run|once per run|in.memory.*set|track.*reviewed|reviewed.*set|anti.infinite|anti-infinite" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-013: select documents anti-infinite-enrichment guard (at most once per run)"
else
  fail "BT-013: select documents anti-infinite-enrichment guard (at most once per run)" \
       "expected anti-infinite-enrichment guard language (at most once per run) in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-014: kill-switch re-check immediately before claim mutation
# ---------------------------------------------------------------------------
if grep -qiE "re.fetch.*label|re.fetch.*kill|re-fetch.*before.*claim|re-check.*before.*claim|immediately before.*claim|re.fetch.*claim|claim.*re.fetch" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-014: doc documents kill-switch label re-fetch immediately before claim mutation"
else
  fail "BT-014: doc documents kill-switch label re-fetch immediately before claim mutation" \
       "expected re-fetch of labels before claim mutation in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-015: all four groom_status output variants documented — ready
# ---------------------------------------------------------------------------
if grep -qiE "groom_status.*ready|groom_status:.*\"ready\"|Variant.*ready|status.*ready.*variant|ready.*groom_status|groom_status.*ready.*required" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-015: doc documents 'ready' groom_status variant"
else
  fail "BT-015: doc documents 'ready' groom_status variant" \
       "expected 'ready' groom_status variant documentation in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-016: all four groom_status output variants documented — blocked
# ---------------------------------------------------------------------------
if grep -qiE "groom_status.*blocked|groom_status:.*\"blocked\"|Variant.*blocked.*groom|blocked.*groom_status|groom_status.*blocked.*escalation" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-016: doc documents 'blocked' groom_status variant with escalation_reason"
else
  fail "BT-016: doc documents 'blocked' groom_status variant with escalation_reason" \
       "expected 'blocked' groom_status variant documentation in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-017: all four groom_status output variants documented — skipped
# ---------------------------------------------------------------------------
if grep -qiE "groom_status.*skipped|groom_status:.*\"skipped\"|Variant.*skipped|skipped.*groom_status|skip_reason" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-017: doc documents 'skipped' groom_status variant with skip_reason"
else
  fail "BT-017: doc documents 'skipped' groom_status variant with skip_reason" \
       "expected 'skipped' groom_status variant with skip_reason in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-018: all four groom_status output variants documented — terminal
# ---------------------------------------------------------------------------
if grep -qiE "groom_status.*terminal|groom_status:.*\"terminal\"|Variant.*terminal.*groom|terminal.*groom_status|terminal.*run_stop_reason" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-018: doc documents 'terminal' groom_status variant with run_stop_reason"
else
  fail "BT-018: doc documents 'terminal' groom_status variant with run_stop_reason" \
       "expected 'terminal' groom_status variant documentation with run_stop_reason in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-019: blocked-is-still-exhaustively-groomed principle documented
# The doc must explicitly state that blocked does NOT mean "couldn't groom"
# and that the ticket is STILL exhaustively groomed when blocked.
# ---------------------------------------------------------------------------
if grep -qiE "exhaustively.*groom|groom.*exhaustively|still.*groom.*block|block.*still.*groom|never.*leave.*un.groom|un-groomed.*never|never.*un.groom" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-019: doc states blocked issues are still exhaustively groomed"
else
  fail "BT-019: doc states blocked issues are still exhaustively groomed" \
       "expected 'exhaustively groomed' or 'never leave un-groomed' language in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-020: escalation-is-RARE principle documented
# The doc must explicitly state that escalation (blocked) is rare and only for
# genuine product/path decisions — not for technical gaps.
# ---------------------------------------------------------------------------
if grep -qiE "escalation.*rare|rare.*escalation|escalat.*is rare|blocked.*rare|RARE|rare.*blocked" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-020: doc states escalation/blocked is RARE (not the default outcome)"
else
  fail "BT-020: doc states escalation/blocked is RARE (not the default outcome)" \
       "expected 'escalation is rare' or 'RARE' escalation language in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-021: UNTRUSTED issue content contract
# ---------------------------------------------------------------------------
if grep -qiE "UNTRUSTED|untrusted" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-021: doc contains untrusted-issue-content section (UNTRUSTED)"
else
  fail "BT-021: doc contains untrusted-issue-content section (UNTRUSTED)" \
       "expected 'UNTRUSTED' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-022: --body-file pattern documented for gh issue edit and gh issue comment
# ---------------------------------------------------------------------------
if grep -qiE "\-\-body-file|body.file|body_file" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-022: doc documents --body-file pattern for gh issue edit/comment"
else
  fail "BT-022: doc documents --body-file pattern for gh issue edit/comment" \
       "expected '--body-file' pattern in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-023: gh queries use --limit flag to avoid silent 30-issue cap
# ---------------------------------------------------------------------------
if grep -qiE "\-\-limit[[:space:]]+[0-9]|--limit [0-9]" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-023: select query uses --limit flag to avoid silent 30-issue cap"
else
  fail "BT-023: select query uses --limit flag to avoid silent 30-issue cap" \
       "expected '--limit <N>' in gh issue list query in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-024: client-side sort documented for select (pick genuinely oldest issue)
# ---------------------------------------------------------------------------
if grep -qiE "sort.*client|client.*sort|sort.*ascending|ascending.*sort|sort.*number|sort_by|jq.*sort|client.side.*filter" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-024: select step documents client-side sort/filter to pick oldest issue"
else
  fail "BT-024: select step documents client-side sort/filter to pick oldest issue" \
       "expected client-side sort (e.g. jq sort_by) in select query documentation in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-025: WATCH mode documented with poll_interval
# ---------------------------------------------------------------------------
if grep -qiE "WATCH.*mode|watch.mode|poll_interval|watch.*poll|poll.*interval" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-025: doc documents WATCH mode with poll_interval"
else
  fail "BT-025: doc documents WATCH mode with poll_interval" \
       "expected 'WATCH mode' and 'poll_interval' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-026: run_stop_reason watch_poll_wait (transient) vs no_status_less_issues (permanent)
# The doc must distinguish transient watch-sleep from permanent exhaustion.
# ---------------------------------------------------------------------------
if grep -qiE "watch_poll_wait|watch.poll.wait" "$AGENT_FILE" 2>/dev/null && \
   grep -qiE "no_status_less_issues|no.status.less.issues" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-026: doc distinguishes watch_poll_wait (transient) from no_status_less_issues (permanent terminal)"
else
  fail "BT-026: doc distinguishes watch_poll_wait (transient) from no_status_less_issues (permanent terminal)" \
       "expected both 'watch_poll_wait' and 'no_status_less_issues' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-027: external cron as production alternative to in-process sleep
# ---------------------------------------------------------------------------
if grep -qiE "cron|external.*sleep|external.*poll|production.*alternative|in.process.*sleep" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-027: doc documents external cron as production alternative to in-process sleep"
else
  fail "BT-027: doc documents external cron as production alternative to in-process sleep" \
       "expected cron or external scheduling alternative documented in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-028: coord-validate usage with file path documented (not stdin)
# ---------------------------------------------------------------------------
if grep -qiE "coord-validate issue-groomer" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-028: doc shows 'coord-validate issue-groomer' usage example"
else
  fail "BT-028: doc shows 'coord-validate issue-groomer' usage example" \
       "expected 'coord-validate issue-groomer' usage in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-029: settings file exists
# ---------------------------------------------------------------------------
if [ -f "$SETTINGS_FILE" ]; then
  pass "BT-029: issue-groomer-settings.json exists"
else
  fail "BT-029: issue-groomer-settings.json exists" \
       "file not found: $SETTINGS_FILE"
fi

# ---------------------------------------------------------------------------
# BT-030: settings denies Edit
# ---------------------------------------------------------------------------
if grep -q '"Edit"' "$SETTINGS_FILE" 2>/dev/null; then
  pass "BT-030: issue-groomer-settings.json denies 'Edit'"
else
  fail "BT-030: issue-groomer-settings.json denies 'Edit'" \
       "expected '\"Edit\"' in deny list in $SETTINGS_FILE"
fi

# ---------------------------------------------------------------------------
# BT-031: settings denies Write
# ---------------------------------------------------------------------------
if grep -q '"Write"' "$SETTINGS_FILE" 2>/dev/null; then
  pass "BT-031: issue-groomer-settings.json denies 'Write'"
else
  fail "BT-031: issue-groomer-settings.json denies 'Write'" \
       "expected '\"Write\"' in deny list in $SETTINGS_FILE"
fi

# ---------------------------------------------------------------------------
# BT-032: settings denies Bash
# ---------------------------------------------------------------------------
if grep -q '"Bash"' "$SETTINGS_FILE" 2>/dev/null; then
  pass "BT-032: issue-groomer-settings.json denies 'Bash'"
else
  fail "BT-032: issue-groomer-settings.json denies 'Bash'" \
       "expected '\"Bash\"' in deny list in $SETTINGS_FILE"
fi

# ===========================================================================
# REGRESSION TESTS — would fail if the full implementation were reverted to stub
# or if individual required attributes were removed.
# ===========================================================================

# ---------------------------------------------------------------------------
# RT-001: tools field must specifically be 'Agent' (not a broader toolset)
# ---------------------------------------------------------------------------
tools_line=$(grep '^tools:' "$AGENT_FILE" 2>/dev/null | head -1)
if [ "$tools_line" = "tools: Agent" ]; then
  pass "RT-001: tools field is exactly 'tools: Agent' (pure-delegation preserved)"
else
  fail "RT-001: tools field is exactly 'tools: Agent'" \
       "expected 'tools: Agent', got: '$tools_line' — pure-delegation contract broken"
fi

# ---------------------------------------------------------------------------
# RT-002: model field must specifically be 'opus'
# ---------------------------------------------------------------------------
model_line=$(grep '^model:' "$AGENT_FILE" 2>/dev/null | head -1)
if [ "$model_line" = "model: opus" ]; then
  pass "RT-002: model field is exactly 'model: opus'"
else
  fail "RT-002: model field is exactly 'model: opus'" \
       "expected 'model: opus', got: '$model_line'"
fi

# ---------------------------------------------------------------------------
# RT-003: settings file denies Edit, Write, AND Bash (all three required)
# ---------------------------------------------------------------------------
if [ -f "$SETTINGS_FILE" ]; then
  if grep -q '"Edit"' "$SETTINGS_FILE" && grep -q '"Write"' "$SETTINGS_FILE" && grep -q '"Bash"' "$SETTINGS_FILE"; then
    pass "RT-003: issue-groomer-settings.json exists and denies Edit, Write, Bash"
  else
    fail "RT-003: issue-groomer-settings.json denies Edit, Write, Bash" \
         "settings file exists but is missing one of: Edit, Write, Bash in deny list"
  fi
else
  fail "RT-003: issue-groomer-settings.json exists" \
       "file not found: $SETTINGS_FILE"
fi

# ---------------------------------------------------------------------------
# RT-004: SKILL.md registration includes model reference for issue-groomer
# ---------------------------------------------------------------------------
if grep -q 'issue-groomer' "$SKILL_FILE" 2>/dev/null && \
   grep 'issue-groomer' "$SKILL_FILE" | grep -q 'Opus\|opus'; then
  pass "RT-004: SKILL.md issue-groomer row includes model reference (Opus)"
else
  fail "RT-004: SKILL.md issue-groomer row includes model reference" \
       "row exists but is missing opus model reference in $SKILL_FILE"
fi

# ---------------------------------------------------------------------------
# RT-005: non-atomic claim caveat mentions concurrency or v2
# A vague "sequential" alone is not enough — must address WHY (concurrency).
# ---------------------------------------------------------------------------
if grep -qi "concurrent\|concurren\|v2\|two.*run\|double.pick\|double-pick\|two.*groomers\|groomers.*concurrently" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-005: non-atomic claim caveat specifically addresses concurrent runs / v2"
else
  fail "RT-005: non-atomic claim caveat specifically addresses concurrent runs" \
       "expected 'concurrent', 'v2', 'two runs', 'double-pick', or 'two groomers' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-006: anti-infinite-enrichment guard cannot be silently removed
# Checks that the guard specifically prevents infinite re-enrichment of ready tickets.
# ---------------------------------------------------------------------------
if grep -qiE "at most once.*run|once per run|in.memory.*set.*reviewed|track.*reviewed.*set|ANTI.INFINITE|anti-infinite|re.enrich.*prevent|prevent.*re.enrich" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-006: anti-infinite-enrichment guard preserved (tracks reviewed-this-run set)"
else
  fail "RT-006: anti-infinite-enrichment guard preserved" \
       "expected anti-infinite-enrichment tracking language in $AGENT_FILE — guard may have been removed"
fi

# ---------------------------------------------------------------------------
# RT-007: WATCH mode documentation cannot be removed
# Specifically checks that both in-process sleep AND external cron are mentioned.
# ---------------------------------------------------------------------------
if grep -qiE "WATCH.*mode\|watch.mode\|poll_interval" "$AGENT_FILE" 2>/dev/null && \
   grep -qiE "cron\|external.*schedule\|in.process.*sleep" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-007: WATCH mode preserved with both in-process sleep and cron/external-schedule docs"
else
  fail "RT-007: WATCH mode preserved with both in-process sleep and cron/external-schedule docs" \
       "expected WATCH mode with poll_interval AND cron/external alternative in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-008: all four groom_status variants documented (cannot remove one silently)
# ---------------------------------------------------------------------------
variants_found=0
for variant in "ready" "blocked" "skipped" "terminal"; do
  if grep -qiE "groom_status.*\"${variant}\"|groom_status:.*${variant}|Variant.*${variant}.*groom|${variant}.*groom_status" "$AGENT_FILE" 2>/dev/null; then
    variants_found=$((variants_found + 1))
  fi
done
if [ "$variants_found" -eq 4 ]; then
  pass "RT-008: all four groom_status variants documented (ready/blocked/skipped/terminal)"
else
  fail "RT-008: all four groom_status variants documented" \
       "only found $variants_found of 4 variants (ready/blocked/skipped/terminal) in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-009: escalation_reason preserved as required for blocked variant
# ---------------------------------------------------------------------------
if grep -qiE "escalation_reason.*required\|required.*escalation_reason\|blocked.*escalation_reason\|escalation_reason.*blocked" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-009: escalation_reason preserved as required for blocked variant"
else
  fail "RT-009: escalation_reason preserved as required for blocked variant" \
       "expected escalation_reason as required field for blocked variant in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-010: UNTRUSTED designation preserved (security posture)
# ---------------------------------------------------------------------------
if grep -q "UNTRUSTED" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-010: UNTRUSTED uppercase preserved (security posture)"
else
  fail "RT-010: UNTRUSTED uppercase preserved" \
       "expected uppercase UNTRUSTED in $AGENT_FILE — security section may have been softened"
fi

# ---------------------------------------------------------------------------
# RT-011: branch slug whitelist [a-z0-9-] documented
# ---------------------------------------------------------------------------
if grep -qiE "\[a-z0-9-\]|whitelist.*slug|slug.*whitelist|sanitize.*branch|branch.*sanitize" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-011: branch slug whitelist [a-z0-9-] documented"
else
  fail "RT-011: branch slug whitelist [a-z0-9-] documented" \
       "expected '[a-z0-9-]' or slug whitelist language in $AGENT_FILE"
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
