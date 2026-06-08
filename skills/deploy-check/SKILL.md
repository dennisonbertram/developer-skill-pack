---
name: deploy-check
description: "Instrument a frontend with version fingerprinting (meta tag + /__version endpoint) so LLM-based testing can verify the correct build is deployed before walking. Use when asked to 'add version check', 'deploy verification', 'instrument version', 'add build fingerprint', 'deploy-check', or before running ux-walker on a deploy."
version: 1.0.0
user_invocable: true
---

# Deploy Check

Instrument a frontend app with subtle version fingerprinting — a `<meta>` tag in the HTML and a `/__version` JSON endpoint — so automated testing (ux-walker, CI, curl) can confirm the correct build is deployed before testing begins.

## Usage

```
/deploy-check [--install] [--verify url] [--expected-sha sha]
```

| Parameter | Default | Notes |
|-----------|---------|-------|
| **--install** | Auto-detect | Instrument the current project with version fingerprinting |
| **--verify url** | None | Check a running app and report what version is deployed |
| **--expected-sha sha** | Current HEAD | Fail if the deployed SHA doesn't match |

If no flags given, auto-detect: if the project already has fingerprinting, run `--verify`; otherwise run `--install`.

---

## What Gets Installed

### 1. Meta Tag

A `<meta>` tag injected into the HTML `<head>` at build time:

```html
<meta name="build-version" content="sha:a1b2c3d timestamp:2026-06-08T12:00:00Z" />
```

Invisible to users. Readable by agent-browser:

```bash
agent-browser snapshot -i | grep 'build-version'
# or via JavaScript:
agent-browser js "document.querySelector('meta[name=build-version]')?.content"
```

### 2. Version Endpoint

A `/__version` route returning JSON:

```json
{
  "git_sha": "a1b2c3d",
  "git_branch": "main",
  "build_timestamp": "2026-06-08T12:00:00Z",
  "version": "1.2.3",
  "dirty": false
}
```

Readable by curl, fetch, or any HTTP client:

```bash
curl -s http://localhost:3000/__version | jq .
```

### 3. Build-time Script

A `scripts/version-stamp.sh` that generates a `version.json` at build time:

```bash
#!/usr/bin/env bash
set -euo pipefail

cat > "${1:-public/version.json}" <<JSON
{
  "git_sha": "$(git rev-parse --short HEAD)",
  "git_branch": "$(git rev-parse --abbrev-ref HEAD)",
  "build_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$(node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")",
  "dirty": $(git diff --quiet && echo false || echo true)
}
JSON
```

---

## Install Mode (`--install`)

Detect the framework and instrument accordingly. The orchestrator performs all steps directly — no sub-agents needed.

### Step 1: Detect Framework

Read `package.json` and project structure to identify the framework:

| Signal | Framework |
|--------|-----------|
| `next` in dependencies | Next.js |
| `vite` in devDependencies | Vite (React/Vue/Svelte) |
| `@remix-run/dev` in dependencies | Remix |
| `@angular/core` in dependencies | Angular |
| `gatsby` in dependencies | Gatsby |
| `astro` in dependencies | Astro |
| `nuxt` in dependencies | Nuxt |
| None of the above | Generic static / Express |

### Step 2: Create Version Stamp Script

Write `scripts/version-stamp.sh` (see template above). Make it executable.

### Step 3: Framework-Specific Instrumentation

#### Next.js

**Meta tag** — add to the root layout (`app/layout.tsx` or `pages/_document.tsx`):

```tsx
import versionData from '../../public/version.json';

// In the <head>:
<meta name="build-version" content={`sha:${versionData.git_sha} timestamp:${versionData.build_timestamp}`} />
```

**Endpoint** — create `app/api/__version/route.ts` (App Router) or `pages/api/__version.ts` (Pages Router):

```ts
import { NextResponse } from 'next/server';
import versionData from '../../../public/version.json';

export async function GET() {
  return NextResponse.json(versionData);
}
```

**Build hook** — add to `package.json` scripts:

```json
{
  "prebuild": "bash scripts/version-stamp.sh public/version.json",
  "predev": "bash scripts/version-stamp.sh public/version.json"
}
```

#### Vite (React / Vue / Svelte)

**Meta tag** — add to `index.html`:

```html
<!-- In <head>, replaced at build time by vite plugin or prebuild -->
<meta name="build-version" content="__BUILD_VERSION__" />
```

Create or update `vite.config.ts` to replace the placeholder:

```ts
import { defineConfig } from 'vite';
import fs from 'fs';

export default defineConfig({
  define: {
    __BUILD_VERSION__: JSON.stringify(
      (() => {
        try {
          const v = JSON.parse(fs.readFileSync('public/version.json', 'utf-8'));
          return `sha:${v.git_sha} timestamp:${v.build_timestamp}`;
        } catch { return 'unknown'; }
      })()
    ),
  },
});
```

**Endpoint** — Vite dev server middleware via plugin, or just serve `public/version.json` directly at `/__version` via a simple redirect/rewrite.

**Build hook**:

```json
{
  "prebuild": "bash scripts/version-stamp.sh public/version.json",
  "predev": "bash scripts/version-stamp.sh public/version.json"
}
```

#### Remix

**Meta tag** — add to `app/root.tsx` via the `meta` export or a direct `<meta>` in the `<head>`.

**Endpoint** — create `app/routes/__version.ts`:

```ts
import { json } from '@remix-run/node';
import versionData from '../../public/version.json';

export function loader() {
  return json(versionData);
}
```

#### Generic / Express / Static

**Meta tag** — find the main HTML file (`index.html`, `public/index.html`) and inject the meta tag.

**Endpoint** — if Express detected (`express` in dependencies), add middleware:

```ts
import versionData from './public/version.json';
app.get('/__version', (req, res) => res.json(versionData));
```

If static site, the `public/version.json` file is the endpoint — instruct the user to access it at `/version.json`.

### Step 4: Update `.gitignore`

Add `public/version.json` to `.gitignore` — it's generated at build time, not committed.

### Step 5: Verify Installation

```bash
# Generate the version stamp
bash scripts/version-stamp.sh public/version.json

# Check it was created
cat public/version.json
```

Report what was installed and which files were modified.

---

## Verify Mode (`--verify`)

Check a running app to confirm the deployed version matches expectations. This is what ux-walker calls before walking.

### Step 1: Read Version from Meta Tag

```bash
agent-browser open "{url}"
agent-browser js "document.querySelector('meta[name=\"build-version\"]')?.content"
```

Parse `sha:XXXXXX timestamp:YYYY-MM-DDTHH:MM:SSZ` from the result.

### Step 2: Read Version from Endpoint

```bash
curl -s "{url}/__version" 2>/dev/null || curl -s "{url}/version.json" 2>/dev/null
```

Parse the JSON response.

### Step 3: Compare Against Expected

If `--expected-sha` was provided, compare. Otherwise compare against `git rev-parse --short HEAD`.

**Output**:

```
Deploy Check Results
────────────────────
Meta tag SHA:      a1b2c3d ✓
Endpoint SHA:      a1b2c3d ✓
Expected SHA:      a1b2c3d ✓
Branch:            main
Build timestamp:   2026-06-08T12:00:00Z
Dirty:             false
Status:            VERIFIED — correct version deployed
```

If mismatch:

```
Deploy Check Results
────────────────────
Meta tag SHA:      a1b2c3d ✗
Expected SHA:      f4e5d6c
Status:            MISMATCH — deployed version does not match HEAD
                   The app is running an older build. Rebuild and redeploy,
                   or pass --expected-sha a1b2c3d to accept this version.
```

### Step 4: Return Verdict

Return a structured result that callers (ux-walker, CI) can act on:

```json
{
  "status": "verified",
  "deployed_sha": "a1b2c3d",
  "expected_sha": "a1b2c3d",
  "match": true,
  "branch": "main",
  "build_timestamp": "2026-06-08T12:00:00Z",
  "dirty": false
}
```

---

## Integration with UX Walker

When ux-walker runs its Phase 0 Preflight, it should call deploy-check verify:

```
Phase 0 — Preflight
├── 0.1 URL Check (existing)
├── 0.1.5 Deploy Check ← NEW
│   └── curl {url}/__version or read meta tag
│   └── Compare SHA against git rev-parse --short HEAD
│   └── If mismatch: warn but continue (don't block — the user may be testing an older deploy intentionally)
│   └── If missing: note "No version fingerprint found — run /deploy-check --install to add one"
├── 0.2 Catalog Check (existing)
└── ...
```

The version check is **advisory, not blocking** — if the fingerprint is missing or mismatched, ux-walker warns but proceeds. The user can install fingerprinting with `/deploy-check --install` when ready.

---

## Constraints

- Never commit `public/version.json` — it's build-time generated
- The meta tag must be invisible to end users (no visible UI element)
- The `/__version` endpoint must not leak sensitive information (no env vars, no secrets, no internal paths)
- Framework detection must not modify files outside the project
- The version stamp script must work on macOS and Linux (use portable `date` flags)
- If the project already has version fingerprinting (e.g., Sentry release, DataDog RUM version), detect it and integrate rather than duplicate
