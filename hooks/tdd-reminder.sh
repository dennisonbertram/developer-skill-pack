#!/usr/bin/env bash
# TDD reminder hook — fires on Edit/Write of src/ files
# Works with both Claude Code (PreToolUse) and Codex (pre_tool_use)
# Reads tool input from stdin or $TOOL_INPUT

INPUT="${TOOL_INPUT:-$(cat)}"

if echo "$INPUT" | grep -q '"file_path"[[:space:]]*:[[:space:]]*"[^"]*src/' 2>/dev/null; then
  echo 'TDD REMINDER: You are about to modify a src/ file.'
  echo 'Before writing implementation code, you MUST:'
  echo '1. Write or identify a FAILING test first (Red)'
  echo '2. Make the smallest change to pass that test (Green)'
  echo '3. Refactor only after tests are green (Refactor)'
  echo ''
  echo 'If you have not yet written or confirmed a failing test, STOP and write the test first.'
fi

exit 0
