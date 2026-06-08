---
name: mine-transcripts
description: "Sweep sub-agent JSONL transcripts for novel learnings and promote the strongest to durable docs. Use when asked to 'mine transcripts', 'sweep for learnings', 'extract learnings from transcripts', 'what did agents learn', 'harvest session insights', or at the end of any multi-agent session."
version: 1.0.0
user_invocable: true
---

# Mine Transcripts

Sweep this session's sub-agent JSONL transcripts for NOVEL learnings not already captured, then promote the strongest to durable docs.

## Usage

```
/mine-transcripts
```

No arguments needed — the skill discovers transcripts automatically.

### Workflow Mode

For deterministic parallel execution, use the workflow script:

```
use a workflow for mine-transcripts
```

The workflow script (`workflows/mine-transcripts.js`) implements the same 3-phase process with typed JSON Schema outputs, parallel slicing via `pipeline()`, and structured consolidation.

---

## Step 1 — Discover

Dispatch a **briefer** to:

1. **Locate the sub-agent transcript directory.** Most likely paths (try in order):
   - `~/.claude/projects/-<absolute-repo-path-encoded>/<session-uuid>/subagents/agent-*.jsonl`
   - `/private/tmp/claude-501/-<absolute-repo-path-encoded>/<session-uuid>/tasks/agent-*.jsonl`
   - Or look at the most recent task notifications for paths like `/private/tmp/claude-501/.../tasks/<id>.output`

2. **List every `agent-*.jsonl`** in that directory (there are usually 30-100+ in a research session). For each, peek the first line to extract `subagent_type` from the metadata.

3. **Read existing learning docs** in the repo:
   - `.coord/learning-inbox.jsonl`
   - `docs/context/repo-practices.md`
   - `docs/context/known-issues.md`
   - `LEARNINGS.md`

   Summarize how many entries and what topics are already covered — this becomes the **dedupe baseline**.

4. **Skip noise**: pure HTML files (ctx7/WebFetch results), polling-wait logs ("Waiting... status: not_found"), single-line >100KB crash blobs, and empty files.

**Return**: agent inventory by type, existing-learnings inventory, and a proposed slicing for parallel mining.

---

## Step 2 — Mine in Parallel

Group the high-signal transcripts into **3-5 slices** of roughly equal token weight.

**High-signal agent types** (include these):
- `worker`, `worker-investigation`, `worker-refactor`, `worker-test`
- `intent-validator`, `reviewer`, `learning-extractor`
- Any custom agent types that involve reasoning

**Low-signal agent types** (skip these):
- `scribe`, `briefer` — confirmations of writes, no novel signal
- Previous `learning-extractor` outputs — meta-noise
- Pure fetch/polling transcripts

For each slice, dispatch a **learning-extractor** in parallel with these instructions:

> Read the assigned JSONL files. For each agent's transcript, look for things ONLY visible in the inner monologue, not the final task output:
>
> 1. **Dead ends and backtracking** — agent tried X, didn't work, switched to Y
> 2. **Silently-recovered tool errors** — wrong flags, missing endpoints, auth weirdness
> 3. **Sub-decisions about design** that weren't surfaced in the final output
> 4. **Confusion points** where the agent paused or expressed uncertainty
> 5. **Repeated reasoning patterns** across multiple agents
> 6. **Time wasters** — long investigations on false hypotheses
>
> **Dedupe rigorously** against the existing learning docs. Don't return anything already covered.
>
> Every candidate must cite **specific evidence**: `agent_id` + verbatim quote OR command + observation. No platitudes. No generic advice.
>
> Cap at **8 candidates per slice**. Quality over quantity. Empty array is acceptable if nothing novel surfaces.
>
> Return JSON:
> ```json
> {
>   "candidate_learnings": [
>     {
>       "category": "practice|issue|pattern|decision|process",
>       "learning": "One clear sentence",
>       "evidence": "agent_id + verbatim quote or command + observation",
>       "confidence": "high|medium|low",
>       "suggested_destination": "repo-practices|known-issues|inbox-only",
>       "why_novel": "Why this isn't already covered"
>     }
>   ],
>   "process_observations": [
>     "Observations about the orchestration itself"
>   ]
> }
> ```

**Critical**: Dispatch all slice extractors in a **single message with multiple tool calls** so they run in parallel, not sequentially.

---

## Step 3 — Consolidate and Persist

Collect all slice outputs. Dedupe across slices (multiple agents often hit the same gotcha).

Dispatch a **scribe** to:

### 3a. Inbox entries

Append every accepted candidate as a JSONL entry to the learning inbox:

```json
{"task_id":"MINE-XXX","learning":"<one sentence>","category":"<one-of>","evidence":"<agent_id + quote>","confidence":"<high|medium|low>","destination":"<repo-practices|known-issues>","timestamp":"<ISO-8601>"}
```

### 3b. Promote high-confidence known-issues

For `confidence=high` entries with `destination=known-issues`, append a new section to `docs/context/known-issues.md`:

```markdown
### <Heading describing the gotcha>

<1-3 sentences describing what fails>

**Symptoms**: <observable evidence>
**Workaround**: <fix or mitigation>
```

### 3c. Promote high-confidence repo-practices

For `confidence=high` entries with `destination=repo-practices`, append a new section to `docs/context/repo-practices.md`:

```markdown
### <Heading describing the pattern>

**Why**: <the problem this pattern solves>

```
<code excerpt or command sequence showing the pattern>
```

**When to use**: <conditions that trigger this pattern>
```

### 3d. Report

Report the final tally:
- N new inbox entries
- M new known-issues sections
- P new repo-practices sections

---

## Constraints

- Run extractors in **PARALLEL**, not sequentially
- Don't manufacture entries to look productive — **empty mining is a valid outcome**
- Don't read scribes' or briefers' transcripts — they're confirmations of writes, no novel signal
- Don't read learning-extractors' OWN previous JSONLs — they're meta-noise
- **Preserve all existing learning entries; only APPEND, never overwrite**
- Every candidate must have specific evidence with quotes — no platitudes

---

## Design Rationale

1. **Two-phase (inventory → mine)**: Without inventory, extractors waste ~30% of budget on HTML noise and polling logs.
2. **Parallel slicing**: A single extractor on 70+ JSONLs would either run out of context or skip detail. Three parallel extractors on ~20 JSONLs each preserves depth.
3. **Dedupe baseline as first-class input**: Without it, extractors re-discover things already captured. Telling them what's covered focuses attention on novelty.
4. **"Empty is acceptable"**: Extractors manufacture filler without explicit permission to return nothing.
5. **Skip-list for low-signal types**: Scribes confirm writes; their JSONLs are nearly content-free. Skipping saves ~40% of work.
6. **Required evidence with quotes**: Without this, you get "agents should test more carefully" — useless. Requiring quotes forces specificity.
7. **Promotion routing per confidence**: Inbox-only for medium, durable docs for high. Keeps durable docs from inflating with weak signal.
