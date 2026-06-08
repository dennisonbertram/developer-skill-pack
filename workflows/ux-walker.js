export const meta = {
  name: 'ux-walker',
  description: 'Walk UX stories through a real browser in parallel — deploy check, walk, triage, fix, report',
  phases: [
    { title: 'Preflight', detail: 'URL check, deploy verification, catalog load' },
    { title: 'Plan', detail: 'Parse catalog and build walk plan' },
    { title: 'Walk', detail: 'Parallel browser walks of stories' },
    { title: 'Triage', detail: 'Classify findings and plan fixes' },
    { title: 'Report', detail: 'Synthesize results into report' },
  ],
}

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    url: { type: 'string' },
    url_reachable: { type: 'boolean' },
    deploy_check: {
      type: 'object',
      properties: {
        has_fingerprint: { type: 'boolean' },
        deployed_sha: { type: 'string' },
        head_sha: { type: 'string' },
        match: { type: 'boolean' },
        message: { type: 'string' },
      },
      required: ['has_fingerprint', 'message'],
    },
    catalog_exists: { type: 'boolean' },
    catalog_path: { type: 'string' },
    story_count: { type: 'number' },
    stories: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          steps: { type: 'number' },
        },
        required: ['id', 'title'],
      },
    },
  },
  required: ['url', 'url_reachable', 'deploy_check', 'catalog_exists', 'story_count'],
}

const WALK_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    story_id: { type: 'string' },
    story_title: { type: 'string' },
    status: { type: 'string', enum: ['pass', 'fail', 'partial', 'blocked'] },
    steps_completed: { type: 'number' },
    steps_total: { type: 'number' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          type: { type: 'string', enum: ['bug', 'ux-issue', 'visual', 'accessibility', 'performance'] },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          title: { type: 'string' },
          description: { type: 'string' },
          step: { type: 'string' },
          screenshot_description: { type: 'string' },
          suggested_fix: { type: 'string' },
        },
        required: ['id', 'type', 'severity', 'title', 'description'],
      },
    },
    notes: { type: 'string' },
  },
  required: ['story_id', 'status', 'findings'],
}

const REPORT_SCHEMA = {
  type: 'object',
  properties: {
    report_written: { type: 'boolean' },
    report_path: { type: 'string' },
    summary: { type: 'string' },
  },
  required: ['report_written', 'summary'],
}

const targetUrl = args || 'http://localhost:3000'

// Phase 1: Preflight
phase('Preflight')
log(`Preflight checks against ${targetUrl}...`)

const preflight = await agent(
  `Perform preflight checks for UX walking.

1. URL CHECK: Test if ${targetUrl} responds.
   curl -s -o /dev/null -w "%{http_code}" ${targetUrl}
   If not reachable, check if a dev server is running (lsof -i :3000, :5173, :8080).
   If nothing running, check package.json for scripts.dev or scripts.start.

2. DEPLOY CHECK: Check version fingerprinting.
   - Try: curl -s ${targetUrl}/__version or ${targetUrl}/version.json
   - If found, compare git_sha against current HEAD (git rev-parse --short HEAD)
   - If not found, note "No version fingerprint — run /deploy-check --install to add one"

3. CATALOG CHECK: Look for docs/ux-paths/catalog.md
   - If it exists, parse story headers to get count and story list
   - If not, report catalog_exists=false

4. Return preflight results with story inventory.`,
  { label: 'preflight:checks', phase: 'Preflight', schema: PREFLIGHT_SCHEMA }
)

if (!preflight.url_reachable) {
  log(`URL ${targetUrl} is not reachable. Cannot walk stories.`)
  return { status: 'blocked', reason: 'URL not reachable', url: targetUrl }
}

if (!preflight.catalog_exists) {
  log('No UX story catalog found. Run /ux-paths first to generate stories.')
  return { status: 'blocked', reason: 'No catalog — run /ux-paths first' }
}

if (!preflight.deploy_check.has_fingerprint) {
  log('Advisory: No deploy fingerprint found. Run /deploy-check --install to add version verification.')
} else if (!preflight.deploy_check.match) {
  log(`Warning: Deployed SHA ${preflight.deploy_check.deployed_sha} does not match HEAD ${preflight.deploy_check.head_sha}. Testing may reflect an older build.`)
} else {
  log(`Deploy verified: SHA ${preflight.deploy_check.deployed_sha} matches HEAD.`)
}

log(`${preflight.story_count} stories found in catalog. Starting walks...`)

// Phase 2: Plan
phase('Plan')

const stories = preflight.stories || []
if (stories.length === 0) {
  log('No stories parsed from catalog.')
  return { status: 'blocked', reason: 'Catalog exists but no stories parsed' }
}

// Phase 3: Walk — parallel story walking (up to 4 concurrent for browser stability)
phase('Walk')
log(`Walking ${stories.length} stories in parallel...`)

const walkResults = await parallel(
  stories.map(story => () =>
    agent(
      `Walk the UX story "${story.title}" (${story.id}) through a real browser at ${targetUrl}.

Use agent-browser (the direct binary, not npx) to:
1. Open ${targetUrl}
2. Follow each step in the story
3. At each step:
   - Take a snapshot: agent-browser snapshot -i
   - Check for console errors: agent-browser errors
   - Check for visual issues (overlapping elements, broken layouts, missing content)
   - Check for UX issues (confusing labels, missing feedback, broken flows)
   - Check accessibility (contrast, labels, keyboard nav where applicable)
4. Record findings with severity

STORY: ${story.title}
ID: ${story.id}

If agent-browser is not available, simulate the walk by reading the codebase to trace the user path and identify potential issues from code analysis.

Rules:
- Only report real issues you can see or trace through code
- Screenshot descriptions should be specific enough to reproduce
- Empty findings array is fine for stories that pass cleanly`,
      { label: `walk:${story.id}`, phase: 'Walk', schema: WALK_RESULT_SCHEMA }
    )
  )
)

const validWalks = walkResults.filter(Boolean)
const allFindings = validWalks.flatMap(w => w.findings.map(f => ({ ...f, story_id: w.story_id, story_title: w.story_title })))
const passed = validWalks.filter(w => w.status === 'pass').length
const failed = validWalks.filter(w => w.status === 'fail').length

log(`Walks complete: ${passed} passed, ${failed} failed, ${allFindings.length} total findings.`)

// Phase 4: Triage
phase('Triage')

const critical = allFindings.filter(f => f.severity === 'critical' || f.severity === 'high')
const minor = allFindings.filter(f => f.severity === 'medium' || f.severity === 'low')

log(`Triage: ${critical.length} critical/high, ${minor.length} medium/low findings.`)

// Phase 5: Report
phase('Report')
log('Generating report...')

const findingsJson = JSON.stringify(allFindings, null, 2)
const walksJson = JSON.stringify(validWalks.map(w => ({ story_id: w.story_id, story_title: w.story_title, status: w.status, steps_completed: w.steps_completed, steps_total: w.steps_total, findings_count: w.findings.length, notes: w.notes })), null, 2)

const report = await agent(
  `Write a UX walker report to docs/ux-walker/latest-report.md.

Create the directory if needed: mkdir -p docs/ux-walker

WALK RESULTS:
${walksJson}

ALL FINDINGS:
${findingsJson}

DEPLOY CHECK:
${JSON.stringify(preflight.deploy_check)}

Write a clean markdown report with:
1. Header with date, URL, deploy SHA, story count
2. Summary: X passed, Y failed, Z findings
3. Critical/High findings section (if any) — each with story, description, severity
4. Medium/Low findings section (if any)
5. Stories that passed cleanly (list)
6. Recommendations

Also update docs/ux-walker/run-history.json (create if needed) with this run's results.`,
  { label: 'report:write', phase: 'Report', schema: REPORT_SCHEMA }
)

log(report.summary)

return {
  status: failed > 0 ? 'findings' : 'clean',
  url: targetUrl,
  deploy_verified: preflight.deploy_check.match,
  stories_walked: validWalks.length,
  stories_passed: passed,
  stories_failed: failed,
  total_findings: allFindings.length,
  critical_high: critical.length,
  medium_low: minor.length,
  report_path: report.report_path,
}
