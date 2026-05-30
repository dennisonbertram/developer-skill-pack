#!/usr/bin/env bash
# agents-registry.test.sh — structural tests for the coordinator agents registry.
#
# Asserts:
#   1. Every agents/*.md file has frontmatter 'name:' that matches its filename (sans .md).
#   2. Every agent that should have a schema has a matching schemas/<name>-output.schema.json.
#      Exempt: coordinator (orchestrator, emits no structured output schema).
#   3. Every agent appears in SKILL.md (agent table contains the agent name).
#
# Run from any directory — the script resolves its own location.
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORD_DIR="$(cd "$SELF_DIR/.." && pwd)"
AGENTS_DIR="$COORD_DIR/agents"
SCHEMAS_DIR="$COORD_DIR/schemas"
SKILL_FILE="$COORD_DIR/SKILL.md"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

echo ""
echo "agents-registry structural tests"
echo "================================="

# ---------------------------------------------------------------------------
# Agents that are explicitly exempt from the output-schema requirement.
# coordinator is a control-plane orchestrator; it delegates to subagents and
# emits no structured JSON output schema of its own.
# ---------------------------------------------------------------------------
SCHEMA_EXEMPT="coordinator"

# ---------------------------------------------------------------------------
# Required agents: the four agents reconciled in this task must be present.
# ---------------------------------------------------------------------------
REQUIRED_AGENTS="distiller evidence-auditor knowledge-packager researcher"

# ---------------------------------------------------------------------------
# BT-001: required agents are present in agents/
# Each of the four reconciled agents must have a .md file in agents/.
# ---------------------------------------------------------------------------
for agent in $REQUIRED_AGENTS; do
  agent_file="$AGENTS_DIR/${agent}.md"
  if [ -f "$agent_file" ]; then
    pass "BT-001: agents/${agent}.md exists"
  else
    fail "BT-001: agents/${agent}.md exists" \
         "file not found: $agent_file"
  fi
done

# ---------------------------------------------------------------------------
# BT-002: every agents/*.md has valid 'name:' frontmatter that matches its filename.
# Iterate every .md in agents/ and verify the YAML frontmatter 'name:' line equals
# the filename without the .md extension.
# ---------------------------------------------------------------------------
for agent_file in "$AGENTS_DIR"/*.md; do
  filename="$(basename "$agent_file" .md)"
  name_line=$(grep '^name:' "$agent_file" 2>/dev/null | head -1)
  expected_name="name: ${filename}"
  if [ "$name_line" = "$expected_name" ]; then
    pass "BT-002: ${filename}.md frontmatter name: matches filename"
  else
    fail "BT-002: ${filename}.md frontmatter name: matches filename" \
         "expected '$expected_name', got '$name_line' in $agent_file"
  fi
done

# ---------------------------------------------------------------------------
# BT-003: every agent has a corresponding schema (unless explicitly exempt).
# For each agents/*.md (except exempt list), assert schemas/<name>-output.schema.json exists.
# ---------------------------------------------------------------------------
for agent_file in "$AGENTS_DIR"/*.md; do
  filename="$(basename "$agent_file" .md)"
  # Check if this agent is exempt
  is_exempt=0
  for exempt in $SCHEMA_EXEMPT; do
    if [ "$filename" = "$exempt" ]; then
      is_exempt=1
      break
    fi
  done
  if [ "$is_exempt" -eq 1 ]; then
    pass "BT-003: ${filename} is exempt from schema requirement (orchestrator)"
    continue
  fi
  schema_file="$SCHEMAS_DIR/${filename}-output.schema.json"
  if [ -f "$schema_file" ]; then
    pass "BT-003: schemas/${filename}-output.schema.json exists"
  else
    fail "BT-003: schemas/${filename}-output.schema.json exists" \
         "schema not found: $schema_file"
  fi
done

# ---------------------------------------------------------------------------
# BT-004: every agent appears in SKILL.md.
# The agent table must contain each agent's name.
# ---------------------------------------------------------------------------
for agent_file in "$AGENTS_DIR"/*.md; do
  filename="$(basename "$agent_file" .md)"
  if grep -q "$filename" "$SKILL_FILE" 2>/dev/null; then
    pass "BT-004: SKILL.md contains '$filename'"
  else
    fail "BT-004: SKILL.md contains '$filename'" \
         "agent '$filename' not found in $SKILL_FILE"
  fi
done

# ---------------------------------------------------------------------------
# BT-005: required agents have 'description:' frontmatter.
# ---------------------------------------------------------------------------
for agent in $REQUIRED_AGENTS; do
  agent_file="$AGENTS_DIR/${agent}.md"
  if [ ! -f "$agent_file" ]; then
    # Already covered by BT-001
    continue
  fi
  if grep -q '^description:' "$agent_file" 2>/dev/null; then
    pass "BT-005: agents/${agent}.md has description: frontmatter"
  else
    fail "BT-005: agents/${agent}.md has description: frontmatter" \
         "no 'description:' found in $agent_file"
  fi
done

# ---------------------------------------------------------------------------
# BT-006: required agents have 'tools:' frontmatter.
# ---------------------------------------------------------------------------
for agent in $REQUIRED_AGENTS; do
  agent_file="$AGENTS_DIR/${agent}.md"
  if [ ! -f "$agent_file" ]; then
    continue
  fi
  if grep -q '^tools:' "$agent_file" 2>/dev/null; then
    pass "BT-006: agents/${agent}.md has tools: frontmatter"
  else
    fail "BT-006: agents/${agent}.md has tools: frontmatter" \
         "no 'tools:' found in $agent_file"
  fi
done

# ---------------------------------------------------------------------------
# BT-007: required agents have 'model:' frontmatter.
# ---------------------------------------------------------------------------
for agent in $REQUIRED_AGENTS; do
  agent_file="$AGENTS_DIR/${agent}.md"
  if [ ! -f "$agent_file" ]; then
    continue
  fi
  if grep -q '^model:' "$agent_file" 2>/dev/null; then
    pass "BT-007: agents/${agent}.md has model: frontmatter"
  else
    fail "BT-007: agents/${agent}.md has model: frontmatter" \
         "no 'model:' found in $agent_file"
  fi
done

# ---------------------------------------------------------------------------
# BT-008: four reconciled schemas already exist in schemas/ directory.
# The schemas were present before the agent files; confirm they are still there.
# ---------------------------------------------------------------------------
for agent in $REQUIRED_AGENTS; do
  schema_file="$SCHEMAS_DIR/${agent}-output.schema.json"
  if [ -f "$schema_file" ]; then
    pass "BT-008: schemas/${agent}-output.schema.json exists (pre-existing schema confirmed)"
  else
    fail "BT-008: schemas/${agent}-output.schema.json exists" \
         "schema not found: $schema_file"
  fi
done

# ---------------------------------------------------------------------------
# REGRESSION RT-001: total agent count is at least 20.
# Before reconciliation the pack had 16 agents; after adding 4 it has 20.
# If someone accidentally removes an agent, this catches it.
# ---------------------------------------------------------------------------
total_agents=$(ls "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$total_agents" -ge 20 ]; then
  pass "RT-001: agent count is $total_agents (>= 20, reconciliation complete)"
else
  fail "RT-001: agent count is $total_agents (>= 20 required)" \
       "expected at least 20 agents in $AGENTS_DIR; got $total_agents — 4 reconciled agents may be missing"
fi

# ---------------------------------------------------------------------------
# REGRESSION RT-002: SKILL.md table contains all four reconciled agents by name.
# ---------------------------------------------------------------------------
missing_from_skill=()
for agent in $REQUIRED_AGENTS; do
  if ! grep -q "$agent" "$SKILL_FILE" 2>/dev/null; then
    missing_from_skill+=("$agent")
  fi
done
if [ ${#missing_from_skill[@]} -eq 0 ]; then
  pass "RT-002: all four reconciled agents appear in SKILL.md"
else
  fail "RT-002: all four reconciled agents appear in SKILL.md" \
       "missing: ${missing_from_skill[*]}"
fi

# ---------------------------------------------------------------------------
# REGRESSION RT-003: no agent file has a mismatched name: vs filename.
# Runs the full BT-002 check and also confirms zero mismatches exist.
# This catches copy/paste errors where name: field is left from another agent.
# ---------------------------------------------------------------------------
mismatch_count=0
for agent_file in "$AGENTS_DIR"/*.md; do
  filename="$(basename "$agent_file" .md)"
  name_line=$(grep '^name:' "$agent_file" 2>/dev/null | head -1)
  expected_name="name: ${filename}"
  if [ "$name_line" != "$expected_name" ]; then
    mismatch_count=$((mismatch_count + 1))
  fi
done
if [ "$mismatch_count" -eq 0 ]; then
  pass "RT-003: zero name:/filename mismatches across all agent files"
else
  fail "RT-003: zero name:/filename mismatches across all agent files" \
       "$mismatch_count mismatch(es) found — check BT-002 failures above for details"
fi

# ---------------------------------------------------------------------------
# REGRESSION RT-004: every non-exempt agent's schema file is non-empty.
# A zero-byte schema would break validation silently.
# ---------------------------------------------------------------------------
empty_schemas=()
for agent_file in "$AGENTS_DIR"/*.md; do
  filename="$(basename "$agent_file" .md)"
  is_exempt=0
  for exempt in $SCHEMA_EXEMPT; do
    if [ "$filename" = "$exempt" ]; then
      is_exempt=1
      break
    fi
  done
  if [ "$is_exempt" -eq 1 ]; then
    continue
  fi
  schema_file="$SCHEMAS_DIR/${filename}-output.schema.json"
  if [ -f "$schema_file" ] && [ ! -s "$schema_file" ]; then
    empty_schemas+=("$filename")
  fi
done
if [ ${#empty_schemas[@]} -eq 0 ]; then
  pass "RT-004: no non-empty schema files (all schemas have content)"
else
  fail "RT-004: no empty schema files found" \
       "empty schemas: ${empty_schemas[*]}"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
