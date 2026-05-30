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
# BT-005: state machine — all required phases appear as labeled headings/steps
# (tightened: bare word match is NOT sufficient; each phase must appear as a
# numbered heading like "#### 1. `startup`" or as "startup" in a labeled-step
# context so removal of a phase description would cause this test to fail)
# ---------------------------------------------------------------------------
MISSING_PHASES=()
for phase in startup select claim ground plan delegate integrate review test validate close; do
  # Require the phase to appear as a markdown heading (### or ####) with the phase word,
  # OR as a numbered step pattern like "1. `startup`" — not just a bare word anywhere.
  if ! grep -qiE "^#+[[:space:]].*\b${phase}\b|^[[:space:]]*[0-9]+\.[[:space:]]+\`${phase}\`" "$AGENT_FILE" 2>/dev/null; then
    MISSING_PHASES+=("$phase")
  fi
done
if [ ${#MISSING_PHASES[@]} -eq 0 ]; then
  pass "BT-005: every state-machine phase appears as a heading or labeled step (startup through close)"
else
  fail "BT-005: every state-machine phase appears as a heading or labeled step" \
       "missing phases as headings/steps: ${MISSING_PHASES[*]}"
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
# BT-011: per-variant output shapes documented — completed variant names its fields
# The doc must explicitly document the 'completed' variant with its required fields.
# ---------------------------------------------------------------------------
if grep -qi "completed.*goal_id\|loop_status.*completed\|completed.*issue_number\|completed.*pr_url\|completed.*audit_trail_commits\|completed.*behavioral_tests\|completed.*tdd_evidence" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-011: doc documents 'completed' variant with its required fields"
else
  fail "BT-011: doc documents 'completed' variant with its required fields" \
       "expected 'completed' variant with field documentation (goal_id, issue_number, pr_url, audit_trail_commits, behavioral_tests, tdd_evidence) in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-012: per-variant output shapes documented — blocked variant names its fields
# The doc must explicitly document the 'blocked' variant with blocked:true and blocked_reason.
# ---------------------------------------------------------------------------
if grep -qi "blocked.*goal_id\|loop_status.*blocked\|blocked.*blocked_reason\|blocked.*claim_evidence\|blocked.*pr_url.*null\|blocked_reason" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-012: doc documents 'blocked' variant with its required fields"
else
  fail "BT-012: doc documents 'blocked' variant with its required fields" \
       "expected 'blocked' variant documentation with blocked_reason and pr_url:null in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-013: per-variant output shapes documented — terminal variant names its fields
# The doc must explicitly document the 'terminal' variant with run_stop_reason.
# ---------------------------------------------------------------------------
if grep -qi "terminal.*goal_id\|loop_status.*terminal\|terminal.*run_stop_reason\|terminal.*recommended_next_step" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-013: doc documents 'terminal' variant with its required fields"
else
  fail "BT-013: doc documents 'terminal' variant with its required fields" \
       "expected 'terminal' variant documentation with run_stop_reason in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-014: per-issue total attempt budget documented (F3 — bound all loops)
# The doc must define a per-issue total attempt budget (e.g. default 3) that
# spans the review/test/validate→delegate re-delegation cycles.
# The ci_retry_budget only covers CI retries; a separate attempt_budget (or
# total_attempt_budget) is needed to cap ALL re-delegation cycles (review, test,
# validate, etc.). Must use the specific variable name to be unambiguous.
# ---------------------------------------------------------------------------
if grep -qE "attempt_budget|total_attempt_budget" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-014: doc documents per-issue total attempt budget (attempt_budget)"
else
  fail "BT-014: doc documents per-issue total attempt budget (attempt_budget)" \
       "expected 'attempt_budget' or 'total_attempt_budget' variable name in $AGENT_FILE — bounded re-delegation loop requires explicit budget"
fi

# ---------------------------------------------------------------------------
# BT-015: circuit-breaker semantics documented (F4 — resolve contradiction)
# The doc must clearly state:
#   - per-issue CI exhaustion → block THAT issue and CONTINUE the loop
#   - consecutive CI-blocked issues → run-level circuit breaker (stop)
# ---------------------------------------------------------------------------
if grep -qiE "circuit.breaker|consecutive.*block|block.*consecutive|systemic|consecutive.*ci|ci.*consecutive" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-015: doc documents circuit-breaker semantics for consecutive CI failures"
else
  fail "BT-015: doc documents circuit-breaker semantics for consecutive CI failures" \
       "expected circuit-breaker or consecutive-block semantics in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-016: per-issue CI exhaustion is block-and-continue (not run-stop)
# The doc must explicitly state that exhausting ci_retry_budget for ONE issue
# blocks that issue but the loop CONTINUES to the next issue.
# Must be in the context of CI/pnpm verify (not just the general blocked path).
# ---------------------------------------------------------------------------
if grep -qiE "ci.*budget.*block.*continue|ci_retry.*block.*continue|pnpm.*verify.*block.*continue|ci.*exhaust.*continue.*loop|budget.*exhaust.*block.*issue.*continue|per.issue.*ci.*block.*continue" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-016: doc states per-issue CI exhaustion = block-and-continue (not run-stop)"
else
  fail "BT-016: doc states per-issue CI exhaustion = block-and-continue (not run-stop)" \
       "expected explicit text that CI-budget exhaustion blocks the issue but the loop continues in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-017: untrusted issue content section present (F5)
# The doc must have a section explicitly flagging issue-derived text (title, body)
# as UNTRUSTED, and requiring branch-slug whitelist and --body-file for PR/comments.
# ---------------------------------------------------------------------------
if grep -qiE "untrusted|UNTRUSTED|untruste" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-017: doc contains untrusted-issue-content section"
else
  fail "BT-017: doc contains untrusted-issue-content section" \
       "expected 'UNTRUSTED' or 'untrusted' section for issue-derived content in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-018: branch slug whitelist documented (F5)
# Branch slugs must be whitelisted to [a-z0-9-] characters.
# ---------------------------------------------------------------------------
if grep -qiE "\[a-z0-9-\]|whitelist.*slug|slug.*whitelist|sanitize.*branch|branch.*sanitize|a-z.*0-9.*slug|slug.*a-z.*0-9" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-018: doc documents branch-slug character whitelist [a-z0-9-]"
else
  fail "BT-018: doc documents branch-slug character whitelist [a-z0-9-]" \
       "expected '[a-z0-9-]' branch slug whitelist in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-019: --body-file pattern documented for PR/comment bodies (F5)
# PR titles/bodies and issue comments must use --body-file to avoid injection.
# ---------------------------------------------------------------------------
if grep -qiE "\-\-body-file|body.file|body_file" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-019: doc documents --body-file pattern for PR/comment bodies"
else
  fail "BT-019: doc documents --body-file pattern for PR/comment bodies" \
       "expected '--body-file' pattern for safe PR/comment bodies in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-020: gh issue list uses --limit flag (F6)
# Without --limit, gh silently caps at 30 and starves older issues.
# The select query must use --limit (e.g., --limit 200).
# ---------------------------------------------------------------------------
if grep -qiE "\-\-limit[[:space:]]+[0-9]|--limit [0-9]" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-020: select query uses --limit flag to avoid silent 30-issue cap"
else
  fail "BT-020: select query uses --limit flag to avoid silent 30-issue cap" \
       "expected '--limit <N>' in gh issue list select query in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-021: client-side sort documented for select (F6)
# After fetching with --limit, the doc must sort by issue number or createdAt
# ascending client-side to guarantee the oldest issue is selected.
# ---------------------------------------------------------------------------
if grep -qiE "sort.*client|client.*sort|sort.*ascending|ascending.*sort|sort.*number|sort.*createdAt|createdAt.*sort|jq.*sort|sort_by" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-021: select step documents client-side sort to pick oldest issue"
else
  fail "BT-021: select step documents client-side sort to pick oldest issue" \
       "expected client-side sort (e.g. jq sort_by) in select query documentation in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-022: kill-switch re-check before claim documented (F7)
# The candidate's labels must be RE-FETCHED immediately before the claim
# mutation to catch a kill label applied in the select→claim window.
# Requires explicit re-fetch/re-check language in the claim phase (not just
# the select-phase check — both must be present, and this test verifies the
# claim-phase re-check specifically using "re-fetch" or "re-check" language).
# ---------------------------------------------------------------------------
if grep -qiE "re.fetch.*label|re.fetch.*kill|re-fetch.*before|re-check.*before.*claim|immediately before.*claim|claim.*phase.*kill|claim.*re.fetch|re.fetch.*claim" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-022: doc documents kill-switch label re-fetch immediately before claim mutation"
else
  fail "BT-022: doc documents kill-switch label re-fetch immediately before claim mutation" \
       "expected explicit re-fetch of labels before claim mutation (not just select-phase check) in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-023: coord-validate usage with file path documented in output contract
# The doc must instruct the agent to validate output via coord-validate <file>
# (file path, not stdin) — specifically in the output-contract section.
# ---------------------------------------------------------------------------
if grep -qiE "coord-validate issue-implementer" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-023: doc shows coord-validate usage with 'coord-validate issue-implementer'"
else
  fail "BT-023: doc shows coord-validate usage with 'coord-validate issue-implementer'" \
       "expected 'coord-validate issue-implementer' usage example in $AGENT_FILE"
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
# RT-006: attempt_budget appears in the Stop Conditions table
# If the per-issue attempt_budget is removed from the table, this fails.
# The table is the canonical reference for operators; it must include this row.
# ---------------------------------------------------------------------------
if grep -qE "attempt_budget" "$AGENT_FILE" 2>/dev/null && \
   grep -qE "\| *\`attempt_budget\`|\battempt_budget\b.*default.*3|default.*3.*attempt_budget" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-006: attempt_budget appears in the Stop Conditions table with default value 3"
else
  fail "RT-006: attempt_budget appears in the Stop Conditions table with default value 3" \
       "expected attempt_budget with default 3 in Stop Conditions table in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-007: circuit-breaker threshold has an explicit default (3) documented
# If the circuit-breaker default is removed or changed without updating docs,
# this fails — ensuring operators know the default before overriding it.
# ---------------------------------------------------------------------------
if grep -qiE "consecutive.*threshold.*3|threshold.*3.*consecutive|default.*3.*consecutive|consecutive.*block.*3|threshold.*default.*3" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-007: circuit-breaker consecutive threshold default (3) is documented"
else
  fail "RT-007: circuit-breaker consecutive threshold default (3) is documented" \
       "expected circuit-breaker threshold default '3' documented in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-008: Output Contract section names all three loop_status variants
# If one variant is removed from the Output Contract section, this fails.
# Tests that the per-variant documentation is complete, not just partial.
# ---------------------------------------------------------------------------
variants_found=0
for variant in "completed" "blocked" "terminal"; do
  if grep -qE "loop_status.*\"${variant}\"|loop_status:.*\"${variant}\"|Variant.*${variant}" "$AGENT_FILE" 2>/dev/null; then
    variants_found=$((variants_found + 1))
  fi
done
if [ "$variants_found" -eq 3 ]; then
  pass "RT-008: Output Contract section documents all three loop_status variants (completed/blocked/terminal)"
else
  fail "RT-008: Output Contract section documents all three loop_status variants" \
       "only found $variants_found of 3 variants (completed/blocked/terminal) in Output Contract in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# RT-009: kill-switch re-check (F7) mentions "re-fetch" in claim phase context
# If the re-fetch guard is removed from the claim phase, this fails.
# Must be more specific than just any mention of kill in the file.
# ---------------------------------------------------------------------------
if grep -qiE "re.fetch.*label|re-fetch.*before|re-fetch.*claim|re.fetch.*kill" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-009: kill-switch re-fetch guard preserved in claim phase"
else
  fail "RT-009: kill-switch re-fetch guard preserved in claim phase" \
       "expected re-fetch of labels before claim in $AGENT_FILE — F7 guard may have been removed"
fi

# ---------------------------------------------------------------------------
# RT-010: untrusted content section uses specific word UNTRUSTED
# If the section is softened to just advisory language without the UNTRUSTED
# designation, this test fails — preserving the security posture.
# ---------------------------------------------------------------------------
if grep -q "UNTRUSTED" "$AGENT_FILE" 2>/dev/null; then
  pass "RT-010: untrusted content section uses the word UNTRUSTED (security-posture preserved)"
else
  fail "RT-010: untrusted content section uses the word UNTRUSTED" \
       "expected uppercase UNTRUSTED in security section — section may have been softened in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-024: worker-selection table does NOT have a routing row for 'refactor'
# The table cell mapping 'refactor' to 'worker-refactor' must be absent.
# The "Deferred" note WILL mention 'refactor' by name — so we must NOT just
# check for word presence. We look for a table row that maps refactor to a
# worker (pipe-separated, with 'refactor' as the task-type cell).
# ---------------------------------------------------------------------------
if grep -qiE "^\|[[:space:]]*\`?refactor\`?[[:space:]]*\|" "$AGENT_FILE" 2>/dev/null; then
  fail "BT-024: worker-selection table has no routing row for 'refactor'" \
       "found a table row with 'refactor' as task type — routing row must be removed (Deferred note is ok)"
else
  pass "BT-024: worker-selection table has no routing row for 'refactor'"
fi

# ---------------------------------------------------------------------------
# BT-025: worker-selection table does NOT have a routing row for 'test'
# Same logic as BT-024 — the Deferred note may mention 'test', but no pipe row
# should map 'test' as a task type to a worker.
# ---------------------------------------------------------------------------
if grep -qiE "^\|[[:space:]]*\`?test\`?[[:space:]]*\|" "$AGENT_FILE" 2>/dev/null; then
  fail "BT-025: worker-selection table has no routing row for 'test'" \
       "found a table row with 'test' as task type — routing row must be removed (Deferred note is ok)"
else
  pass "BT-025: worker-selection table has no routing row for 'test'"
fi

# ---------------------------------------------------------------------------
# BT-026: doc contains the "Deferred — refactor/test" note
# The note must explain that refactor/test issue types are not in v1 and
# mention what would need to be done to restore them.
# ---------------------------------------------------------------------------
if grep -qiE "Deferred.*refactor.test|Deferred.*refactor/test|deferred.*refactor.*test" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-026: doc contains the 'Deferred — refactor/test' note"
else
  fail "BT-026: doc contains the 'Deferred — refactor/test' note" \
       "expected 'Deferred' note about refactor/test issue types in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-027: close phase documents DoD checklist rendered as markdown checkboxes
# The close phase PR body must include the DoD checklist as real markdown
# checkboxes (- [x] / - [ ]) mirroring dod_checklist_results.
# ---------------------------------------------------------------------------
if grep -qiE "\- \[x\]|\- \[ \]|dod_checklist_results.*checkbox|checkbox.*dod_checklist|markdown.*checkbox.*dod|dod.*markdown.*checkbox" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-027: close phase documents DoD checklist as markdown checkboxes"
else
  fail "BT-027: close phase documents DoD checklist as markdown checkboxes" \
       "expected '- [x]' / '- [ ]' checkbox pattern or dod_checklist_results checkbox reference in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-028: close phase documents collapsible <details>/<summary> raw-report block
# The PR body must include a <details><summary>Machine-readable run report</summary>
# block with the full raw JSON report.
# ---------------------------------------------------------------------------
if grep -qiE "<details>|<summary>.*[Mm]achine.readable|<summary>.*[Rr]un [Rr]eport" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-028: close phase documents collapsible <details>/<summary> raw-report block"
else
  fail "BT-028: close phase documents collapsible <details>/<summary> raw-report block" \
       "expected '<details><summary>Machine-readable run report</summary>' pattern in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-029: close phase explicitly uses --body-file for PR creation (not inline)
# The PR body built from the goal report must be passed via --body-file <tempfile>
# to avoid shell injection from untrusted issue content.
# ---------------------------------------------------------------------------
if grep -qiE "\-\-body-file.*tempfile|\-\-body-file.*tmp|body.file.*pr.*create|pr.*create.*body.file|--body-file.*pr.body" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-029: close phase uses --body-file <tempfile> for PR creation"
else
  fail "BT-029: close phase uses --body-file <tempfile> for PR creation" \
       "expected '--body-file <tempfile>' pattern in close phase PR creation in $AGENT_FILE"
fi

# ---------------------------------------------------------------------------
# BT-030: close phase states the PR is self-contained proof (no .coord/ link)
# The doc must explicitly state the PR body is the durable proof and that
# .coord/ is ephemeral/gitignored — NOT to rely on .coord/ links.
# ---------------------------------------------------------------------------
if grep -qiE "\.coord.*ephemeral|ephemeral.*\.coord|\.coord.*gitignored|gitignored.*\.coord|self.contained.*proof|PR.*durable.*proof|durable.*proof.*PR|do not store.*\.coord|not.*store.*only.*\.coord" "$AGENT_FILE" 2>/dev/null; then
  pass "BT-030: close phase states PR is self-contained proof (not .coord/ link)"
else
  fail "BT-030: close phase states PR is self-contained proof (not .coord/ link)" \
       "expected statement that .coord/ is ephemeral/gitignored and PR body is the durable proof in $AGENT_FILE"
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
