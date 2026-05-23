---
name: research-spike
description: "Time-boxed research before adopting a library, API, architecture, or provider. Use when asked to 'research', 'compare options', 'evaluate a library', 'spike on', 'investigate a tool', 'should we use X', or 'what are our options for'. Produces structured findings in docs/research/ with no production code changes."
version: 1.0.0
user_invocable: true
---

# Research Spike

Execute a structured, time-boxed research spike. Produces a recommendation with tradeoffs, captured in `docs/research/`, with no production code changes.

## Usage

```
/research-spike <question> [--options "A, B, C"] [--time-box 2h]
```

## Process

### Phase 1: Frame the Question

1. Restate the research question in one sentence
2. List the options to compare (at minimum 2)
3. Define the decision criteria (cost, complexity, maintenance, performance, security, compatibility)
4. Identify documentation sources:
   - Use Context7 for libraries, frameworks, SDKs, APIs, CLI tools, and cloud services
   - Link vendor docs
   - Reference existing repo docs or decisions

### Phase 2: Research

Spawn **read-only Explore subagents** in parallel (one per option or topic area):

1. Fetch current documentation via Context7:
   ```bash
   npx ctx7@latest library "<library name>" "<research question>"
   npx ctx7@latest docs <libraryId> "<specific question>"
   ```
2. Read official docs, source code, examples
3. Identify: capabilities, limitations, failure modes, maintenance status, community health
4. Note expectation gaps between docs and reality

### Phase 3: Compare and Recommend

1. Build a comparison matrix against the decision criteria
2. State a clear recommendation with rationale
3. List tradeoffs and risks for each option
4. Identify follow-up implementation issues if adopting

### Phase 4: Write Findings

Write to `docs/research/<date>-<slug>.md`:

```markdown
# Research: <Question>

**Date**: <ISO date>
**Decision**: <Recommended option>
**Status**: <recommended | needs-discussion | blocked>

## Question
<Restatement>

## Options Compared

### Option A: <name>
- **Pros**: ...
- **Cons**: ...
- **Risks**: ...

### Option B: <name>
- **Pros**: ...
- **Cons**: ...
- **Risks**: ...

## Comparison Matrix

| Criterion | Option A | Option B |
|-----------|----------|----------|
| ...       | ...      | ...      |

## Recommendation
<Clear recommendation with rationale>

## Follow-up
- [ ] Implementation issue if adopting
- [ ] Migration plan if replacing existing

## Sources
- Context7: <library IDs used>
- Vendor docs: <URLs>
- Repo docs: <paths>
```

## Rules

- No production code changes. Research only.
- Always use Context7 for library/framework/SDK questions — do not rely on training data.
- Capture findings even if the recommendation is "don't adopt."
- File follow-up implementation issues for adopted recommendations.
- Time-box the research. If a question cannot be answered within the time box, document what is known and what remains unknown.
