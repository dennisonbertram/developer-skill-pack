#!/usr/bin/env bash
# Session start hook — announces TDD-first requirement
# Works with both Claude Code and Codex

echo 'TDD-FIRST DEVELOPMENT IS REQUIRED IN THIS REPOSITORY.'
echo ''
echo 'Before writing ANY implementation code:'
echo '1. RED   — Write a failing test that defines the desired behavior'
echo '2. GREEN — Write the minimum code to make the test pass'
echo '3. REFACTOR — Clean up while keeping tests green'
echo ''
echo 'This is a non-negotiable workflow requirement. Do not skip it.'

exit 0
