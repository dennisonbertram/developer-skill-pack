# Native inspection — what to look for

Two sources of truth, and they catch different things. Use both at every screen.

- **The screenshot** shows what the user sees: alignment, crowding, clipped
  text, whether anything looks broken. Only your eyes catch this.
- **The tree** shows what the app claims exists: labels, values, enabled state,
  exact frames. Only the tree catches an unlabelled button or a toggle whose
  value never changed.

A screen audited by only one of them is half audited.

## In the screenshot

Everything the web walker looks for applies. These are the ones native apps get
wrong most often:

**Sibling consistency.** Rows in a list, buttons in a toolbar, cards in a grid —
same height, same padding, same corner radius? SwiftUI stacks size to content, so
one long label silently makes its row taller than the rest.

**Edge alignment.** Left edges of stacked sections, tops of side-by-side
controls, label/field pairs, indentation of nested rows. Misalignment of a few
points is visible and reads as sloppiness.

**Text truncation vs. wrapping.** Native controls truncate with an ellipsis by
default. A label ending in "…" where the user needs the full value is a finding.
A control that grew two lines tall to fit its label is a different finding.

**Density.** Native apps inherit generous default padding. A window that is
mostly empty space with content crammed in one corner fails the layout check
even though nothing is technically broken.

**Dark mode.** Screenshot in both appearances if the story touches theming.
Hardcoded colours show up immediately: a white card in dark mode, invisible grey
text, an icon that vanishes.

**Focus ring.** Is the keyboard focus visible? Native users tab. An invisible
focus ring is an accessibility failure and a usability one.

**Disabled state.** Does a disabled control actually look disabled, or just fail
silently when clicked?

## In the tree

**Unlabelled interactive elements.** Any element with an interactive role and no
`label`, `help`, or `placeholder` is invisible to VoiceOver and unreachable by
label in a walk. Log every one as `a11y`. Icon-only buttons are the usual
culprit — they need an accessibility label even when the icon is obvious.

**Values that do not change.** After toggling something, compare the `value`
before and after. A control that looks like it responded but did not change
state is a bug the screenshot cannot show.

**Enabled state that lies.** A control reported `enabled: true` that does nothing
when pressed, or `enabled: false` that still fires.

**Frames of zero size.** An element in the tree with a zero or near-zero frame is
either hidden (fine) or broken layout (not fine). Cross-check against the
screenshot.

**Duplicate labels.** Two controls with the same label on one screen are
ambiguous for keyboard and assistive-technology users, and they make the walk
itself ambiguous.

**Depth.** A very deep tree for a simple screen often signals nested containers
that will fight you on resize. Not a finding on its own; a hint about where
layout bugs will be.

## What the geometry audit reports

`nativeui geometry` returns violations of these kinds:

| Kind | Meaning |
|---|---|
| `overflow-horizontal` | An element is drawn past the window's edge — clipped or spilling |
| `uneven-sibling-height` | Siblings of one role vary more than 15% (or 3pt) in height |
| `left-edge-drift` | Stacked siblings do not share a left edge |
| `uneven-gaps` | Vertical spacing between stacked siblings is inconsistent |
| `possible-wrapped-control` | A control is much taller than its peers — its label is probably wrapping |

Treat each as a measurement, not a verdict. Confirm it in the screenshot, then
decide whether it is a defect or intentional. A deliberately larger primary
button will show up as `uneven-sibling-height` and is not a bug.

Equally, the audit is not exhaustive. It cannot see colour, contrast, typography,
crowding, or whether the screen makes sense. That is what your eyes are for.

## Native-specific findings worth naming

- **Keyboard dead ends.** A flow that cannot be completed without the mouse.
- **Missing standard shortcuts.** No ⌘N for new, ⌘W for close, ⌘, for settings.
- **Custom controls where the system has one.** A hand-rolled dropdown that does
  not behave like a real menu, a fake alert instead of a sheet.
- **Window amnesia.** Size and position not restored between launches.
- **Blocking the main thread.** The window stops redrawing during work — visible
  as a frozen screenshot or a spinning cursor. Check the app's log for the cause.
- **No empty state.** A list that is simply blank rather than explaining itself.
