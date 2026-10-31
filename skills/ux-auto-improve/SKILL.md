---
name: ux-auto-improve
description: "Improve one section of an app end to end, in a loop: a cheap reviewer critiques the section (UX, DRY, modularity, speed, reliability, missing user stories), a strong model (Opus or Fable) judges the proposals for user experience and argues against them adversarially, cheap implementers build the survivors in parallel with regression tests, the lead tests and merges, and every merged improvement is defended with a narrated before/after walkthrough video (female voice). Code-only changes get clear system illustrations instead of screen recordings. Use when asked to 'auto-improve the app', 'run ux-auto-improve', 'review and improve a section', or invoked as /ux-auto-improve [section]."
version: 0.1.0
user_invocable: true
---

# UX auto-improve

One round improves one **section** of the app (a feature area such as "Live
pages" or "Settings"). Run it under `/loop` to keep going section by section.

```
/ux-auto-improve              # pick the next section not yet reviewed
/ux-auto-improve Live pages   # review this section
```

The lead (you) owns choosing the section, checking claims, integration,
merging and the final report. Subagents do the reviewing, building and
recording. Every subagent gets an explicit `model`.

## The round

### 1. Pick the section
Use the argument, or the next unreviewed area. Keep a ledger at
`docs/ux-auto-improve/ledger.md` (section, date, PRs, videos) in the target
repo, or in a scratch folder if the repo should not carry it. Prefer recently
shipped areas that have had no UX pass.

### 2. Review (cheap model)
Spawn one reviewer (`sonnet`; use `opus` or `fable` only when the section is an
architecture question). It reads the code and the plan docs, starts the app
(the project's demo/preview stack, never the user's live instance), seeds fake
data if needed, uses the section through a real browser, and screenshots it.
It answers, with file:line or screenshot evidence:
- Could this be improved?
- How could the user experience be better: fewer steps, clearer, faster, more intuitive?
- Could the code be more DRY, more modular, more self-contained?
- Could it be faster? More reliable?
- Which user stories are unaddressed and should be?

Output: at most 8 ranked proposals (problem with evidence, concrete change,
user-visible effect, risk, size S/M/L) plus a screenshot list. Removing things
counts as an improvement. No new product surfaces or speculative abstractions.

**Lead check:** reopen 2–3 of the strongest cited claims in the code yourself
before passing them on.

### 3. Judge and adversarial check (Opus or Fable)
Spawn one strong reviewer with the proposals file and screenshots. For each
proposal it answers:
- Does the experience get better, faster, easier, more intuitive, or does it add clutter?
- Do we break any functionality? Name the flow, test or contract at risk (other clients that decode the same API, security boundaries, autosave, etc.).
- Does everything still behave as expected? What edge cases were missed?
- Adversarially: is the claimed problem real in the code? What is the strongest case against doing it?
- Which user stories have gone unaddressed, and which should be addressed now?

Output: **approved work packages** with a tightened spec each (exact behaviour,
exact visible copy, files owned, the regression test that must fail first,
what must NOT change), grouped so packages touch separate files; changed and
rejected proposals with reasons; and a visual/UX regression checklist for
testers (screens, states, light and dark, phone width).

**Lead check:** verify the reviewer's corrections that change the plan. A
second reviewer often finds the first one's evidence came from bad seed data.

### 4. Build (cheap models, in parallel)
One `sonnet` implementer per package (merge tiny packages into a neighbour),
each in its own git worktree and branch, all launched in one message. Each brief
names: the spec section, owned files and other agents' files, failing
regression test first, focused tests and typecheck, a hand test in a real
browser (one demo stack at a time on a free slot; Storybook stories are fine
for isolated components), screenshots to a known folder, commit on the branch,
**no push, no PR, no merge**. Ask the first web implementer to write a
reusable, idempotent fake-data seed script so testers and the recorder can
reproduce the same states.

### 5. Integrate, test, merge (lead)
- Read each diff and the decisive test output and screenshots. A completion message is not proof.
- Send corrections back to the same implementer.
- Merge packages in dependency order. Run the repo's required checks, follow its review and merge rules (CI, required review, PR watch).
- Hand test the merged result once on a fresh demo stack, walking the reviewer's checklist.
- Open one PR per package or one per round, whichever the repo prefers. Each PR body says why (the user-visible problem), what changed, and how it was tested, and links the video.

### 6. Defend each improvement with a video
For every merged improvement, make a short narrated walkthrough (30–90 s):
1. **Before:** record the old behaviour on the base commit with the same seed data.
2. **After:** record the new behaviour on the merged commit.
3. Narrate in plain sentences: what the user was trying to do, what went wrong before, what happens now, and why it is better. One or two sentences per scene.

Recording: drive the app with Playwright (`recordVideo`) or take a sequence of
agent-browser screenshots. Use a 1440×900 or 1920×1080 viewport, zoom so text is
readable on video, and pause on each state long enough to read it.

**Code-only improvements** (speed, DRY, reliability) get illustrations instead of
screen recordings: simple diagrams rendered from HTML or SVG to PNG, one idea per
frame, large type (at least 32 px at 1080p), at most about 6 boxes, the before
and after shown side by side or as consecutive frames, with the change
highlighted in one accent colour. No dense architecture diagrams.

Render the scenes with the bundled script:

```bash
# scenes.tsv: <png|mp4 path><TAB><narration>
skills/ux-auto-improve/scripts/make-video.sh scenes.tsv out/live-pages-paused.mp4
```

The voice is ElevenLabs "Rachel" (female) when `ELEVENLABS_API_KEY` is set, or
`UX_VOICE_ID` picks another voice; otherwise macOS `say`. Only narration
text is sent to the TTS service, so keep secrets and private data out of it.
Watch at least one scene of each video (or read back its frames) before
calling it done. Store videos outside a public repo unless the owner says
otherwise; link them in the report.

### 7. Report, then loop
Report per improvement: what changed and why, tests, what was hand tested,
the PR, the video path, and what remains unverified. Record deferred
proposals and new user stories in the ledger, then start the next section.

## Rules
- Never run against the user's live instance or real accounts; use demo/preview stacks and fake data.
- Keep at most 1–2 heavy stacks running at once; always stop the ones you start.
- Follow the repo's AGENTS.md/CLAUDE.md for copy, design system, tests, and PR rules; they override this skill.
- Public repos: no secrets, local paths or real data in commits, PRs, or committed docs.
