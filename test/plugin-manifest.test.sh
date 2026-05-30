#!/usr/bin/env bash
# test/plugin-manifest.test.sh
# Asserts that the Claude Code plugin manifests are valid and the agent-exposure
# mechanism points at all 20 agents in skills/coordinator/agents/.
#
# Exit 0 = all assertions pass. Exit 1 = at least one assertion failed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
AGENTS_SYMLINK_DIR="$REPO_ROOT/agents"
AGENTS_SOURCE_DIR="$REPO_ROOT/skills/coordinator/agents"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)) || true; }
fail() { echo "  FAIL: $1"; ((FAIL++)) || true; }

# ---------------------------------------------------------------------------
# Section 1 — JSON validity
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 1: JSON validity ==="

if python3 -c "import json, sys; json.load(open('$PLUGIN_JSON'))" 2>/dev/null; then
  pass "plugin.json is valid JSON"
else
  fail "plugin.json is NOT valid JSON"
fi

if python3 -c "import json, sys; json.load(open('$MARKETPLACE_JSON'))" 2>/dev/null; then
  pass "marketplace.json is valid JSON"
else
  fail "marketplace.json is NOT valid JSON"
fi

# ---------------------------------------------------------------------------
# Section 2 — plugin.json required fields
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 2: plugin.json required fields ==="

PLUGIN_NAME=$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d.get('name',''))" 2>/dev/null)
if [[ "$PLUGIN_NAME" == "developer-skill-pack" ]]; then
  pass "plugin.json name is 'developer-skill-pack'"
else
  fail "plugin.json name is '$PLUGIN_NAME' (expected 'developer-skill-pack')"
fi

PLUGIN_VERSION=$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d.get('version',''))" 2>/dev/null)
if [[ "$PLUGIN_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  pass "plugin.json version is semver: $PLUGIN_VERSION"
else
  fail "plugin.json version is missing or not semver: '$PLUGIN_VERSION'"
fi

PLUGIN_SCHEMA=$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d.get('\$schema',''))" 2>/dev/null)
if [[ "$PLUGIN_SCHEMA" == *"anthropic.com"* ]] || [[ "$PLUGIN_SCHEMA" == *"plugin.schema"* ]]; then
  pass "plugin.json has \$schema pointing to anthropic schema"
else
  fail "plugin.json missing or wrong \$schema: '$PLUGIN_SCHEMA'"
fi

# ---------------------------------------------------------------------------
# Section 3 — marketplace.json required fields
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 3: marketplace.json required fields ==="

MKT_NAME=$(python3 -c "import json; d=json.load(open('$MARKETPLACE_JSON')); print(d.get('name',''))" 2>/dev/null)
if [[ "$MKT_NAME" == "developer-skill-pack" ]]; then
  pass "marketplace.json name is 'developer-skill-pack'"
else
  fail "marketplace.json name is '$MKT_NAME' (expected 'developer-skill-pack')"
fi

# The marketplace entry must contain at least one plugin referencing the github source
GITHUB_SOURCE=$(python3 -c "
import json
d = json.load(open('$MARKETPLACE_JSON'))
plugins = d.get('plugins', [])
for p in plugins:
    src = p.get('source', '')
    if isinstance(src, dict):
        url = src.get('url', '')
    elif isinstance(src, str):
        url = src
    else:
        url = ''
    if 'dennisonbertram' in url or 'developer-skill-pack' in url:
        print('found')
        break
" 2>/dev/null)
if [[ "$GITHUB_SOURCE" == "found" ]]; then
  pass "marketplace.json plugins entry references the github source"
else
  fail "marketplace.json plugins does not contain a dennisonbertram/developer-skill-pack source URL"
fi

# ---------------------------------------------------------------------------
# Section 4 — agents/ symlink directory exists and is complete
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 4: agents/ symlink directory ==="

if [[ -d "$AGENTS_SYMLINK_DIR" ]]; then
  pass "agents/ directory exists at plugin root"
else
  fail "agents/ directory does NOT exist at plugin root (expected: $AGENTS_SYMLINK_DIR)"
fi

# Count source agents
SOURCE_COUNT=$(find "$AGENTS_SOURCE_DIR" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
# Count symlinks in agents/
SYMLINK_COUNT=$(find "$AGENTS_SYMLINK_DIR" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')

if [[ "$SOURCE_COUNT" -eq 20 ]]; then
  pass "skills/coordinator/agents/ has exactly 20 agent .md files (source of truth)"
else
  fail "skills/coordinator/agents/ has $SOURCE_COUNT .md files (expected 20)"
fi

if [[ "$SYMLINK_COUNT" -eq "$SOURCE_COUNT" ]]; then
  pass "agents/ has $SYMLINK_COUNT entries matching all $SOURCE_COUNT source agents"
else
  fail "agents/ has $SYMLINK_COUNT entries but source has $SOURCE_COUNT (mismatch)"
fi

# ---------------------------------------------------------------------------
# Section 5 — agents/ entries are symlinks (not copies) pointing to source
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 5: agents/ entries are symlinks resolving to source ==="

COPY_COUNT=0
BROKEN_COUNT=0
WRONG_TARGET_COUNT=0

for src_file in "$AGENTS_SOURCE_DIR"/*.md; do
  agent_name=$(basename "$src_file")
  link_path="$AGENTS_SYMLINK_DIR/$agent_name"

  if [[ ! -e "$link_path" ]]; then
    fail "Missing symlink: agents/$agent_name"
    ((FAIL++)) || true
    continue
  fi

  if [[ -L "$link_path" ]]; then
    # It's a symlink - check it resolves
    if [[ ! -f "$link_path" ]]; then
      fail "Broken symlink: agents/$agent_name"
      ((BROKEN_COUNT++)) || true
    fi
    # Check the real path matches the source
    real=$(python3 -c "import os; print(os.path.realpath('$link_path'))" 2>/dev/null)
    expected=$(python3 -c "import os; print(os.path.realpath('$src_file'))" 2>/dev/null)
    if [[ "$real" != "$expected" ]]; then
      fail "Wrong target: agents/$agent_name -> $real (expected $expected)"
      ((WRONG_TARGET_COUNT++)) || true
    fi
  else
    # Not a symlink — it's a copy (content duplication)
    ((COPY_COUNT++)) || true
    fail "agents/$agent_name is a regular file (expected symlink)"
  fi
done

if [[ $COPY_COUNT -eq 0 && $BROKEN_COUNT -eq 0 && $WRONG_TARGET_COUNT -eq 0 ]]; then
  pass "All agents/ entries are valid symlinks resolving to skills/coordinator/agents/"
fi

# ---------------------------------------------------------------------------
# Section 6 — 1:1 coverage check (no extra entries in agents/)
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 6: no extra entries in agents/ ==="

EXTRA_COUNT=0
for link_file in "$AGENTS_SYMLINK_DIR"/*.md; do
  agent_name=$(basename "$link_file")
  src_path="$AGENTS_SOURCE_DIR/$agent_name"
  if [[ ! -f "$src_path" ]]; then
    fail "Extra entry in agents/ with no source: $agent_name"
    ((EXTRA_COUNT++)) || true
  fi
done

if [[ $EXTRA_COUNT -eq 0 ]]; then
  pass "No extra entries in agents/ (1:1 match with source)"
fi

# ---------------------------------------------------------------------------
# Section 7 — Known agents are present
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 7: spot-check known agent names ==="

KNOWN_AGENTS=(
  "issue-groomer.md"
  "issue-implementer.md"
  "coordinator.md"
  "worker.md"
  "reviewer.md"
  "planner.md"
  "briefer.md"
  "researcher.md"
)

for agent in "${KNOWN_AGENTS[@]}"; do
  if [[ -e "$AGENTS_SYMLINK_DIR/$agent" ]]; then
    pass "$agent is present in agents/"
  else
    fail "$agent is MISSING from agents/"
  fi
done

# ---------------------------------------------------------------------------
# Section 8 — REGRESSION: agent .md files have valid YAML frontmatter (name field)
# If agents/ is accidentally populated with binary files or broken stubs,
# each agent must have a proper name: field in its frontmatter.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 8 (regression): agents/*.md have YAML name: field ==="

MISSING_NAME=0
for link_file in "$AGENTS_SYMLINK_DIR"/*.md; do
  agent_name=$(basename "$link_file")
  name_val=$(python3 -c "
import re, sys
with open('$link_file', 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()
m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if m:
    for line in m.group(1).splitlines():
        if line.startswith('name:'):
            print(line.split(':', 1)[1].strip())
            sys.exit(0)
print('')
" 2>/dev/null)
  if [[ -z "$name_val" ]]; then
    fail "agents/$agent_name: missing 'name:' field in YAML frontmatter"
    ((MISSING_NAME++)) || true
  fi
done
if [[ $MISSING_NAME -eq 0 ]]; then
  pass "All 20 agents have a 'name:' field in their YAML frontmatter"
fi

# ---------------------------------------------------------------------------
# Section 9 — REGRESSION: plugin.json stays a PROPER plugin, not a marketplace
# If someone accidentally swaps plugin.json and marketplace.json, this catches it.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 9 (regression): plugin.json is a plugin manifest, not marketplace ==="

HAS_PLUGINS_ARRAY=$(python3 -c "
import json
d = json.load(open('$PLUGIN_JSON'))
print('yes' if 'plugins' in d else 'no')
" 2>/dev/null)
if [[ "$HAS_PLUGINS_ARRAY" == "no" ]]; then
  pass "plugin.json does NOT have a top-level 'plugins' array (correct — that's for marketplace.json)"
else
  fail "plugin.json has a 'plugins' array — it may be accidentally structured as a marketplace manifest"
fi

HAS_SCHEMA=$(python3 -c "
import json
d = json.load(open('$MARKETPLACE_JSON'))
schema = d.get('\$schema', '')
print('yes' if 'marketplace' in schema else 'no')
" 2>/dev/null)
if [[ "$HAS_SCHEMA" == "yes" ]]; then
  pass "marketplace.json \$schema references 'marketplace' (not plugin schema)"
else
  fail "marketplace.json \$schema does not reference marketplace schema"
fi

# ---------------------------------------------------------------------------
# Section 10 — REGRESSION: skills.sh.json is untouched (skills install not broken)
# The skills.sh.json must remain valid JSON and reference the expected skills.
# ---------------------------------------------------------------------------
echo ""
echo "=== Section 10 (regression): skills.sh.json is intact ==="

SKILLS_JSON="$REPO_ROOT/skills.sh.json"

if python3 -c "import json, sys; json.load(open('$SKILLS_JSON'))" 2>/dev/null; then
  pass "skills.sh.json is valid JSON (skills install path unbroken)"
else
  fail "skills.sh.json is NOT valid JSON — skills install path may be broken"
fi

# Check that expected skills are still listed
EXPECTED_SKILLS=("coordinator" "ux-paths" "ux-walker" "walk-the-issues" "mine-transcripts" "setup-repo" "debug" "regression-guard" "research-spike")
SKILLS_CONTENT=$(python3 -c "
import json
d = json.load(open('$SKILLS_JSON'))
skills = []
for g in d.get('groupings', []):
    skills.extend(g.get('skills', []))
print(' '.join(skills))
" 2>/dev/null)

for skill in "${EXPECTED_SKILLS[@]}"; do
  if echo "$SKILLS_CONTENT" | grep -qw "$skill"; then
    pass "skills.sh.json still lists skill: $skill"
  else
    fail "skills.sh.json is MISSING skill: $skill"
  fi
done

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
