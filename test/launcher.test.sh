#!/usr/bin/env bash
# test/launcher.test.sh
# Asserts that bin/claude-coord is structurally correct, contains no token
# literals, maps basenames to the right agents, exits 2 on unknown invocation
# name, and exits 1 with a helpful message when no token is available.
#
# Exit 0 = all assertions pass. Exit 1 = at least one assertion failed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/claude-coord"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)) || true; }
fail() { echo "  FAIL: $1"; ((FAIL++)) || true; }

# ---------------------------------------------------------------------------
# Section 1 — Script exists and is executable
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 1: script exists and is executable ==="

if [[ -f "$SCRIPT" ]]; then
  pass "bin/claude-coord exists"
else
  fail "bin/claude-coord does NOT exist"
fi

if [[ -x "$SCRIPT" ]]; then
  pass "bin/claude-coord is executable"
else
  fail "bin/claude-coord is NOT executable (chmod +x missing)"
fi

# ---------------------------------------------------------------------------
# Section 2 — bash -n syntax check
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 2: bash -n syntax parse ==="

if bash -n "$SCRIPT" 2>/dev/null; then
  pass "bash -n bin/claude-coord: syntax OK"
else
  fail "bash -n bin/claude-coord: syntax ERRORS"
fi

# ---------------------------------------------------------------------------
# Section 3 — SECURITY: no token literal in the committed script
# A token literal is any string starting with plat_sa_ or otherwise matching
# the Gamut token prefix pattern. Also check for common secret patterns.
# This test MUST FAIL if someone accidentally hardcodes a token.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 3 (SECURITY): no token literal in bin/claude-coord ==="

# Fail if the file contains the plat_sa_ prefix (Gamut service-account token)
if grep -q 'plat_sa_' "$SCRIPT" 2>/dev/null; then
  fail "SECURITY: bin/claude-coord contains 'plat_sa_' — token literal detected!"
else
  pass "bin/claude-coord does NOT contain 'plat_sa_' token prefix"
fi

# Fail if the file contains any obvious token-like 40+ char alphanumeric run
# (heuristic: a line that has a 40-char hex or base64-ish string not in a comment)
SUSPICIOUS=$(grep -oE '[A-Za-z0-9_-]{40,}' "$SCRIPT" 2>/dev/null | grep -v '^#' | grep -v 'platformproxy' | grep -v 'gamutagents' | grep -v 'ANTHROPIC' | grep -v 'GAMUT_AUTH_TOKEN' | grep -v 'dangerously' | grep -v 'issue.groomer\|issue.implementer\|issue-groomer\|issue-implementer' || true)
if [[ -n "$SUSPICIOUS" ]]; then
  fail "SECURITY: possible long token-like string found in script: $SUSPICIOUS"
else
  pass "No suspicious 40+ char token-like strings found in script"
fi

# ---------------------------------------------------------------------------
# Section 4 — SECURITY: no token literal in the test file itself
# (Prevents accidentally committing a token in test fixtures)
# We search for a token VALUE: the prefix followed by alphanumeric chars
# (an actual credential), not just the prefix string used in a grep pattern.
# The regex is split across two variables so THIS grep doesn't match itself.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 4 (SECURITY): no token literal in test/launcher.test.sh ==="

SELF="${BASH_SOURCE[0]}"
# Split pattern so this script's own grep call doesn't self-match
TOKEN_PREFIX='plat_sa'
TOKEN_SUFFIX='_[A-Za-z0-9]'
if grep -qE "${TOKEN_PREFIX}${TOKEN_SUFFIX}" "$SELF" 2>/dev/null; then
  fail "SECURITY: test/launcher.test.sh contains a token value — token literal in test!"
else
  pass "test/launcher.test.sh does NOT contain a token value"
fi

# ---------------------------------------------------------------------------
# Section 5 — Agent name mapping: both known names are referenced
# (Static grep — does not execute cco)
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 5: agent name mapping present in script ==="

if grep -q 'issue-groomer' "$SCRIPT"; then
  pass "bin/claude-coord references 'issue-groomer'"
else
  fail "bin/claude-coord does NOT reference 'issue-groomer'"
fi

if grep -q 'issue-implementer' "$SCRIPT"; then
  pass "bin/claude-coord references 'issue-implementer'"
else
  fail "bin/claude-coord does NOT reference 'issue-implementer'"
fi

# Confirm the basename dispatch is present
if grep -q 'basename' "$SCRIPT"; then
  pass "bin/claude-coord uses 'basename' for invocation-name dispatch"
else
  fail "bin/claude-coord does NOT use 'basename' for invocation-name dispatch"
fi

# ---------------------------------------------------------------------------
# Section 6 — Unknown basename exits 2
# Run the script directly (not via a symlink) — its basename is "claude-coord"
# which is not a known launcher name, so it must exit 2.
# We must not have cco available in this test since it must NOT be called.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 6: unknown basename -> exit 2 ==="

# Temporarily prepend a fake-cco dir to PATH to prevent actual cco invocation.
# We want the dispatch guard to trigger BEFORE any token/cco logic.
FAKE_BIN=$(mktemp -d)
cat > "$FAKE_BIN/cco" <<'EOFSTUB'
#!/usr/bin/env bash
echo "STUB: cco should not have been called in basename dispatch test" >&2
exit 99
EOFSTUB
chmod +x "$FAKE_BIN/cco"

EXIT_CODE=0
bash "$SCRIPT" 2>/dev/null || EXIT_CODE=$?
rm -rf "$FAKE_BIN"

if [[ "$EXIT_CODE" -eq 2 ]]; then
  pass "Invoking as 'bash bin/claude-coord' (unknown basename 'bash') exits 2"
else
  fail "Expected exit 2 for unknown basename, got: $EXIT_CODE"
fi

# ---------------------------------------------------------------------------
# Section 7 — Known basename with no token -> exit 1 with helpful message
# Simulate claude-groom invocation by creating a symlink to the script in a
# temp dir, then calling it with GAMUT_AUTH_TOKEN= and a fake HOME (no token file).
# We override PATH so cco cannot be found at all — exit 1 must come from token
# validation, not from cco being absent.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 7: claude-groom with no token -> exit 1 + helpful message ==="

TMPDIR_GROOM=$(mktemp -d)
ln -sf "$SCRIPT" "$TMPDIR_GROOM/claude-groom"

# Use a fake HOME with no cco-gamut/token file, and strip real PATH to no cco
FAKE_HOME=$(mktemp -d)
STDERR_OUT=$(mktemp)

EXIT_CODE_GROOM=0
GAMUT_AUTH_TOKEN= HOME="$FAKE_HOME" PATH="/usr/bin:/bin" \
  bash "$TMPDIR_GROOM/claude-groom" 2>"$STDERR_OUT" || EXIT_CODE_GROOM=$?

STDERR_CONTENT=$(cat "$STDERR_OUT")
rm -rf "$TMPDIR_GROOM" "$FAKE_HOME" "$STDERR_OUT"

if [[ "$EXIT_CODE_GROOM" -eq 1 ]]; then
  pass "claude-groom with no token exits 1"
else
  fail "Expected exit 1 for missing token, got: $EXIT_CODE_GROOM"
fi

# The error message must mention how to provide the token
if echo "$STDERR_CONTENT" | grep -qi 'GAMUT_AUTH_TOKEN\|cco-gamut'; then
  pass "Error message mentions GAMUT_AUTH_TOKEN or cco-gamut token path"
else
  fail "Error message does not explain how to provide the token. Got: $STDERR_CONTENT"
fi

# ---------------------------------------------------------------------------
# Section 8 — claude-groom invokes cco with correct agent
# Use a stub cco that echoes its arguments. Provide a token via env var.
# Assert that --agent issue-groomer appears in the args.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 8: claude-groom stub-invokes cco with --agent issue-groomer ==="

TMPDIR_STUB=$(mktemp -d)
ln -sf "$SCRIPT" "$TMPDIR_STUB/claude-groom"

# Create a stub cco that records its arguments and exits 0
STUB_BIN=$(mktemp -d)
STUB_OUT=$(mktemp)
cat > "$STUB_BIN/cco" <<EOFSTUB
#!/usr/bin/env bash
echo "\$@" > "$STUB_OUT"
exit 0
EOFSTUB
chmod +x "$STUB_BIN/cco"

EXIT_CODE_STUB=0
GAMUT_AUTH_TOKEN="test-token-value" HOME="$(mktemp -d)" PATH="$STUB_BIN:/usr/bin:/bin" \
  bash "$TMPDIR_STUB/claude-groom" 2>/dev/null || EXIT_CODE_STUB=$?

STUB_ARGS=$(cat "$STUB_OUT" 2>/dev/null || true)
rm -rf "$TMPDIR_STUB" "$STUB_BIN" "$STUB_OUT"

if [[ "$EXIT_CODE_STUB" -eq 0 ]]; then
  pass "claude-groom with token exits 0 (stub cco ran successfully)"
else
  fail "claude-groom with token exited $EXIT_CODE_STUB (expected 0)"
fi

if echo "$STUB_ARGS" | grep -q -- '--agent issue-groomer'; then
  pass "cco was called with '--agent issue-groomer'"
else
  fail "cco was NOT called with '--agent issue-groomer'. Args: $STUB_ARGS"
fi

if echo "$STUB_ARGS" | grep -q -- '--dangerously-skip-permissions'; then
  pass "cco was called with '--dangerously-skip-permissions'"
else
  fail "cco was NOT called with '--dangerously-skip-permissions'. Args: $STUB_ARGS"
fi

# ---------------------------------------------------------------------------
# Section 9 — claude-implement stub-invokes cco with --agent issue-implementer
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 9: claude-implement stub-invokes cco with --agent issue-implementer ==="

TMPDIR_IMPL=$(mktemp -d)
ln -sf "$SCRIPT" "$TMPDIR_IMPL/claude-implement"

STUB_BIN2=$(mktemp -d)
STUB_OUT2=$(mktemp)
cat > "$STUB_BIN2/cco" <<EOFSTUB2
#!/usr/bin/env bash
echo "\$@" > "$STUB_OUT2"
exit 0
EOFSTUB2
chmod +x "$STUB_BIN2/cco"

EXIT_CODE_IMPL=0
GAMUT_AUTH_TOKEN="test-token-value" HOME="$(mktemp -d)" PATH="$STUB_BIN2:/usr/bin:/bin" \
  bash "$TMPDIR_IMPL/claude-implement" 2>/dev/null || EXIT_CODE_IMPL=$?

IMPL_ARGS=$(cat "$STUB_OUT2" 2>/dev/null || true)
rm -rf "$TMPDIR_IMPL" "$STUB_BIN2" "$STUB_OUT2"

if [[ "$EXIT_CODE_IMPL" -eq 0 ]]; then
  pass "claude-implement with token exits 0 (stub cco ran successfully)"
else
  fail "claude-implement with token exited $EXIT_CODE_IMPL (expected 0)"
fi

if echo "$IMPL_ARGS" | grep -q -- '--agent issue-implementer'; then
  pass "cco was called with '--agent issue-implementer'"
else
  fail "cco was NOT called with '--agent issue-implementer'. Args: $IMPL_ARGS"
fi

# ---------------------------------------------------------------------------
# Section 10 — REGRESSION: token file fallback (no env var, file has token)
# If GAMUT_AUTH_TOKEN is unset but ~/.config/cco-gamut/token exists and is
# readable, the script must read it and invoke cco (not exit 1).
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 10 (regression): token file fallback works ==="

TMPDIR_FILE=$(mktemp -d)
ln -sf "$SCRIPT" "$TMPDIR_FILE/claude-groom"

FAKE_HOME_FILE=$(mktemp -d)
mkdir -p "$FAKE_HOME_FILE/.config/cco-gamut"
echo "file-based-token-value" > "$FAKE_HOME_FILE/.config/cco-gamut/token"
chmod 600 "$FAKE_HOME_FILE/.config/cco-gamut/token"

STUB_BIN3=$(mktemp -d)
STUB_OUT3=$(mktemp)
cat > "$STUB_BIN3/cco" <<EOFSTUB3
#!/usr/bin/env bash
echo "\$@" > "$STUB_OUT3"
exit 0
EOFSTUB3
chmod +x "$STUB_BIN3/cco"

EXIT_CODE_FILE=0
GAMUT_AUTH_TOKEN="" HOME="$FAKE_HOME_FILE" PATH="$STUB_BIN3:/usr/bin:/bin" \
  bash "$TMPDIR_FILE/claude-groom" 2>/dev/null || EXIT_CODE_FILE=$?

FILE_ARGS=$(cat "$STUB_OUT3" 2>/dev/null || true)
rm -rf "$TMPDIR_FILE" "$FAKE_HOME_FILE" "$STUB_BIN3" "$STUB_OUT3"

if [[ "$EXIT_CODE_FILE" -eq 0 ]]; then
  pass "Token file fallback: exits 0 when token file exists"
else
  fail "Token file fallback: expected exit 0, got $EXIT_CODE_FILE"
fi

if echo "$FILE_ARGS" | grep -q -- '--agent issue-groomer'; then
  pass "Token file fallback: cco still called with correct agent"
else
  fail "Token file fallback: cco not called with --agent issue-groomer. Args: $FILE_ARGS"
fi

# ---------------------------------------------------------------------------
# Section 11 — REGRESSION: extra args are passed through to cco
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 11 (regression): extra args are passed through to cco ==="

TMPDIR_ARGS=$(mktemp -d)
ln -sf "$SCRIPT" "$TMPDIR_ARGS/claude-groom"

STUB_BIN4=$(mktemp -d)
STUB_OUT4=$(mktemp)
cat > "$STUB_BIN4/cco" <<EOFSTUB4
#!/usr/bin/env bash
echo "\$@" > "$STUB_OUT4"
exit 0
EOFSTUB4
chmod +x "$STUB_BIN4/cco"

EXIT_CODE_ARGS=0
GAMUT_AUTH_TOKEN="test-token-value" HOME="$(mktemp -d)" PATH="$STUB_BIN4:/usr/bin:/bin" \
  bash "$TMPDIR_ARGS/claude-groom" -p "max_issues_per_run=1" 2>/dev/null || EXIT_CODE_ARGS=$?

PASS_ARGS=$(cat "$STUB_OUT4" 2>/dev/null || true)
rm -rf "$TMPDIR_ARGS" "$STUB_BIN4" "$STUB_OUT4"

if echo "$PASS_ARGS" | grep -q -- '-p'; then
  pass "Extra args (-p) passed through to cco"
else
  fail "Extra args (-p) NOT passed through to cco. Args: $PASS_ARGS"
fi

if echo "$PASS_ARGS" | grep -q 'max_issues_per_run=1'; then
  pass "Extra arg value 'max_issues_per_run=1' passed through to cco"
else
  fail "Extra arg value not passed through. Args: $PASS_ARGS"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS passed, $FAIL failed (of $TOTAL assertions)"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
