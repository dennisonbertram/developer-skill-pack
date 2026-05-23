# UX Audit Rubric

Used by ux-walker sub-agents to evaluate every page state encountered during story walks.

## Scoring

Each criterion is scored: `pass` | `warn` | `fail`
- **pass**: Meets expectations, no action needed
- **warn**: Minor issue, worth noting (medium/low severity finding)
- **fail**: Clear problem, must be addressed (high/critical severity finding)

## 1. Simplicity

**Question**: Is the user overwhelmed?

| Check | Pass | Warn | Fail |
|-------|------|------|------|
| Visible action count | ≤5 primary actions visible | 6-8 primary actions | >8 primary actions competing for attention |
| Information density | Appropriate for the task | Some unnecessary info visible | Wall of text or data overload |
| Decision complexity | Clear next step | Requires scanning | User must read everything to know what to do |
| Advanced options | Hidden behind toggle/menu | Visible but de-emphasized | Mixed with primary actions |

**"Take Away" Test**: For each visible element, ask: "If I removed this, would the user still succeed?" If yes, it should be hidden, collapsed, or moved to an advanced section.

## 2. Progressive Disclosure

**Question**: Does information appear when needed, not before?

| Check | Pass | Warn | Fail |
|-------|------|------|------|
| Form fields | Show only what's needed for current step | All fields visible but grouped | Long scrolling form with everything at once |
| Error messages | Appear on interaction/submission | Pre-shown but dimmed | Error states visible before user acts |
| Help text | Available on hover/click | Inline but concise | Paragraphs of instructions before the action |
| Secondary features | Revealed after primary task | Visible but clearly secondary | Competing with primary workflow |

## 3. Layout Quality

**Question**: Does the page use space effectively?

| Check | Pass | Warn | Fail |
|-------|------|------|------|
| Viewport usage | Content fills viewport appropriately | Minor whitespace gaps | Large empty areas or content crammed in corner |
| Scroll necessity | No unnecessary scrolling for primary task | Slight scroll needed | Must scroll to find primary action |
| Content width | Readable line lengths (45-75 chars for text) | Slightly wide/narrow | Full-width text or extremely narrow columns |
| Spacing consistency | Uniform spacing rhythm | Minor inconsistencies | Noticeably uneven spacing |
| Responsive behavior | Elements reflow gracefully | Minor alignment issues at edges | Broken layout, overlapping elements |

## 4. Visual Correctness

**Question**: Is the page visually sound?

| Check | Pass | Warn | Fail |
|-------|------|------|------|
| Overflow | No content overflow | Slight text truncation with ellipsis | Content spilling out of containers |
| Alignment | Elements properly aligned | 1-2px misalignment | Visibly misaligned elements |
| Theme consistency | Colors/fonts match design system | Minor deviation | Clashing styles, mixed themes |
| Broken elements | All elements render correctly | Minor rendering artifact | Missing images, broken layouts, empty containers |
| Z-index/layering | Proper stacking | Minor overlap on edge cases | Modals behind content, dropdowns clipped |

## 5. Happy Path Clarity

**Question**: Can a naive user accomplish the goal without help?

| Check | Pass | Warn | Fail |
|-------|------|------|------|
| Primary CTA | Obviously the next step | Identifiable with scanning | Buried or ambiguous |
| Labels/copy | Self-explanatory | Requires domain knowledge | Jargon, abbreviations, or misleading text |
| Navigation | User always knows where they are | Breadcrumbs/back available but not prominent | Lost/disoriented after action |
| Feedback | Clear success/error indication | Subtle feedback | No feedback after action |
| Recovery | Easy to undo or go back | Can go back but not obvious | Destructive action with no undo |

## 6. Accessibility Basics

**Question**: Are basic accessibility needs met?

| Check | Pass | Warn | Fail |
|-------|------|------|------|
| Color contrast | Meets WCAG AA (4.5:1 text, 3:1 large) | Close to threshold | Clearly insufficient contrast |
| Interactive sizing | Touch targets ≥44x44px | 32-44px | <32px targets |
| Focus indicators | Visible focus ring on tab | Focus visible but faint | No visible focus indicator |
| Alt text | Images have meaningful alt text | Generic alt text | Missing alt text on informative images |
| Keyboard nav | All actions reachable via keyboard | Most actions reachable | Key actions require mouse only |

## 7. Error Handling & Edge Cases

**Question**: Does the app handle problems gracefully?

| Check | Pass | Warn | Fail |
|-------|------|------|------|
| Empty states | Helpful message with action suggestion | Generic "no data" message | Blank/broken appearance |
| Loading states | Skeleton or spinner with context | Generic spinner | No loading indication, appears frozen |
| Error messages | Specific, actionable, non-technical | Generic but polite | Technical jargon, stack traces, or cryptic codes |
| Form validation | Inline, immediate, helpful | On submit only, but clear | Unclear what went wrong or how to fix |
| Network failure | Retry option, data preserved | Error shown, manual refresh needed | Silent failure, data lost |

## Finding Template

When a check results in `warn` or `fail`, create a finding:

```json
{
  "id": "F-{STORY_ID}-{SEQ}",
  "severity": "critical|high|medium|low|suggestion",
  "category": "simplicity|disclosure|layout|visual|happy-path|a11y|error-handling",
  "criterion": "Which specific check failed",
  "score": "warn|fail",
  "description": "What is wrong",
  "expected": "What should happen",
  "actual": "What actually happens",
  "screenshot": "path/to/screenshot.png",
  "suggested_fix": "How to fix it (if obvious)",
  "files_likely_involved": ["src/components/Foo.tsx"]
}
```

## Severity Mapping

- **critical**: App crashes, data loss, completely blocked workflow, security issue
- **high**: User cannot complete primary goal, major visual breakage, misleading UI
- **medium**: Annoying but workaround exists, moderate visual issues, confusing copy
- **low**: Minor cosmetic issue, slight inconvenience, polish item
- **suggestion**: Enhancement idea, not a bug ("this would be even better if...")
