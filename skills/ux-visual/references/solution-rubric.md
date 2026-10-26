# Solution judging rubric and defense template

## Judges and lenses
Three judges per cluster, each scoring every proposal independently:
- **Usability** — a first-time user doing the core task: speed, discoverability,
  error-proneness, clarity of state and labels.
- **Visual craft** — hierarchy, rhythm, density, alignment, consistency with the
  design system and with the rest of the app.
- **Engineering** — scope, risk, reuse of existing components/tokens, ease of
  testing, impact on other surfaces.

## External judges
Meta MUSE Wonder and Google Gemini 4 Argon (run by second-opinion.mjs --mode judge) score with the same criteria and return a winner, an optional graft, and a defense. They count as two additional votes. Record their scores in the decision table; if both reject the chosen option, the decision must rebut their reasoning explicitly.

## Criteria (score 1–5 each; weights in brackets)
1. Meets every acceptance criterion of the cluster, measurably [×3]
2. Simplicity — fewer elements/steps/states for the user [×2]
3. Consistency — reuses system patterns; one concept, one look [×2]
4. Usability — task speed, error prevention, accessibility [×2]
5. Visual quality — hierarchy, density, whitespace, alignment [×2]
6. Effort and risk (5 = small and safe) [×1]
Any proposal that fails criterion 1 is disqualified unless every proposal fails
it — then the judges must specify the graft that makes the best one pass.

Judges may propose a **graft**: one concrete element from a runner-up that
improves the winner without breaking its idea.

## Decision document (decisions/{cluster}.md)

```markdown
# {cluster-id}: {title}

## Problem
{root cause, findings covered, evidence links, acceptance criteria}

## Options considered
| Option | Idea | Weighted score (U / V / E judges) |
|--------|------|-----------------------------------|
| A Minimal | ... | 34 / 31 / 38 |
| B Restructure | ... | 41 / 44 / 33 |
| C Convention | ... | 39 / 40 / 35 |

## Decision
{the chosen option, plus grafts, stated precisely enough to implement}

## Why this is the best
- Against A: ...
- Against C: ...
- Norms satisfied: L1, L3, H1 ...
- Costs and what it rules out: ...

## Implementation plan
{design-system changes first (tokens → CSS → components → catalog), then pages; files}

## Test plan
{failing-first tests: layout assertions, e2e, unit; viewports; states}
```
