# Action patterns — translating story steps into driver commands

A story step is written for a human ("open settings and turn on plan mode").
This is how each kind of step becomes driver commands.

## The loop that never changes

```bash
nativeui snapshot --app {APP}      # 1. see what is on screen
# 2. find the target by its label in the JSON
nativeui click "Settings" --app {APP}
nativeui screenshot step-3.png --app {APP}   # 3. capture
# 4. READ the screenshot
```

Snapshot before every action. A native UI mutates its tree constantly — sheets,
popovers, list reloads — and a ref from three actions ago points at nothing.

## Target by label, not by ref

```bash
nativeui click "Plan mode" --app GoCode     # durable
nativeui click e17 --app GoCode             # breaks on the next redraw
```

Labels come from `label`, `placeholder`, `help`, then `value`, in that order.
Matching is case-insensitive, exact first then substring. Use a ref only when a
label is genuinely absent — and note that absence as an `a11y` finding.

## Buttons and links

```bash
nativeui click "New" --app {APP}
```

The driver prefers the element's own press action and falls back to clicking the
centre of its frame. If a click does nothing, check `actions` in the snapshot: an
element with no `AXPress` and a zero-size frame is not really a button.

## Text fields

```bash
nativeui type "Ask the harness to do something…" "list the files" --app {APP}
nativeui key return --app {APP}
```

Target a field by its placeholder — that is usually the only label a SwiftUI
`TextField` exposes. The driver sets the value directly when it can and types
character by character when it cannot.

Submitting is usually a separate `key return`. If the story says "press send",
prefer clicking the actual send control so the button itself gets exercised.

## Menus and pickers

```bash
nativeui click "Server default" --app {APP}   # opens the picker
nativeui snapshot --app {APP}                 # menu items are now in the tree
nativeui click "gpt-5.6-sol" --app {APP}
```

A popup's items only exist in the tree while it is open, so the snapshot between
the two clicks is required, not optional.

## Menu bar

The menu bar is not in the app window's tree. Drive it with shortcuts:

```bash
nativeui key cmd+n --app {APP}
nativeui key cmd+comma --app {APP}   # if you add comma to the key map
```

To audit the menus themselves, use the app's own menu structure via
`snapshot --all` on the menu bar element, or check that every shortcut the app
advertises actually works — that is the finding that matters.

## Toggles and checkboxes

```bash
nativeui snapshot --app {APP}       # read `value` — "1"/"0" or true/false
nativeui click "Plan mode" --app {APP}
nativeui snapshot --app {APP}       # confirm `value` flipped
```

Always confirm the state changed. A toggle that looks pressed but did not change
its value is a real bug and only the tree reveals it.

## Sheets, dialogs and alerts

A sheet becomes part of the window's tree when it opens. Snapshot to see its
buttons. To dismiss:

```bash
nativeui key escape --app {APP}
```

Be careful with destructive confirmations — same rule as the web walker: do not
confirm a deletion unless the story explicitly calls for it.

## Waiting

There is no network-idle signal. Poll:

```bash
for i in $(seq 1 30); do
  if nativeui snapshot --app {APP} | grep -q "Done"; then break; fi
  sleep 1
done
```

Record how long it took. An action that takes seconds with no spinner, no
disabled control and no status text is a `feedback` finding regardless of
whether it eventually worked.

## Scrolling

There is no scroll command. Options, in order of preference:

1. Resize the window larger so the content fits, audit, then restore.
2. Click an element near the bottom edge to bring focus there, then `key down`.
3. Note in the report that a region could not be reached.

Content only reachable by scrolling in a window that had room to show it is a
layout finding.

## Multiple windows

`snapshot` targets the focused window. After an action that opens a window:

```bash
nativeui focus --app {APP}
nativeui window --app {APP}     # confirm the title changed
nativeui snapshot --app {APP}
```

## What not to do

- Do not `sleep 5` between every step. Poll for the element instead; blind sleeps
  hide slowness that should be a finding.
- Do not drive two stories against one app at once. One keyboard, one cursor.
- Do not leave the window resized at the end of a story.
- Do not relaunch the app to "reset" unless the story says to — you will lose
  the state later stories depend on.
