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
if grep -qiE "WATCH.*mode|watch.mode|poll_interval" "$AGENT_FILE" 2>/dev/null && \
   grep -qiE "cron|external.*schedule|in.process.*sleep" "$AGENT_FILE" 2>/dev/null; then
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
if grep -qiE "escalation_reason.*required|required.*escalation_reason|blocked.*escalation_reason|escalation_reason.*blocked" "$AGENT_FILE" 2>/dev/null; then
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

# ===========================================================================
# NEW BEHAVIORAL TESTS — G1–G14 runtime-logic fixes (REVIEW-G1 findings)
# ===========================================================================

# ---------------------------------------------------------------------------
# BT-033 (GF1): reviewed_ready_this_run is ADDED TO in tier-2 before emitting result
# The doc must state that each reviewed issue's number is added to the set BEFORE
# emitting (not after, not conditionally).
# ---------------------------------------------------------------------------
if grep -qiE "add.*reviewed_ready_this_run|reviewed_ready_this_run.*add|ADD.*to.*reviewed_ready|before.*emit.*reviewed|reviewed_ready.*before.*emit" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-033 (GF1): doc states reviewed_ready_this_run is populated BEFORE emitting result"
else
  fail "BT-033 (GF1): doc states reviewed_ready_this_run is populated BEFORE emitting result" \
       "expected explicit 'add ... reviewed_ready_this_run ... before emit' language in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-034 (GF1): tier-2 candidate query EXCLUDES already-reviewed issues
# The query must filter out issues already in reviewed_ready_this_run.
# ---------------------------------------------------------------------------
if grep -qiE "exclud.*reviewed_ready|reviewed_ready.*exclud|filter.*reviewed_ready|reviewed_ready.*filter|not.*reviewed_ready|reviewed_ready.*not|exclude.*already.*reviewed" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-034 (GF1): tier-2 candidate query excludes issues already in reviewed_ready_this_run"
else
  fail "BT-034 (GF1): tier-2 candidate query excludes issues already in reviewed_ready_this_run" \
       "expected tier-2 query to explicitly exclude reviewed_ready_this_run members in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-035 (GF1): empty tier-2 falls through to tier-3 (not loop back)
# The doc must state that when tier-2 filtered set is empty, agent falls through
# to tier-3 (terminal / WATCH sleep), guaranteeing termination.
# ---------------------------------------------------------------------------
if grep -qiE "fall.*through.*tier.3|fall.through.*terminal|filtered.*empty.*fall|empty.*filtered.*fall|all.*reviewed.*fall|tier.2.*empty.*terminal|fall.*through.*when.*empty|empty.*candidate.*fall" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-035 (GF1): empty tier-2 falls through to tier-3/terminal (termination guaranteed)"
else
  fail "BT-035 (GF1): empty tier-2 falls through to tier-3/terminal (termination guaranteed)" \
       "expected explicit fall-through to tier-3 when filtered tier-2 set is empty in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-036 (GF1): ready-reviews do NOT consume the grooming budget
# Skipped ready reviews must not count against max_issues_per_run.
# ---------------------------------------------------------------------------
if grep -qiE "ready.*not.*budget|ready.*do not.*budget|skipped.*not.*count|not.*consume.*budget|budget.*not.*ready|ready.review.*not.*count|not count.*grooming budget|do not consume" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-036 (GF1): doc states ready-review skips do NOT consume grooming budget"
else
  fail "BT-036 (GF1): doc states ready-review skips do NOT consume grooming budget" \
       "expected explicit statement that ready-review skips don't count against max_issues_per_run in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-037 (GF3/GF4): attempt_budget counts ONLY retry/re-delegation cycles,
# NOT first-pass phase delegations (happy path must not consume budget).
# ---------------------------------------------------------------------------
if grep -qiE "attempt_budget.*retry|retry.*attempt_budget|budget.*only.*retry|only.*retry.*budget|count.*only.*retry|retry.cycle.*budget|re.delegation.*budget|budget.*re.delegation" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-037 (GF3/GF4): attempt_budget counts only retry/re-delegation cycles (not first-pass delegations)"
else
  fail "BT-037 (GF3/GF4): attempt_budget counts only retry/re-delegation cycles" \
       "expected explicit language that attempt_budget counts retries only (not happy-path delegations) in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-038 (GF2/GF3): budget/operational exhaustion routes to groom_status:failed, NOT blocked
# The doc must state that attempt_budget exhaustion => failed (not blocked).
# ---------------------------------------------------------------------------
if grep -qiE "budget.*exhausted.*failed|exhausted.*groom_status.*failed|attempt_budget.*groom_status.*failed|operational.*failed|groom_status.*failed.*budget|failed.*not.*blocked.*budget|budget.*emit.*failed" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-038 (GF2/GF3): budget/operational exhaustion routes to groom_status:failed (not blocked)"
else
  fail "BT-038 (GF2/GF3): budget/operational exhaustion routes to groom_status:failed (not blocked)" \
       "expected 'budget exhausted => groom_status:failed' language in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-039 (GF2/GF3): failed variant RELEASES the claim (removes status:grooming + unassigns)
# When emitting failed, the agent must release the claim so the issue can be retried.
# ---------------------------------------------------------------------------
if grep -qiE "remove.*status:grooming.*fail|fail.*remove.*status:grooming|release.*claim.*fail|fail.*release.*claim|unassign.*fail|fail.*unassign|remove.*grooming.*label.*fail|emit.*failed.*release" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-039 (GF2/GF3): failed outcome releases claim (removes status:grooming and unassigns)"
else
  fail "BT-039 (GF2/GF3): failed outcome releases claim (removes status:grooming and unassigns)" \
       "expected 'remove status:grooming' + 'unassign' on failure path in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-040 (GF2/GF3): operational/tooling failure is NEVER a blocked reason
# The doc must reiterate the distinction: operational limit != blocked.
# ---------------------------------------------------------------------------
if grep -qiE "operational.*never.*block|never.*block.*operational|tooling.*never.*block|never.*block.*tooling|operational.*not.*block|not.*block.*operational" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-040 (GF2/GF3): doc states operational/tooling failures are NEVER a blocked reason"
else
  fail "BT-040 (GF2/GF3): doc states operational/tooling failures are NEVER a blocked reason" \
       "expected 'operational ... never ... blocked' distinction in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-041 (GF8): explicit rollback path — on failure after claim, remove status:grooming
# The doc must define a FAILURE/ROLLBACK path that triggers on errors after claim.
# ---------------------------------------------------------------------------
if grep -qiE "rollback|ROLLBACK|failure.*path|FAILURE.*path|rollback.on.fail|on.*failure.*rollback|failure.*rollback|remove.*grooming.*interrupt|interrupt.*remove.*grooming" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-041 (GF8): doc defines explicit FAILURE/ROLLBACK path after claim"
else
  fail "BT-041 (GF8): doc defines explicit FAILURE/ROLLBACK path after claim" \
       "expected 'rollback' or 'FAILURE/ROLLBACK path' language in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-042 (GF8): startup stale-claim sweep — find + release abandoned status:grooming issues
# The startup phase must sweep for stale grooming claims left from prior failures.
# ---------------------------------------------------------------------------
if grep -qiE "stale.*claim|claim.*stale|stale.*groom|startup.*sweep|sweep.*startup|sweep.*stale|stale.*sweep|abandoned.*claim|claim.*abandon" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-042 (GF8): startup phase includes stale-claim sweep for abandoned status:grooming issues"
else
  fail "BT-042 (GF8): startup phase includes stale-claim sweep for abandoned status:grooming issues" \
       "expected 'stale claim sweep' or 'abandoned status:grooming' sweep in startup in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-043 (GF5): repo-wide kill precheck BEFORE tier-1
# At the start of select, BEFORE any tier-1 candidate query, check for status:kill issues.
# ---------------------------------------------------------------------------
if grep -qiE "kill.*precheck|precheck.*kill|repo.wide.*kill|kill.*before.*tier|before.*tier.*kill|kill.*switch.*before.*select|select.*kill.*precheck|start of select.*kill|kill.*at.*start.*select" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-043 (GF5): repo-wide kill precheck at start of select (before tier-1)"
else
  fail "BT-043 (GF5): repo-wide kill precheck at start of select (before tier-1)" \
       "expected 'kill precheck' or 'repo-wide kill' check before tier-1 select in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-044 (GF6): target_repo threaded into ALL gh commands via --repo
# The doc must normalize target_repo at startup and thread it into every gh invocation.
# ---------------------------------------------------------------------------
if grep -qiE "\-\-repo.*target_repo|target_repo.*\-\-repo|\"\$target_repo\"|target_repo.*normalize|normalize.*target_repo|every.*gh.*\-\-repo|gh.*command.*\-\-repo" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-044 (GF6): target_repo normalized at startup and threaded into gh commands via --repo"
else
  fail "BT-044 (GF6): target_repo normalized at startup and threaded into gh commands via --repo" \
       "expected '--repo \"\$target_repo\"' or target_repo normalization in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-045 (GF7): worker-investigation used for external docs; 'researcher' NOT referenced
# The invented 'researcher' subagent must be replaced by worker-investigation.
# ---------------------------------------------------------------------------
if ! grep -qiE "^\| \*\*researcher\*\*|\| researcher |researcher.*subagent|spawn.*researcher\b|researcher.*external" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-045 (GF7): 'researcher' subagent NOT referenced (replaced by worker-investigation)"
else
  fail "BT-045 (GF7): 'researcher' subagent NOT referenced (replaced by worker-investigation)" \
       "found 'researcher' reference in subagent table or usage — must be replaced with worker-investigation in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-046 (GF9): scribe Write primitive used for body/comment files (no heredoc for untrusted)
# The write phase must delegate file creation to scribe (Write tool), not use shell heredocs
# for untrusted content.
# ---------------------------------------------------------------------------
if grep -qiE "scribe.*write.*body|scribe.*write.*file|scribe.*body.file|delegate.*scribe.*body|body.*file.*scribe|write.*body.*scribe" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-046 (GF9): scribe Write primitive used to create body/comment files (not heredoc)"
else
  fail "BT-046 (GF9): scribe Write primitive used to create body/comment files (not heredoc)" \
       "expected 'scribe ... Write ... body file' delegation for untrusted content in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-047 (GF9): <<'EOF' heredoc NOT used for untrusted content (injection vector eliminated)
# The doc must not rely on heredoc injection for untrusted issue bodies.
# ---------------------------------------------------------------------------
# The current doc uses <<'EOF' in write phase for issue body. After fix it should be gone
# from the write-phase and untrusted-content section, replaced by scribe Write calls.
# We check that the doc explicitly WARNS against heredoc-for-untrusted, not just avoids it.
if grep -qiE "heredoc.*inject|inject.*heredoc|EOF.*inject|EOF.*break|break.*out.*EOF|EOF.*untrusted|untrusted.*EOF|never.*heredoc.*untrusted|heredoc.*vector" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-047 (GF9): doc warns against heredoc injection vector for untrusted content"
else
  fail "BT-047 (GF9): doc warns against heredoc injection vector for untrusted content" \
       "expected heredoc injection warning in $AGENT_FILE (use scribe Write, not <<'EOF' for untrusted)"
fi

# ---------------------------------------------------------------------------
# BT-048 (GF10): TOCTOU re-fetch checks OPEN + ZERO status labels (not only status:kill)
# The pre-claim re-fetch must abort unless issue is still OPEN and has no status:* labels.
# ---------------------------------------------------------------------------
if grep -qiE "still.*open.*status.less|open.*zero.*status|no.*status.*label.*re.fetch|re.fetch.*open.*no.*status|TOCTOU|toctou|still.*open.*no.*status|re.fetch.*zero.*status" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-048 (GF10): TOCTOU re-fetch checks still-open + zero status:* labels (not only kill)"
else
  fail "BT-048 (GF10): TOCTOU re-fetch checks still-open + zero status:* labels (not only kill)" \
       "expected TOCTOU re-fetch to verify 'still open AND no status:* labels' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-049 (GF11): WATCH activates ONLY on explicit watch=true (no implicit activation)
# The doc must state watch is explicit-only, removing the implicit-activation clause.
# ---------------------------------------------------------------------------
if grep -qiE "watch.*only.*explicit|explicit.*watch.*only|watch.*activate.*explicit|explicit.*watch.*true|watch.*true.*only|only.*when.*watch.*true|ONLY when.*watch.*true" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-049 (GF11): WATCH activates ONLY on explicit watch=true (no implicit activation)"
else
  fail "BT-049 (GF11): WATCH activates ONLY on explicit watch=true (no implicit activation)" \
       "expected 'WATCH only when watch:true is explicitly passed' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-050 (GF12): per-run state reset AFTER poll_interval sleep (before returning to select)
# In WATCH mode, reviewed_ready_this_run and per-run counters must reset each cycle.
# ---------------------------------------------------------------------------
if grep -qiE "reset.*reviewed_ready|reviewed_ready.*reset|reset.*per.run.*watch|watch.*reset.*per.run|reset.*counters.*sleep|sleep.*reset.*counter|cycle.*reset|reset.*each.*cycle|reset.*watch.*cycle" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-050 (GF12): per-run state reset after poll_interval sleep (each watch cycle fresh)"
else
  fail "BT-050 (GF12): per-run state reset after poll_interval sleep (each watch cycle fresh)" \
       "expected 'reset reviewed_ready_this_run ... after sleep' or 'reset ... each cycle' in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-051 (GF13): drifted-ready write path — scribe writes comment file, worker runs gh issue comment
# A ready ticket that has drifted needs a defined write path (not just 'comment and skip').
# ---------------------------------------------------------------------------
if grep -qiE "drifted.*ready.*write|drifted.*write.*path|write.*path.*drift|drift.*write.*branch|drifted.*comment.*file|comment.*file.*drifted|drifted.*scribe|scribe.*drifted" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-051 (GF13): drifted-ready write path defined (scribe writes file, worker runs gh issue comment)"
else
  fail "BT-051 (GF13): drifted-ready write path defined (scribe writes file, worker runs gh issue comment)" \
       "expected explicit drifted-ready write path with scribe+worker in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-052 (GF14): select pagination documented — either paginate to exhaustion or document the limit
# The doc must address pagination beyond --limit 200 for large backlogs.
# ---------------------------------------------------------------------------
if grep -qiE "paginate|pagination|paginate.*exhaustion|exhaustion.*paginate|page.*through|page-through|known.*limit|limit.*constraint|document.*limit.*known|pagination.*large" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-052 (GF14): select pagination addressed (paginate to exhaustion or document constraint)"
else
  fail "BT-052 (GF14): select pagination addressed (paginate to exhaustion or document constraint)" \
       "expected pagination strategy or known-limit documentation for large backlogs in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-053 (GF2/schema): groom_status:failed variant documented with failure_reason field
# The schema regression-notes require a 'failed' variant. The agent doc must document it.
# ---------------------------------------------------------------------------
if grep -qiE "groom_status.*failed|groom_status:.*\"failed\"|Variant.*failed.*groom|failed.*groom_status|failure_reason" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-053 (GF2): groom_status:failed variant documented with failure_reason"
else
  fail "BT-053 (GF2): groom_status:failed variant documented with failure_reason" \
       "expected 'failed' groom_status variant with failure_reason in $AGENT_FILE"
fi

# ===========================================================================
# NEW REGRESSION TESTS — protect the G1–G14 fixes from future reversion
# ===========================================================================

# ---------------------------------------------------------------------------
# RT-012: reviewed_ready_this_run populated AND excluded in tier-2 query (GF1 cannot regress)
# Both add-before-emit AND exclude-from-query must be present.
# ---------------------------------------------------------------------------
has_add_before=$(grep -ciE "add.*reviewed_ready_this_run|reviewed_ready_this_run.*add|ADD.*to.*reviewed_ready|before.*emit.*reviewed|reviewed_ready.*before.*emit" "$AGENT_FILE" 2>/dev/null || true)
has_exclude=$(grep -ciE "exclud.*reviewed_ready|reviewed_ready.*exclud|filter.*reviewed_ready|reviewed_ready.*filter|not.*reviewed_ready" "$AGENT_FILE" 2>/dev/null || true)
if [ "${has_add_before:-0}" -gt 0 ] && [ "${has_exclude:-0}" -gt 0 ]; then
  pass "RT-012 (GF1): anti-infinite guard: both populate-before-emit AND exclude-from-query documented"
else
  fail "RT-012 (GF1): anti-infinite guard: both populate-before-emit AND exclude-from-query documented" \
       "add_before_emit_count=$has_add_before, exclude_count=$has_exclude — need both > 0 in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-013: attempt_budget semantics — retry-only AND failed-not-blocked (GF3/GF4 cannot regress)
# Both the retry-only definition AND the failed routing must be present.
# ---------------------------------------------------------------------------
has_retry_only=$(grep -ciE "attempt_budget.*retry|retry.*attempt_budget|budget.*only.*retry|only.*retry.*budget|count.*only.*retry" "$AGENT_FILE" 2>/dev/null || true)
has_failed_route=$(grep -ciE "budget.*exhausted.*failed|exhausted.*groom_status.*failed|attempt_budget.*groom_status.*failed|groom_status.*failed.*budget" "$AGENT_FILE" 2>/dev/null || true)
if [ "${has_retry_only:-0}" -gt 0 ] && [ "${has_failed_route:-0}" -gt 0 ]; then
  pass "RT-013 (GF3/GF4): attempt_budget: retry-only semantics AND failed-not-blocked routing both documented"
else
  fail "RT-013 (GF3/GF4): attempt_budget: retry-only semantics AND failed-not-blocked routing both documented" \
       "retry_only_count=$has_retry_only, failed_route_count=$has_failed_route — need both > 0 in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-014: rollback path + startup sweep both present (GF8 cannot regress)
# ---------------------------------------------------------------------------
has_rollback=$(grep -ciE "rollback|ROLLBACK|failure.*path|FAILURE.*path" "$AGENT_FILE" 2>/dev/null || true)
has_sweep=$(grep -ciE "stale.*claim|claim.*stale|stale.*groom|startup.*sweep|sweep.*startup|sweep.*stale|stale.*sweep" "$AGENT_FILE" 2>/dev/null || true)
if [ "${has_rollback:-0}" -gt 0 ] && [ "${has_sweep:-0}" -gt 0 ]; then
  pass "RT-014 (GF8): rollback-on-failure path AND startup stale-claim sweep both documented"
else
  fail "RT-014 (GF8): rollback-on-failure path AND startup stale-claim sweep both documented" \
       "rollback_count=$has_rollback, sweep_count=$has_sweep — need both > 0 in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-015: worker-investigation replaces researcher AND target_repo threaded (GF6/GF7 cannot regress)
# ---------------------------------------------------------------------------
no_researcher=$(! grep -qiE "^\| \*\*researcher\*\*|\| researcher |spawn.*researcher\b" "$AGENT_FILE" 2>/dev/null && echo 1 || echo 0)
has_repo_flag=$(grep -ciE "\-\-repo.*target_repo|target_repo.*\-\-repo|\"\$target_repo\"" "$AGENT_FILE" 2>/dev/null || true)
if [ "$no_researcher" = "1" ] && [ "${has_repo_flag:-0}" -gt 0 ]; then
  pass "RT-015 (GF6/GF7): researcher removed AND --repo \$target_repo threaded into gh commands"
else
  fail "RT-015 (GF6/GF7): researcher removed AND --repo \$target_repo threaded into gh commands" \
       "no_researcher=$no_researcher (1=good), repo_flag_count=$has_repo_flag — need no_researcher=1 and repo_flag>0 in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-016: WATCH explicit-only + per-cycle reset both documented (GF11/GF12 cannot regress)
# ---------------------------------------------------------------------------
has_explicit_watch=$(grep -ciE "watch.*only.*explicit|explicit.*watch.*only|ONLY when.*watch.*true|only.*when.*watch.*true|watch.*activate.*explicit" "$AGENT_FILE" 2>/dev/null || true)
has_cycle_reset=$(grep -ciE "reset.*reviewed_ready|reviewed_ready.*reset|reset.*per.run.*watch|cycle.*reset|reset.*each.*cycle|reset.*watch.*cycle" "$AGENT_FILE" 2>/dev/null || true)
if [ "${has_explicit_watch:-0}" -gt 0 ] && [ "${has_cycle_reset:-0}" -gt 0 ]; then
  pass "RT-016 (GF11/GF12): WATCH explicit-activation AND per-cycle state reset both documented"
else
  fail "RT-016 (GF11/GF12): WATCH explicit-activation AND per-cycle state reset both documented" \
       "explicit_watch_count=$has_explicit_watch, cycle_reset_count=$has_cycle_reset — need both > 0 in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-017: five groom_status variants documented — including 'failed' (cannot remove one)
# ---------------------------------------------------------------------------
all_five_variants=0
for variant in "ready" "blocked" "skipped" "terminal" "failed"; do
  if grep -qiE "groom_status.*\"${variant}\"|groom_status:.*${variant}|Variant.*${variant}.*groom|${variant}.*groom_status|failure_reason" "$AGENT_FILE" 2>/dev/null; then
    all_five_variants=$((all_five_variants + 1))
  fi
done
if [ "$all_five_variants" -eq 5 ]; then
  pass "RT-017: all five groom_status variants documented (ready/blocked/skipped/terminal/failed)"
else
  fail "RT-017: all five groom_status variants documented" \
       "only found $all_five_variants of 5 variants (ready/blocked/skipped/terminal/failed) in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-018: FAILURE/ROLLBACK path specifically removes status:grooming AND unassigns (GF8)
# Both the label removal AND the unassign must be documented together — neither alone is sufficient.
# ---------------------------------------------------------------------------
has_remove_grooming=$(grep -ciE "remove.*status:grooming|status:grooming.*remove" "$AGENT_FILE" 2>/dev/null || true)
has_unassign=$(grep -ciE "remove.assignee|unassign" "$AGENT_FILE" 2>/dev/null || true)
if [ "${has_remove_grooming:-0}" -gt 0 ] && [ "${has_unassign:-0}" -gt 0 ]; then
  pass "RT-018 (GF8): FAILURE/ROLLBACK path removes status:grooming AND unassigns (both required)"
else
  fail "RT-018 (GF8): FAILURE/ROLLBACK path removes status:grooming AND unassigns (both required)" \
       "remove_grooming_count=$has_remove_grooming, unassign_count=$has_unassign — need both > 0 in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-019: kill precheck uses status:kill label filter (not just generic kill language)
# Catches regression where precheck language becomes vague and doesn't specify the label.
# ---------------------------------------------------------------------------
if grep -qiE "status:kill.*precheck|precheck.*status:kill|--label.*status:kill.*before|status:kill.*before.*tier" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-019 (GF5): kill precheck specifically queries status:kill label before tier-1"
else
  fail "RT-019 (GF5): kill precheck specifically queries status:kill label before tier-1" \
       "expected kill precheck to reference 'status:kill' label in the precheck query in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-020: attempt_budget default value explicitly stated as retry-cycles (not generic cycles)
# Catches regression where the default reverts to counting all delegate cycles.
# ---------------------------------------------------------------------------
if grep -qiE "attempt_budget.*default.*3.*retry|attempt_budget.*3.*retry|default.*3.*retry.*cycle|3.*retry.*cycle.*default" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-020 (GF4): attempt_budget default explicitly stated as '3 retry cycles'"
else
  fail "RT-020 (GF4): attempt_budget default explicitly stated as '3 retry cycles'" \
       "expected 'attempt_budget ... default ... 3 ... retry cycle' in $AGENT_FILE"
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
