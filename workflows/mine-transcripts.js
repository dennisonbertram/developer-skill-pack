export const meta = {
  name: 'mine-transcripts',
  description: 'Sweep sub-agent JSONL transcripts for novel learnings, dedupe against existing docs, promote high-confidence findings',
  phases: [
    { title: 'Discover', detail: 'Inventory transcripts and existing learnings for dedupe baseline' },
    { title: 'Mine', detail: 'Parallel learning extractors on transcript slices' },
    { title: 'Consolidate', detail: 'Dedupe across slices and persist findings' },
  ],
}

const INVENTORY_SCHEMA = {
  type: 'object',
  properties: {
    transcript_dir: { type: 'string' },
    transcripts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          agent_id: { type: 'string' },
          agent_type: { type: 'string' },
          size_bytes: { type: 'number' },
          high_signal: { type: 'boolean' },
        },
        required: ['file', 'agent_id', 'size_bytes', 'high_signal'],
      },
    },
    existing_learnings_summary: { type: 'string' },
    existing_topics: { type: 'array', items: { type: 'string' } },
    proposed_slices: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          slice_id: { type: 'number' },
          files: { type: 'array', items: { type: 'string' } },
        },
        required: ['slice_id', 'files'],
      },
    },
  },
  required: ['transcript_dir', 'transcripts', 'existing_learnings_summary', 'existing_topics', 'proposed_slices'],
}

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    candidate_learnings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          category: { type: 'string', enum: ['practice', 'issue', 'pattern', 'decision', 'process'] },
          learning: { type: 'string' },
          evidence: { type: 'string' },
          confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
          suggested_destination: { type: 'string', enum: ['repo-practices', 'known-issues', 'inbox-only'] },
          why_novel: { type: 'string' },
        },
        required: ['category', 'learning', 'evidence', 'confidence', 'suggested_destination', 'why_novel'],
      },
    },
    process_observations: { type: 'array', items: { type: 'string' } },
  },
  required: ['candidate_learnings', 'process_observations'],
}

const CONSOLIDATION_SCHEMA = {
  type: 'object',
  properties: {
    inbox_entries_written: { type: 'number' },
    known_issues_added: { type: 'number' },
    repo_practices_added: { type: 'number' },
    duplicates_removed: { type: 'number' },
    summary: { type: 'string' },
  },
  required: ['inbox_entries_written', 'known_issues_added', 'repo_practices_added', 'duplicates_removed', 'summary'],
}

// Phase 1: Discover
phase('Discover')
log('Inventorying transcripts and existing learning docs...')

const inventory = await agent(
  `You are a briefer. Inventory the sub-agent transcripts and existing learning docs for this project.

1. Find agent JSONL transcripts. Check these paths in order:
   - ~/.claude/projects/ directories matching this repo path, then look for subagents/ subdirectories
   - /private/tmp/claude-501/ directories matching this repo path

   For each JSONL file found, peek at the first few lines to determine:
   - The agent_type (look for "subagent_type" in metadata, or infer from the prompt content)
   - File size in bytes
   - Whether it's high-signal (worker, worker-investigation, worker-refactor, worker-test, intent-validator, reviewer, learning-extractor, general-purpose, Explore) or low-signal (scribe, briefer, pure fetch/polling)

2. Read existing learning docs to build a dedupe baseline:
   - .coord/learning-inbox.jsonl
   - docs/context/repo-practices.md
   - docs/context/known-issues.md
   - LEARNINGS.md
   Summarize how many entries exist and what topics are already covered.

3. Filter OUT low-signal transcripts (scribe, briefer, previous learning-extractor outputs, files < 1KB, files > 500KB that are mostly HTML/fetch dumps).

4. Group the remaining high-signal transcripts into 3-4 slices of roughly equal total byte count for parallel mining.

Return the full inventory with proposed slices.`,
  { label: 'discover:inventory', phase: 'Discover', schema: INVENTORY_SCHEMA, agentType: 'briefer' }
)

if (!inventory || !inventory.proposed_slices || inventory.proposed_slices.length === 0) {
  log('No transcripts found or all filtered out. Nothing to mine.')
  return { status: 'empty', message: 'No high-signal transcripts found to mine.' }
}

log(`Found ${inventory.transcripts.length} transcripts, ${inventory.transcripts.filter(t => t.high_signal).length} high-signal. ${inventory.proposed_slices.length} slices planned.`)

// Phase 2: Mine in Parallel
phase('Mine')
log(`Dispatching ${inventory.proposed_slices.length} parallel extractors...`)

const existingTopics = inventory.existing_topics.join(', ')
const dedupeBaseline = inventory.existing_learnings_summary

const sliceResults = await parallel(
  inventory.proposed_slices.map(slice => () =>
    agent(
      `You are a learning extractor. Read the assigned JSONL transcript files and look for things ONLY visible in the inner monologue — not the final task output.

ASSIGNED FILES (slice ${slice.slice_id}):
${slice.files.map(f => `- ${f}`).join('\n')}

DEDUPE BASELINE (already captured — do NOT return these):
${dedupeBaseline}

Already-covered topics: ${existingTopics}

For each transcript, look for:
1. Dead ends and backtracking — agent tried X, didn't work, switched to Y
2. Silently-recovered tool errors — wrong flags, missing endpoints, auth weirdness
3. Sub-decisions about design that weren't surfaced in the final output
4. Confusion points where the agent paused or expressed uncertainty
5. Repeated reasoning patterns across multiple agents
6. Time wasters — long investigations on false hypotheses

RULES:
- Dedupe rigorously against the baseline. Don't return anything already covered.
- Every candidate must cite specific evidence: agent_id + verbatim quote OR command + observation
- No platitudes. No generic advice like "agents should test more carefully"
- Cap at 8 candidates for this slice. Quality over quantity.
- Empty array is ACCEPTABLE if nothing novel surfaces — don't manufacture filler.`,
      { label: `mine:slice-${slice.slice_id}`, phase: 'Mine', schema: FINDINGS_SCHEMA }
    )
  )
)

const validResults = sliceResults.filter(Boolean)
const allCandidates = validResults.flatMap(r => r.candidate_learnings || [])
const allObservations = validResults.flatMap(r => r.process_observations || [])

log(`Mining complete. ${allCandidates.length} candidates from ${validResults.length} slices. ${allObservations.length} process observations.`)

if (allCandidates.length === 0) {
  log('No novel learnings found. This is a valid outcome — the existing docs already cover what these transcripts show.')
  return { status: 'empty', candidates: 0, message: 'No novel learnings found after deduplication.' }
}

// Phase 3: Consolidate
phase('Consolidate')
log(`Consolidating ${allCandidates.length} candidates, deduping across slices...`)

const candidatesJson = JSON.stringify(allCandidates, null, 2)
const observationsJson = JSON.stringify(allObservations, null, 2)

const result = await agent(
  `You are a scribe. Consolidate and persist mining results.

CANDIDATE LEARNINGS (from ${validResults.length} parallel extractors):
${candidatesJson}

PROCESS OBSERVATIONS:
${observationsJson}

TASKS:

1. DEDUPE across slices: Multiple extractors often hit the same gotcha. Remove near-duplicates, keeping the one with stronger evidence.

2. For each surviving candidate, append a JSONL entry to .coord/learning-inbox.jsonl:
   {"task_id":"MINE-001","learning":"<one sentence>","category":"<category>","evidence":"<agent_id + quote>","confidence":"<high|medium|low>","destination":"<repo-practices|known-issues>","timestamp":"<run 'date -u +%Y-%m-%dT%H:%M:%SZ' to get the current timestamp>"}

   Number sequentially from MINE-001.

3. For confidence=high entries with destination=known-issues, append a new section to docs/context/known-issues.md:
   ### <Heading>
   <1-3 sentences>
   **Symptoms**: <observable evidence>
   **Workaround**: <fix or mitigation>

4. For confidence=high entries with destination=repo-practices, append a new section to docs/context/repo-practices.md:
   ### <Heading>
   **Why**: <the problem this pattern solves>
   **When to use**: <conditions>

5. PRESERVE all existing entries in all files. Only APPEND, never overwrite.

6. Report the final tally.`,
  { label: 'consolidate:persist', phase: 'Consolidate', schema: CONSOLIDATION_SCHEMA }
)

log(`Done: ${result.inbox_entries_written} inbox, ${result.known_issues_added} known-issues, ${result.repo_practices_added} repo-practices, ${result.duplicates_removed} dupes removed.`)

return result
