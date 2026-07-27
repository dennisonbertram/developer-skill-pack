---
name: ux-paths-native
description: "Generate exhaustive user journey stories for a native macOS/iOS app by analyzing its codebase. Produces short feature exercises and long end-to-end flows written in terms of windows, panes, menus, sheets and keyboard shortcuts, ready for /ux-walker-native. Use when asked to 'map the native app', 'create stories for the mac app', 'generate ux paths for the desktop app', or 'run ux-paths-native'. For web apps use ux-paths instead."
version: 0.1.0
user_invocable: true
---

# UX Paths (native macOS/iOS)

Generate a catalog of realistic user journeys through a native app by reading its
code. Output feeds `/ux-walker-native`.

This is the sibling of `/ux-paths`. The method is the same — discovery agent,
story swarm, consolidation — and the **process, output format, and story schema
are inherited unchanged**. Read `../ux-paths/SKILL.md` and follow
it, applying the substitutions below.

Do not duplicate that skill's phases here. This file only records what changes
for a native target.

---

## What changes

### Discovery: where the app's surface actually lives

A web discovery agent looks for routes. A native app has no router. Look for:

| Web concept | Look for in a native app |
|---|---|
| Routes / pages | `WindowGroup`, `Settings`, `NavigationStack`, `NavigationSplitView`, `.sheet`, `.popover`, `.alert`, `TabView`, Storyboard scenes, `NSViewController` subclasses |
| Nav bar / sidebar | `List` in a sidebar column, `NavigationLink`, `Sidebar` toolbar items, `TabView` |
| Buttons and forms | `Button`, `TextField`, `Toggle`, `Picker`, `Stepper`, `Slider`, `Form`, `@FocusState` |
| Client-side state | `@State`, `@Observable`, `@AppStorage`, `@SceneStorage`, `UserDefaults`, `NSUbiquitousKeyValueStore` |
| API layer | `URLSession` clients, XPC services, a bundled local server, CLI subprocesses the app spawns |
| Auth | Keychain access, `ASWebAuthenticationSession`, OAuth token stores, subscription receipts |
| Feature flags | Build configuration, `#if DEBUG`, launch arguments, environment variables the app reads |

**Also enumerate — these have no web equivalent and are where native apps fail:**

- **Menu bar commands.** Every `CommandGroup`, `CommandMenu`, and `.keyboardShortcut`.
  Each menu item is a user-reachable capability and belongs in the story catalog.
- **Keyboard shortcuts.** Collect the full list. "Complete this flow using only
  the keyboard" is a story the web catalog never has to write.
- **Window management.** Multiple windows, tabs, full screen, restoring size and
  position, what happens when the last window closes.
- **Launch and first run.** Cold launch, no saved state, permission prompts,
  onboarding.
- **Permissions.** Anything triggering a system prompt — files, network, camera,
  accessibility, notifications. Each needs a granted story and a denied story.
- **System integration.** Drag and drop, share sheet, services menu, URL scheme
  handling, dock menu, notifications, background activity.
- **Offline and sleep.** What the app does with no network, and after the
  machine wakes.
- **Appearance.** Light and dark mode, accent colour, Increase Contrast,
  Reduce Motion, and larger text sizes.

### Story wording

Write steps in native vocabulary. Not "navigate to /settings" but "open Settings
from the gear in the sidebar, or press ⌘,". A step must name something a walker
can find in the accessibility tree — a visible label, a menu item, or a
shortcut.

Each story should carry, in addition to the inherited fields:

- **Entry** — how the user gets here: launch, a menu item, a shortcut, a click path
- **Keyboard path** — the same journey without a mouse, or "not possible" if it isn't
- **Window state** — which window or sheet the story happens in

The **Ideal path** field matters more here than on the web: a desktop app that
takes six clicks for something the menu bar could do in one keystroke is exactly
the friction `/ux-flow-native` is looking for.

### Topics for the swarm

Use the inherited topic list, plus these native-only ones:

- Menu bar and keyboard-only operation
- First launch and permission prompts
- Window and multi-window behaviour
- Appearance and accessibility settings (dark mode, contrast, larger text)
- System integration (drag and drop, share, notifications, URL schemes)
- Offline, sleep, and long-running background work

### What to leave out

Skip topics that do not exist here rather than inventing native analogues:

- Responsive breakpoints — a Mac window resizes continuously. Replace with a
  "works in a small window" story.
- Browser back/forward, deep links to arbitrary state, SEO, page load
  performance.
- Multi-tab and multi-session-in-one-app stories, unless the app really has
  document windows or tabs.

---

## Output

Identical structure to `/ux-paths`: `docs/ux-paths/discovery.md`,
per-topic files, and `docs/ux-paths/catalog.md`.

Add to `discovery.md` a **Platform Surface** section listing the menu bar
commands, the keyboard shortcuts, the permissions the app requests, and the
window model. `/ux-walker-native` reads this to audit shortcut correctness and
keyboard reachability.
