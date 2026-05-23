---
name: setup-repo
description: "Scaffold a new repository with GitHub issue templates, PR template, development process docs, TDD workflow, hooks, and CI configuration. Use when asked to 'setup a repo', 'scaffold a project', 'init project structure', 'add github templates', 'setup development process', or 'bootstrap repo'."
version: 1.0.0
user_invocable: true
---

# Setup Repo

Scaffold a repository with production-grade development infrastructure: GitHub issue templates, PR template, development process documentation, TDD workflow configuration, hooks, and CI setup.

## Usage

```
/setup-repo [--full] [--templates-only] [--hooks-only] [--process-only]
```

| Parameter | Default | Notes |
|-----------|---------|-------|
| **--full** | On | Install everything |
| **--templates-only** | Off | Only GitHub issue/PR templates |
| **--hooks-only** | Off | Only hooks and settings |
| **--process-only** | Off | Only process documentation |

## What Gets Installed

### 1. GitHub Issue Templates

Three structured issue templates that enforce planning discipline:

#### Feature Slice (`.github/ISSUE_TEMPLATE/feature-slice.yml`)
- Why this matters
- User/operator path protected
- Behavior contract (Given/When/Then)
- Product and design spec
- Integration spec
- In scope / Out of scope
- Research and context sources
- Agent todo checklist
- Tests to add first (with expected red commands)
- TDD audit trail plan
- Regression risks
- Deploy impact
- Documentation handoff notes
- Definition of done

#### Bug Regression (`.github/ISSUE_TEMPLATE/bug-regression.yml`)
- Observed vs expected behavior
- Reproduction steps
- Regression test plan (smallest test + behavior proof)
- Blast radius
- Agent todo checklist
- TDD audit trail
- Documentation handoff notes
- Definition of done

#### Research Spike (`.github/ISSUE_TEMPLATE/research-spike.yml`)
- Research question
- Options to compare
- Documentation sources (Context7 + vendor docs)
- Agent todo checklist
- Expected output (recommendation in docs/research/)

#### Config (`.github/ISSUE_TEMPLATE/config.yml`)
- Disables blank issues
- Links to project docs index and build process

### 2. Pull Request Template (`.github/pull_request_template.md`)

Structured PR body:
- Summary with issue linkage (Closes #)
- Why / In Scope / Out of Scope
- Tests Added First (unit/integration/regression)
- Regression Risks Covered
- Docs Updated
- Verification checklist

### 3. Development Process Docs

#### `docs/process/development-workflow.md`
- Read context docs before work
- Plan before code
- One issue-sized branch per task
- Behavior-first TDD (Red → Green → Refactor)
- Formatting and type-check gates
- Docs updated with behavior changes

#### `docs/process/behavior-tdd.md`
- Behavior-first TDD checklist template
- Red/green commit discipline
- When separate commits are required vs optional

#### `docs/process/github-build-process.md`
- One issue per PR, one branch per issue
- PR-gated main branch
- CI gates before merge
- Deterministic tests before live systems

#### `docs/process/regression-discipline.md`
- Every bug fix requires a failing regression test first
- Mandatory for production incidents, customer bugs, auth/billing bugs
- Red/green audit trail

### 4. Claude Code Hooks (`.claude/settings.json`)

- **TDD reminder hook** (PreToolUse on Edit/Write of src/): Warns when modifying source without a failing test first
- **Session start hook**: Announces TDD-first requirement
- **Learning capture hooks** (Stop/SessionEnd): Gather learnings from completed work

### 5. Coordinator State Templates

- `docs/context/current-intent.md` — What we're building
- `docs/context/repo-practices.md` — Conventions and patterns
- `docs/context/known-issues.md` — Known problems
- `docs/plans/active-plan.md` — Current plan

## Execution

When invoked:

1. Check if `.github/ISSUE_TEMPLATE/` exists — skip templates if already present (ask user)
2. Check if `.claude/settings.json` exists — merge hooks if present, create if not
3. Create all directories: `.github/ISSUE_TEMPLATE/`, `docs/process/`, `docs/context/`, `docs/plans/`, `docs/research/`
4. Write all template and process files from the references in this skill
5. Add `.coord/` to `.gitignore`
6. Report what was created

## References

| Reference | Purpose |
|-----------|---------|
| [references/feature-slice.yml](references/feature-slice.yml) | Feature issue template |
| [references/bug-regression.yml](references/bug-regression.yml) | Bug issue template |
| [references/research-spike.yml](references/research-spike.yml) | Research issue template |
| [references/config.yml](references/config.yml) | Issue template config |
| [references/pull-request-template.md](references/pull-request-template.md) | PR template |
| [references/settings.json](references/settings.json) | Claude Code hooks |
