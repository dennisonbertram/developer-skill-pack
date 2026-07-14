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
          type: { type: 'string', enum: ['bug', 'ux-issue', 'visual', 'consistency', 'hierarchy', 'flow', 'accessibility', 'performance'] },
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

// Measurable layout defects: uneven sibling cards, overflow spills, wrapped
// controls, page overflow. Walk agents write this to a temp file and run it
// via `agent-browser eval` — numbers beat eyeballs for evenness/spacing.
// Kept in sync with skills/ux-walker/references/geometry-audit.js.
const GEOMETRY_AUDIT_SRC = String.raw`(() => {
  const sig = (e) => {
    let s = e.tagName.toLowerCase();
    if (e.id) s += '#' + e.id;
    else if (typeof e.className === 'string' && e.className.trim())
      s += '.' + e.className.trim().split(/\s+/).slice(0, 2).join('.');
    const t = (e.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 30);
    return t ? s + ' "' + t + '"' : s;
  };
  const vis = (e) => {
    const r = e.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    const cs = getComputedStyle(e);
    return cs.visibility !== 'hidden' && cs.display !== 'none';
  };
  const firstClass = (e) =>
    typeof e.className === 'string' ? (e.className.trim().split(/\s+/)[0] || '') : '';
  const out = {
    pageOverflowX: Math.max(0, document.documentElement.scrollWidth - window.innerWidth),
    unevenRows: [], overflowSpills: [], wrappedControls: [],
  };
  for (const p of document.querySelectorAll('body *')) {
    const cs = getComputedStyle(p);
    const flexRow = cs.display.includes('flex') && cs.flexDirection.startsWith('row');
    const grid = cs.display.includes('grid');
    if (!flexRow && !grid) continue;
    const kids = [...p.children].filter(vis);
    if (kids.length < 2 || kids.length > 16) continue;
    if (!kids.every((k) => k.tagName === kids[0].tagName && firstClass(k) === firstClass(kids[0]))) continue;
    const rects = kids.map((k) => k.getBoundingClientRect());
    const topDrift = Math.max(...rects.map((r) => r.top)) - Math.min(...rects.map((r) => r.top));
    if (topDrift > 24) continue;
    const hs = rects.map((r) => Math.round(r.height));
    const ws = rects.map((r) => Math.round(r.width));
    const sorted = [...rects].sort((a, b) => a.left - b.left);
    const gaps = [];
    for (let i = 1; i < sorted.length; i++) gaps.push(Math.round(sorted[i].left - sorted[i - 1].right));
    const issue = {};
    if (Math.max(...hs) - Math.min(...hs) > 8) issue.heights = hs;
    if (flexRow && Math.max(...ws) - Math.min(...ws) > 8) issue.widths = ws;
    if (gaps.length > 1 && Math.max(...gaps) - Math.min(...gaps) > 4) issue.gaps = gaps;
    if (topDrift > 3) issue.topDriftPx = Math.round(topDrift);
    if (Object.keys(issue).length)
      out.unevenRows.push({ container: sig(p), children: kids.length, ...issue });
  }
  for (const e of document.querySelectorAll('body *')) {
    if (!vis(e) || e.clientWidth < 24) continue;
    if (!getComputedStyle(e).overflowX.includes('visible')) continue;
    if (e.scrollWidth > e.clientWidth + 4)
      out.overflowSpills.push({ el: sig(e), spillPx: e.scrollWidth - e.clientWidth });
  }
  for (const b of document.querySelectorAll('button, [role="button"], a, summary, [class*="tab"], [class*="chip"], [class*="badge"]')) {
    if (!vis(b)) continue;
    const cs = getComputedStyle(b);
    if (cs.display === 'inline') continue;
    if (b.querySelector('br, svg, img')) continue;
    const label = (b.textContent || '').trim();
    if (!label || label.length > 40) continue;
    const lh = parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.4;
    const contentH = b.clientHeight - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
    if (contentH > lh * 1.8) out.wrappedControls.push(sig(b));
  }
  for (const k of ['unevenRows', 'overflowSpills', 'wrappedControls']) {
    if (out[k].length > 12) { out[k] = out[k].slice(0, 12); out[k + 'Truncated'] = true; }
  }
  return JSON.stringify(out);
})();`

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

Setup: write the geometry audit script below to /tmp/ux-geometry-audit.js (once, verbatim).

Use agent-browser (the direct binary, not npx) to:
1. Open ${targetUrl}
2. Follow each step in the story
3. At each step:
   - Take a snapshot: agent-browser snapshot -i
   - Take a screenshot to /tmp/ux-walk-${story.id}-step-N.png and OPEN IT with the
     Read tool. The accessibility snapshot cannot show misalignment, uneven cards,
     broken text wrapping, or spacing problems — only the screenshot can. A step
     where you did not view the screenshot is a step you did not audit.
   - In the screenshot, look for: sibling cards/tiles with different shapes
     (height/width/radius/padding), misaligned edges or inconsistent indentation,
     uneven gaps, wrapped button/tab labels, overflow/clipping, more than one
     competing primary action, the same information shown twice on one screen
   - Check for console errors: agent-browser errors
   - Check for UX issues (confusing labels, missing feedback, broken flows)
   - Check accessibility (contrast, labels, keyboard nav where applicable)
4. At each DISTINCT page state (new page or major layout change), run the
   geometry audit: agent-browser eval "$(cat /tmp/ux-geometry-audit.js)"
   It returns JSON (uneven sibling rows, overflow spills, wrapped controls, page
   overflow). Confirm each hit in the screenshot, then record it as a finding
   (type: consistency for evenness/alignment, visual for overflow/wrap).
5. Track flow friction across the whole story: extra steps vs. what the goal
   should need, moments a first-time user would hesitate (control not found on
   first snapshot, ambiguous label), data re-entered that the app already knows,
   confirmations that guard nothing destructive. Record these as findings with
   type: flow.
6. Record findings with severity

STORY: ${story.title}
ID: ${story.id}

If agent-browser is not available, simulate the walk by reading the codebase to trace the user path and identify potential issues from code analysis.

Rules:
- Only report real issues you can see or trace through code
- Screenshot descriptions should be specific enough to reproduce
- One systemic defect is ONE finding: if the same component is uneven on five
  screens, report it once listing all occurrences
- Empty findings array is fine for stories that pass cleanly

GEOMETRY AUDIT SCRIPT (write verbatim to /tmp/ux-geometry-audit.js):
${GEOMETRY_AUDIT_SRC}`,
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
