# UX Visual Report — {DATE}

## Summary
| Metric | Value |
|--------|-------|
| Surfaces audited | {pages} pages × {states} states × {viewports} viewports |
| Coverage gaps | {list or "none"} |
| Findings | P0 {n} · P1 {n} · P2 {n} · P3 {n} |
| By level | component {n} · group {n} · page {n} · layout {n} |
| Clusters | {total} found · {implemented} implemented · {deferred} deferred |

## Implemented
### {cluster-id}: {title}
- **Problem**: {one line + key metric before, e.g. "page scrolls 412px at 1440x900"}
- **Decision**: {one line} — chosen over {alternatives} because {reason}
- **Result**: {metric after, criteria pass/fail}
- **Before / after**: `pages/{slug}/shots/...png` → `verification/{cluster}/...png`
- **Tests**: {specs added/updated, results}
- **Commit**: {sha} on {branch}

## Deferred
| Cluster | Severity | Why deferred | Issue |
|---------|----------|--------------|-------|

## Still failing / unverified
- ...

## Excellent as is
- {surfaces that passed clean, so re-runs can skip them}
