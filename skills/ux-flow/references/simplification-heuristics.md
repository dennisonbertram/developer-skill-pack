# Simplification Heuristics

The question battery for `/ux-flow` critics. Each heuristic: the question, how
to detect a violation, and the typical fix. These are established interaction-
design principles (step/decision economy, progressive disclosure, recognition
over recall, consistency) applied as concrete checks — not novel rules.

## Flow heuristics (per journey)

### 1. Step economy
**Ask**: Could this goal be reached in fewer steps without hiding information the user needs?
**Detect**: Count actual clicks/inputs/screens; compare to the story's Ideal path.
**Fix**: Merge screens, combine confirm+submit, deep-link past hub pages, batch inputs.

### 2. Decision economy
**Ask**: Does every choice the user makes actually matter to them?
**Detect**: List each decision point; for each, would 90% of users pick the same option?
**Fix**: Make that option the default, move the choice to settings or an "advanced" disclosure.

### 3. Don't ask for what you know
**Ask**: Is the user re-entering data the app already has?
**Detect**: Any input pre-fillable from account, context, or a previous step but empty.
**Fix**: Prefill, infer, or drop the field.

### 4. Confirmation budget
**Ask**: Does each confirmation guard something destructive or irreversible?
**Detect**: Confirmations on safe/undoable actions; double confirmations.
**Fix**: Remove the dialog; prefer undo over confirm.

### 5. Dead-end audit
**Ask**: After every action, is the next step obvious from the resulting screen?
**Detect**: Success screens with no onward action; flows ending at a bare toast; back-button-only exits.
**Fix**: Every terminal screen offers the likely next action ("View it", "Create another", "Back to list").

### 6. Shortest path to value
**Ask**: How many steps from first arrival to the first moment of real value?
**Detect**: Walk the new-user story counting steps before the user has DONE the core thing once.
**Fix**: Defer setup (profile, preferences, invites) until after first success.

### 7. Recognition over recall
**Ask**: Must the user remember anything from a previous screen to succeed here?
**Detect**: IDs/names/values that must be memorized or re-typed across screens; codes with no copy affordance.
**Fix**: Carry context forward; show, don't quiz.

## Screen heuristics (per screen)

### 8. Take-away test
**Ask**: For each visible element — if removed, would the user still succeed?
**Detect**: Elements no story step ever uses; decoration competing with content.
**Fix**: Remove, collapse behind disclosure, or move to an advanced section. Removal is the default; keeping needs the justification.

### 9. One primary action
**Ask**: Squinting at the screen, is exactly one action visually dominant — and is it the right one?
**Detect**: Zero or 2+ equally-weighted primary buttons; the visually loudest element isn't the next step.
**Fix**: One primary style per screen; demote the rest to secondary/tertiary.

### 10. Hierarchy matches importance
**Ask**: Does visual weight (size, color, position) track how much the user cares?
**Detect**: Key info smaller/quieter than chrome, badges, or metadata; everything bold (emphasis inflation).
**Fix**: Re-weight: important things big and first, trivia small and last; spend emphasis sparingly.

### 11. Progressive disclosure
**Ask**: Is anything shown before the user needs it?
**Detect**: Long forms where later fields depend on earlier answers; advanced options mixed with basics; help paragraphs above the action.
**Fix**: Stage it — show the next thing when the previous thing is done.

### 12. Once and only once (information)
**Ask**: Is each fact stated exactly once per screen?
**Detect**: Same title/status/metadata in header AND breadcrumb AND card AND sidebar.
**Fix**: Pick the canonical surface; the rest reference it or drop it.

## App heuristics (cross-journey — redundancy critic)

### 13. One way to do one thing
**Ask**: Is each duplicate route to a goal a deliberate shortcut, or drift?
**Detect**: Alternate paths fields in the catalog; same verb in two menus; two screens that both edit the same entity.
**Fix**: Mark one route canonical; keep shortcuts only when they're accelerators of the canonical route, not parallel implementations.

### 14. One concept, one name
**Ask**: Is every concept called the same thing everywhere?
**Detect**: "Workspace" vs "project" vs "space" for the same entity across screens, docs, and buttons.
**Fix**: Pick one term; rename all surfaces.

### 15. Feature overlap
**Ask**: Do two features substantially do the same job?
**Detect**: Two tools/panels/reports whose capabilities overlap enough that users won't know which to use.
**Fix**: Merge, sharply differentiate, or remove one.

### 16. Navigation depth vs. importance
**Ask**: Is anything users need often buried 3+ levels deep? Anything rare sitting at top level?
**Detect**: Map each core-story destination to its click depth from home.
**Fix**: Promote the frequent, demote the rare.

## Verdict calibration

| Verdict | Meaning |
|---------|---------|
| **minimal** | Actual ≈ ideal steps; take-away pass finds little; no redundancy involving this journey |
| **acceptable** | 1-2 extra steps or a few removable elements; nothing structural |
| **convoluted** | 3+ extra steps, forced detours, duplicated surfaces, or a screen failing 3+ heuristics |

Do not grade on a curve. If everything is minimal, the report says so — that is
a useful result, not a failed critique.
