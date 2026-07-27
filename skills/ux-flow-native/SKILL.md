---
name: ux-flow-native
description: "Critique a native macOS/iOS app's user experience for simplicity, clarity, and redundancy. Measures friction against the ideal path, hunts duplicated features across windows and menus, and audits visual hierarchy, keyboard reachability, and platform conventions. Use when asked to 'simplify the native app ux', 'audit the mac app flows', 'find redundancy in the desktop app', or 'run ux-flow-native'. For web apps use ux-flow instead."
version: 0.1.0
user_invocable: true
---

# UX Flow (native macOS/iOS)

For each core journey: how could this be simpler, how could this be clearer.

This is the sibling of `/ux-flow`. The method — journey selection, parallel
critics, redundancy critic, synthesis — is inherited unchanged. Read
`../ux-flow/SKILL.md` and follow it, applying the substitutions
below. Do not duplicate its phases here.

---

## What changes

### Evidence source

`/ux-flow` reads walk evidence from `/ux-walker`. This reads it from
`/ux-walker-native`: the same `walk-report.md` and `findings.json` layout, plus
the **Platform** section and the geometry violations from `nativeui geometry`.

If no native walk exists, say so and either run `/ux-walker-native` first or
critique from the code and the story catalog alone — labelled clearly as
un-walked, following the inherited honesty rules.

### Friction is counted differently

On the web, friction is clicks and page loads. Here, count:

- **Clicks** to complete the journey vs. the ideal path
- **Keystrokes**, and whether the journey is possible without the mouse at all
- **Window and sheet transitions** — every new window is a context switch and
  costs more than a page navigation does
- **Mouse travel** — a flow that drags the pointer from a sidebar to a far
  toolbar and back on every iteration is friction the click count hides
- **Mode switches** — moving between mouse and keyboard mid-flow

A journey the menu bar could do in one keystroke but the UI takes six clicks for
is the signature native finding. Look for it specifically.

### Redundancy hunting, native edition

The redundancy critic looks for the same capability offered more than once. In a
native app, check every one of these against each other:

- the main window's controls
- the sidebar
- the toolbar
- the menu bar
- context menus
- keyboard shortcuts
- the settings window
- the dock menu

Three of these offering the same action is often correct on a Mac — menu bar,
toolbar and shortcut for one command is the platform convention, not
duplication. **Say so rather than flagging it.** What is genuinely redundant:

- The same setting editable in two places that can disagree
- Two different controls that do the same thing with different labels
- Information shown identically in the sidebar and the main pane at once
- A custom control duplicating something the system already provides
- A preference the app never reads

### Additional critic lenses

Alongside the inherited ones, each journey critic should ask:

**Platform fit.** Does this behave the way a Mac app should, or like a web page
in a window? Real menu bar, standard shortcuts, sheets not custom modals, system
colours, native controls, drag and drop where expected.

**Keyboard-first.** Could a keyboard user complete this journey comfortably —
not merely possibly? Where does focus go after each action? Does the tab order
follow the visual order?

**Window economy.** Does the journey open windows it does not need? Could a
sheet or an inline expansion replace a whole window? Conversely, is something
cramped into one window that deserves its own?

**Progressive disclosure via panes.** Native apps hide complexity in inspectors,
sidebars and settings. Is the right thing hidden? Is anything hidden that the
user needs on the main path?

**Settings sprawl.** Is there a preference for something that should just have a
sensible default? Every toggle is a decision pushed onto the user.

### What to drop

Do not carry over web-only critique dimensions: page weight, above-the-fold,
scroll depth, breakpoint behaviour, URL structure, browser history. Replace the
responsive dimension with **small-window behaviour**, using the narrow-window
screenshots from the native walk.

---

## Output

Identical structure to `/ux-flow`, with one added section in the synthesis:

**Platform report card** — a short verdict on each of: menu bar completeness,
shortcut coverage and correctness, keyboard reachability, window behaviour,
accessibility labelling, and appearance support. Each line cites the walk
evidence behind it, or says "not walked".
