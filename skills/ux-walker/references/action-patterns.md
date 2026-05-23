# Action Patterns — Story Step to agent-browser Translation

This reference maps common UX story actions to their `agent-browser` CLI equivalents. Walker sub-agents use this to translate catalog story steps into executable browser commands.

## Session Management

```bash
# Start session (done once by orchestrator in preflight)
agent-browser --session {SESSION} open {URL}
agent-browser --session {SESSION} wait --load networkidle

# Save auth state (after login flows)
agent-browser --session {SESSION} state save docs/ux-walker/.browser-state

# Restore auth state (for subsequent stories)
agent-browser --session {SESSION} state load docs/ux-walker/.browser-state

# Close session (done once at end)
agent-browser --session {SESSION} close
```

## Core Workflow: Snapshot-Driven Interaction

**Always follow this pattern:**

1. **Snapshot** — Read the current page state
2. **Find** — Locate the target element from the snapshot
3. **Act** — Perform the action
4. **Screenshot** — Capture the result
5. **Verify** — Check the expected outcome

```bash
# 1. Snapshot (returns accessibility tree with element refs)
agent-browser --session {SESSION} snapshot

# 2. Find element — use snapshot output to identify element by:
#    - Text content: look for button/link text in snapshot
#    - Role: look for role annotations (button, textbox, link, etc.)
#    - Ref number: use the [ref=N] annotation from snapshot

# 3. Act (see action table below)
# 4. Screenshot
agent-browser --session {SESSION} screenshot {path}
# 5. Verify — read snapshot again, check for expected state changes
```

## Action Table

### Navigation

| Story Step Pattern | agent-browser Command |
|---|---|
| "Navigate to {url}" | `agent-browser --session {S} navigate {url}` |
| "Go to {page}" | `agent-browser --session {S} navigate {base_url}/{page}` |
| "Click the back button" | `agent-browser --session {S} navigate back` |
| "Refresh the page" | `agent-browser --session {S} navigate reload` |
| "Open {url} in a new tab" | `agent-browser --session {S} navigate {url}` |

### Clicking

| Story Step Pattern | agent-browser Command |
|---|---|
| "Click {button text}" | `agent-browser --session {S} click --text "{button text}"` |
| "Click the {Nth} item" | `agent-browser --session {S} click --ref {N}` (from snapshot) |
| "Click the icon/logo" | Take snapshot, find ref for icon, `click --ref {N}` |
| "Select {option} from dropdown" | `click` the dropdown, then `click --text "{option}"` |
| "Toggle {switch name}" | `click --text "{switch name}"` or `click --ref {N}` |
| "Click the link to {page}" | `click --text "{link text}"` |

### Typing / Input

| Story Step Pattern | agent-browser Command |
|---|---|
| "Type {text} in {field}" | `agent-browser --session {S} type --ref {N} "{text}"` |
| "Enter {value} in the {field name} field" | Find field by label in snapshot, `type --ref {N} "{value}"` |
| "Clear the {field} and type {text}" | `agent-browser --session {S} fill --ref {N} "{text}"` |
| "Press Enter" | `agent-browser --session {S} press Enter` |
| "Press Escape" | `agent-browser --session {S} press Escape` |
| "Press Tab" | `agent-browser --session {S} press Tab` |

### Scrolling

| Story Step Pattern | agent-browser Command |
|---|---|
| "Scroll down" | `agent-browser --session {S} scroll down` |
| "Scroll to {element}" | `agent-browser --session {S} scroll --ref {N}` |
| "Scroll to bottom" | `agent-browser --session {S} scroll bottom` |

### Waiting

| Story Step Pattern | agent-browser Command |
|---|---|
| "Wait for page to load" | `agent-browser --session {S} wait --load networkidle` |
| "Wait for {element} to appear" | `agent-browser --session {S} wait --text "{element}"` |
| "Wait {N} seconds" | `sleep {N}` (use sparingly, prefer wait conditions) |

### Screenshots & Evidence

| Purpose | Command |
|---|---|
| Step screenshot | `agent-browser --session {S} screenshot {dir}/step-{N}.png` |
| Finding screenshot | `agent-browser --session {S} screenshot {dir}/finding-{ID}.png` |
| Full page screenshot | `agent-browser --session {S} screenshot --full {path}` |
| Video start | `agent-browser --session {S} video start {path}` |
| Video stop | `agent-browser --session {S} video stop` |

## Complex Interaction Patterns

### Login Flow
```bash
agent-browser --session {S} snapshot
# Find email field
agent-browser --session {S} type --ref {email_ref} "test@example.com"
agent-browser --session {S} type --ref {password_ref} "password123"
agent-browser --session {S} click --text "Sign In"
agent-browser --session {S} wait --load networkidle
agent-browser --session {S} screenshot {dir}/after-login.png
# Save state for reuse
agent-browser --session {S} state save docs/ux-walker/.browser-state
```

### Form Filling
```bash
agent-browser --session {S} snapshot
# Fill fields in order (use refs from snapshot)
agent-browser --session {S} fill --ref {ref1} "Value 1"
agent-browser --session {S} fill --ref {ref2} "Value 2"
# Select dropdown
agent-browser --session {S} click --ref {dropdown_ref}
sleep 0.5
agent-browser --session {S} click --text "Option A"
# Submit
agent-browser --session {S} click --text "Submit"
agent-browser --session {S} wait --load networkidle
```

### Modal / Dialog Interaction
```bash
# Trigger modal
agent-browser --session {S} click --text "Open Settings"
sleep 0.5
agent-browser --session {S} snapshot  # Modal should now be in the tree
agent-browser --session {S} screenshot {dir}/modal-open.png
# Interact with modal content
agent-browser --session {S} click --text "Save Changes"
sleep 0.5
agent-browser --session {S} snapshot  # Verify modal closed
```

### Drag and Drop
```bash
agent-browser --session {S} drag --from-ref {source_ref} --to-ref {target_ref}
sleep 0.5
agent-browser --session {S} screenshot {dir}/after-drag.png
```

### Hover State Inspection
```bash
agent-browser --session {S} hover --ref {element_ref}
sleep 0.3
agent-browser --session {S} screenshot {dir}/hover-state.png
```

## Verification Patterns

### Check element exists
```bash
agent-browser --session {S} snapshot
# Parse snapshot output — look for expected text/element
# If found → pass; if not → finding
```

### Check URL changed
```bash
agent-browser --session {S} url
# Compare with expected URL pattern
```

### Check text content
```bash
agent-browser --session {S} text --ref {N}
# Compare with expected content
```

### Check visual state
```bash
agent-browser --session {S} screenshot {path}
# Sub-agent visually inspects screenshot for:
# - Correct layout
# - No broken elements
# - Expected content visible
```

## Pacing Guidelines

- Add `sleep 0.5` after clicks that trigger animations or transitions
- Add `sleep 1` after navigation or form submissions
- Use `wait --load networkidle` after page navigations
- Use `wait --text "{expected}"` when waiting for specific content to appear
- For video captures of interactive issues: `sleep 1-2` between actions for clarity

## Error Recovery

If an action fails:
1. Take a screenshot of the current state
2. Try a snapshot to understand where we are
3. Attempt recovery:
   - If element not found: scroll, wait, re-snapshot
   - If page error: navigate back, refresh
   - If session lost: report to orchestrator
4. If recovery fails after 2 attempts: log failure, continue to next step
