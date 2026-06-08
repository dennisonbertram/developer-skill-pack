export const meta = {
  name: 'code-review',
  description: 'Multi-perspective code review with adversarial verification — 5 dimension reviewers then skeptics refute false positives',
  phases: [
    { title: 'Scope', detail: 'Identify changed files and diff' },
    { title: 'Review', detail: 'Parallel reviewers across 5 dimensions' },
    { title: 'Verify', detail: 'Adversarial skeptics refute each finding' },
    { title: 'Report', detail: 'Synthesize confirmed findings' },
  ],
}

const DIFF_SCHEMA = {
  type: 'object',
  properties: {
    base_branch: { type: 'string' },
    changed_files: { type: 'array', items: { type: 'string' } },
    diff_summary: { type: 'string' },
    total_lines_changed: { type: 'number' },
  },
  required: ['base_branch', 'changed_files', 'diff_summary', 'total_lines_changed'],
}

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    dimension: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          file: { type: 'string' },
          line_range: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          description: { type: 'string' },
          suggestion: { type: 'string' },
        },
        required: ['id', 'title', 'file', 'severity', 'description'],
      },
    },
  },
  required: ['dimension', 'findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    finding_id: { type: 'string' },
    is_real: { type: 'boolean' },
    reasoning: { type: 'string' },
    revised_severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low', 'false-positive'] },
  },
  required: ['finding_id', 'is_real', 'reasoning'],
}

const DIMENSIONS = [
  {
    key: 'correctness',
    prompt: `Review the diff for CORRECTNESS bugs: logic errors, off-by-one mistakes, null/undefined paths, race conditions, incorrect type coercions, wrong operator precedence, missing error handling on external calls. Ignore style and naming.`,
  },
  {
    key: 'security',
    prompt: `Review the diff for SECURITY vulnerabilities: injection (SQL, XSS, command), auth bypass, exposed secrets, insecure deserialization, path traversal, SSRF, missing input validation at system boundaries. Ignore internal code style.`,
  },
  {
    key: 'performance',
    prompt: `Review the diff for PERFORMANCE issues: N+1 queries, missing indexes implied by new queries, unbounded loops over user data, large allocations in hot paths, missing pagination, synchronous I/O blocking the event loop, cache invalidation bugs.`,
  },
  {
    key: 'concurrency',
    prompt: `Review the diff for CONCURRENCY and STATE issues: data races, missing locks/transactions, stale reads, lost updates, deadlock potential, non-atomic check-then-act sequences, shared mutable state without synchronization.`,
  },
  {
    key: 'api-contract',
    prompt: `Review the diff for API CONTRACT issues: breaking changes to public interfaces, missing backwards compatibility, changed response shapes without version bump, removed fields callers depend on, new required parameters without defaults.`,
  },
]

// Phase 1: Scope
phase('Scope')
log('Identifying changed files and diff...')

const scope = await agent(
  `Determine the review scope for the current branch.

1. Run: git diff --name-only main...HEAD (or master...HEAD)
   If that fails, try: git diff --name-only HEAD~5...HEAD
   If that also fails, try: git diff --name-only --cached

2. Run: git diff main...HEAD --stat (for a summary)

3. Run: git diff main...HEAD (the full diff — read it all)

4. Identify the base branch and list all changed files.

Return the scope information. If there are no changes to review, set changed_files to an empty array.`,
  { label: 'scope:diff', phase: 'Scope', schema: DIFF_SCHEMA }
)

if (!scope || scope.changed_files.length === 0) {
  log('No changes to review.')
  return { status: 'clean', message: 'No changes found to review.' }
}

log(`Reviewing ${scope.changed_files.length} files (${scope.total_lines_changed} lines changed) against ${scope.base_branch}.`)

// Phase 2: Review — 5 dimensions in parallel via pipeline
phase('Review')
log('Dispatching 5 dimension reviewers...')

const fileList = scope.changed_files.map(f => `- ${f}`).join('\n')

const reviews = await parallel(
  DIMENSIONS.map(dim => () =>
    agent(
      `${dim.prompt}

CHANGED FILES:
${fileList}

DIFF SUMMARY:
${scope.diff_summary}

Read the full content of each changed file and the git diff for context. Focus ONLY on the ${dim.key} dimension.

Rules:
- Only report findings in changed code (not pre-existing issues)
- Each finding needs: file, line range, severity, description, and fix suggestion
- Use IDs like "${dim.key}-001", "${dim.key}-002", etc.
- Empty findings array is fine if no issues in this dimension
- No style nits, no naming suggestions — only real ${dim.key} issues`,
      { label: `review:${dim.key}`, phase: 'Review', schema: FINDINGS_SCHEMA, agentType: 'reviewer' }
    )
  )
)

const allFindings = reviews
  .filter(Boolean)
  .flatMap(r => r.findings.map(f => ({ ...f, dimension: r.dimension })))

log(`${allFindings.length} findings across ${reviews.filter(Boolean).length} dimensions.`)

if (allFindings.length === 0) {
  log('No issues found across any dimension. Clean review.')
  return { status: 'clean', dimensions_checked: DIMENSIONS.map(d => d.key), findings: 0 }
}

// Phase 3: Verify — adversarial skeptics
phase('Verify')
log(`Dispatching ${allFindings.length} adversarial verifiers...`)

const verified = await pipeline(
  allFindings,
  (finding) => agent(
    `You are a skeptic. Your job is to REFUTE this code review finding if possible. Default to refuted=true if uncertain.

FINDING:
- ID: ${finding.id}
- Dimension: ${finding.dimension}
- File: ${finding.file}
- Severity: ${finding.severity}
- Description: ${finding.description}
- Suggestion: ${finding.suggestion || 'none'}

Read the actual file and the git diff. Then determine:
1. Is this finding actually real? (not a misread of the code)
2. Does the code already handle this case? (missed by the reviewer)
3. Is the severity accurate?
4. Could this be a false positive?

Be adversarial — look for reasons this finding is WRONG. Only confirm it if you cannot refute it.`,
    { label: `verify:${finding.id}`, phase: 'Verify', schema: VERDICT_SCHEMA }
  ),
  (verdict, finding) => verdict ? { ...finding, verdict } : null
)

const confirmed = verified
  .filter(Boolean)
  .filter(f => f.verdict && f.verdict.is_real)
  .map(f => ({
    ...f,
    severity: (f.verdict && f.verdict.revised_severity && f.verdict.revised_severity !== 'false-positive')
      ? f.verdict.revised_severity
      : f.severity,
  }))

const refuted = verified.filter(Boolean).filter(f => f.verdict && !f.verdict.is_real)

log(`Verification complete: ${confirmed.length} confirmed, ${refuted.length} refuted as false positives.`)

// Phase 4: Report
phase('Report')

const report = {
  status: confirmed.length > 0 ? 'findings' : 'clean',
  scope: {
    base_branch: scope.base_branch,
    files_reviewed: scope.changed_files.length,
    lines_changed: scope.total_lines_changed,
  },
  dimensions_checked: DIMENSIONS.map(d => d.key),
  total_raw_findings: allFindings.length,
  false_positives_removed: refuted.length,
  confirmed_findings: confirmed.map(f => ({
    id: f.id,
    dimension: f.dimension,
    title: f.title,
    file: f.file,
    line_range: f.line_range,
    severity: f.severity,
    description: f.description,
    suggestion: f.suggestion,
    verification: f.verdict ? f.verdict.reasoning : 'unverified',
  })),
  by_severity: {
    critical: confirmed.filter(f => f.severity === 'critical').length,
    high: confirmed.filter(f => f.severity === 'high').length,
    medium: confirmed.filter(f => f.severity === 'medium').length,
    low: confirmed.filter(f => f.severity === 'low').length,
  },
}

log(`Review complete: ${report.confirmed_findings.length} confirmed findings (${report.by_severity.critical} critical, ${report.by_severity.high} high, ${report.by_severity.medium} medium, ${report.by_severity.low} low)`)

return report
