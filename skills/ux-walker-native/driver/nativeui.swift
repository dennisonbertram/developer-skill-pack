// nativeui — drive and inspect a native macOS app the way agent-browser drives a web page.
//
// The accessibility tree is the native DOM: every control carries a role, a
// label, a value and a frame, which is exactly what a UX walk needs in order to
// find a control, press it, and measure whether the layout is straight.
//
// Build:  swiftc -O -o nativeui nativeui.swift -framework AppKit -framework ApplicationServices
//
// Every command needs Accessibility permission for the *calling* process (the
// terminal), granted once in System Settings › Privacy & Security › Accessibility.
// `nativeui doctor` reports whether that is in place.

import AppKit
import ApplicationServices
import Foundation

// MARK: - Output helpers

func emit(_ value: Any) {
    guard JSONSerialization.isValidJSONObject(value),
        let data = try? JSONSerialization.data(
            withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    else {
        print("{}")
        return
    }
    print(String(decoding: data, as: UTF8.self))
}

func fail(_ message: String, hint: String? = nil) -> Never {
    var payload: [String: Any] = ["ok": false, "error": message]
    if let hint { payload["hint"] = hint }
    emit(payload)
    exit(1)
}

// MARK: - Accessibility attribute reading

/// Reads one attribute, returning nil for the many "this element simply does
/// not have that attribute" cases rather than treating them as failures.
func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
    guard let raw = attribute(element, name) else { return nil }
    if let text = raw as? String {
        return text.isEmpty ? nil : text
    }
    // A value can be a number or a bool (checkboxes, sliders, steppers).
    if let number = raw as? NSNumber { return number.stringValue }
    return nil
}

func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool? {
    (attribute(element, name) as? NSNumber)?.boolValue
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] ?? []
}

func frame(_ element: AXUIElement) -> CGRect? {
    guard let positionValue = attribute(element, kAXPositionAttribute as String),
        let sizeValue = attribute(element, kAXSizeAttribute as String)
    else { return nil }
    var origin = CGPoint.zero
    var size = CGSize.zero
    // CFTypeRef -> AXValue is safe here: these two attributes are always AXValues.
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    else { return nil }
    return CGRect(origin: origin, size: size)
}

func actions(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
    return (names as? [String]) ?? []
}

// MARK: - App and window lookup

func runningApp(named name: String) -> NSRunningApplication {
    let wanted = name.lowercased()
    let matches = NSWorkspace.shared.runningApplications.filter { app in
        guard app.activationPolicy == .regular else { return false }
        let localized = (app.localizedName ?? "").lowercased()
        let bundle = (app.bundleIdentifier ?? "").lowercased()
        return localized == wanted || bundle == wanted || localized.contains(wanted)
    }
    guard let app = matches.first else {
        let available = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
            .sorted()
        fail(
            "no running app matches \(name.debugDescription)",
            hint: "running apps: \(available.joined(separator: ", "))")
    }
    return app
}

func requireTrust() {
    guard AXIsProcessTrusted() else {
        fail(
            "this process is not trusted for Accessibility, so no app can be inspected or driven",
            hint:
                "System Settings › Privacy & Security › Accessibility → enable the terminal app you run Claude Code in, then restart that terminal. Verify with `nativeui doctor`."
        )
    }
}

/// The app's focused window, falling back to its first window. A walk always
/// operates on one window; multi-window flows re-run snapshot after switching.
func mainWindow(of app: NSRunningApplication) -> AXUIElement {
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    if let focused = attribute(axApp, kAXFocusedWindowAttribute as String) {
        return focused as! AXUIElement
    }
    guard let windows = attribute(axApp, kAXWindowsAttribute as String) as? [AXUIElement],
        let first = windows.first
    else {
        fail(
            "\(app.localizedName ?? "app") has no accessible window",
            hint:
                "If the app is running, this usually means Accessibility permission is missing — run `nativeui doctor`."
        )
    }
    return first
}

// MARK: - Tree walking

struct Node {
    let element: AXUIElement
    let path: String
    let role: String
    let subrole: String?
    let label: String?
    let value: String?
    let help: String?
    let placeholder: String?
    let identifier: String?
    let rect: CGRect?
    let enabled: Bool?
    let focused: Bool?
    let actions: [String]
    let depth: Int

    /// Roles a user can actually act on. The full tree is mostly layout groups;
    /// listing only these keeps a snapshot readable, the same way
    /// `agent-browser snapshot -i` hides non-interactive nodes.
    static let interactiveRoles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton",
        "AXTextField", "AXTextArea", "AXSearchField", "AXSecureTextField",
        "AXSlider", "AXStepper", "AXComboBox", "AXLink", "AXTabGroup", "AXTab",
        "AXMenuItem", "AXDisclosureTriangle", "AXIncrementor", "AXSegmentedControl",
        "AXColorWell", "AXTable", "AXOutline", "AXRow", "AXCell", "AXToolbar",
        "AXSwitch", "AXToggle",
    ]

    var isInteractive: Bool {
        if Node.interactiveRoles.contains(role) { return true }
        // Anything that advertises a press-like action is actionable regardless
        // of how its role is reported — SwiftUI is inconsistent here.
        return actions.contains(kAXPressAction as String)
            || actions.contains("AXOpen") || actions.contains("AXPick")
    }

    /// The text a human would use to refer to this control.
    var displayLabel: String? {
        label ?? placeholder ?? help ?? value
    }
}

func describe(_ element: AXUIElement, path: String, depth: Int) -> Node {
    Node(
        element: element,
        path: path,
        role: stringAttribute(element, kAXRoleAttribute as String) ?? "AXUnknown",
        subrole: stringAttribute(element, kAXSubroleAttribute as String),
        label: stringAttribute(element, kAXTitleAttribute as String)
            ?? stringAttribute(element, kAXDescriptionAttribute as String),
        value: stringAttribute(element, kAXValueAttribute as String),
        help: stringAttribute(element, kAXHelpAttribute as String),
        placeholder: stringAttribute(element, kAXPlaceholderValueAttribute as String),
        identifier: stringAttribute(element, kAXIdentifierAttribute as String),
        rect: frame(element),
        enabled: boolAttribute(element, kAXEnabledAttribute as String),
        focused: boolAttribute(element, kAXFocusedAttribute as String),
        actions: actions(element),
        depth: depth
    )
}

/// Depth is capped because a deep SwiftUI hierarchy can nest far enough to make
/// a full walk slow without surfacing anything new.
func walk(_ element: AXUIElement, path: String = "", depth: Int = 0, maxDepth: Int = 40) -> [Node] {
    let node = describe(element, path: path.isEmpty ? "0" : path, depth: depth)
    var collected = [node]
    guard depth < maxDepth else { return collected }
    for (index, child) in children(element).enumerated() {
        let childPath = "\(node.path).\(index)"
        collected.append(contentsOf: walk(child, path: childPath, depth: depth + 1, maxDepth: maxDepth))
    }
    return collected
}

// MARK: - Ref cache
//
// Each invocation is a fresh process, so `snapshot` records ref → path and the
// action commands read it back. This is the same session-state trick a browser
// driver uses to let you say `click e3` instead of repeating a selector.

func cacheURL(for app: NSRunningApplication) -> URL {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/tmp/nativeui", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let safe = (app.localizedName ?? "app").replacingOccurrences(of: "/", with: "_")
    return dir.appending(path: "\(safe).json")
}

func writeCache(_ map: [String: String], for app: NSRunningApplication) {
    guard let data = try? JSONSerialization.data(withJSONObject: map) else { return }
    try? data.write(to: cacheURL(for: app))
}

func readCache(for app: NSRunningApplication) -> [String: String] {
    guard let data = try? Data(contentsOf: cacheURL(for: app)),
        let map = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return [:] }
    return map
}

func element(at path: String, from root: AXUIElement) -> AXUIElement? {
    // "0.3.1" — the leading component is the root itself.
    let parts = path.split(separator: ".").compactMap { Int($0) }
    guard !parts.isEmpty else { return nil }
    var current = root
    for index in parts.dropFirst() {
        let kids = children(current)
        guard index < kids.count else { return nil }
        current = kids[index]
    }
    return current
}

/// Resolves a target given either a ref from the last snapshot or a label.
/// Label matching is the more durable of the two: a ref goes stale the moment
/// the tree changes, and during a walk the tree changes constantly.
func resolveTarget(_ target: String, app: NSRunningApplication, window: AXUIElement) -> Node {
    let nodes = walk(window)

    if target.hasPrefix("e"), let path = readCache(for: app)[target] {
        if let found = nodes.first(where: { $0.path == path }) { return found }
        if let raw = element(at: path, from: window) {
            return describe(raw, path: path, depth: 0)
        }
    }
    if target.contains(".") , let found = nodes.first(where: { $0.path == target }) {
        return found
    }

    // Fall back to label matching: exact first, then a contains match.
    let wanted = target.lowercased()
    let labelled = nodes.filter { $0.isInteractive && $0.displayLabel != nil }
    if let exact = labelled.first(where: { $0.displayLabel?.lowercased() == wanted }) {
        return exact
    }
    if let partial = labelled.first(where: { $0.displayLabel?.lowercased().contains(wanted) == true })
    {
        return partial
    }

    let candidates = labelled.compactMap { $0.displayLabel }.prefix(25).joined(separator: " | ")
    fail(
        "no element matches \(target.debugDescription)",
        hint: "run `nativeui snapshot` again — refs go stale when the UI changes. visible labels: \(candidates)"
    )
}

func json(_ node: Node, ref: String?) -> [String: Any] {
    var out: [String: Any] = ["role": node.role, "path": node.path]
    if let ref { out["ref"] = ref }
    if let label = node.label { out["label"] = label }
    if let value = node.value { out["value"] = value }
    if let placeholder = node.placeholder { out["placeholder"] = placeholder }
    if let help = node.help { out["help"] = help }
    if let identifier = node.identifier { out["id"] = identifier }
    if let subrole = node.subrole { out["subrole"] = subrole }
    if let enabled = node.enabled { out["enabled"] = enabled }
    if let focused = node.focused, focused { out["focused"] = true }
    if let rect = node.rect {
        out["frame"] = [Int(rect.origin.x), Int(rect.origin.y), Int(rect.width), Int(rect.height)]
    }
    if !node.actions.isEmpty { out["actions"] = node.actions }
    return out
}

// MARK: - Window screenshots

func windowID(for app: NSRunningApplication) -> CGWindowID? {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for entry in list {
        guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid == app.processIdentifier,
            let number = entry[kCGWindowNumber as String] as? CGWindowID
        else { continue }
        // Skip the zero-size helper windows an app keeps around.
        if let bounds = entry[kCGWindowBounds as String] as? [String: Any],
            let height = bounds["Height"] as? Double, height < 80
        {
            continue
        }
        return number
    }
    return nil
}

@discardableResult
func shell(_ launchPath: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    try? process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

// MARK: - Keyboard

let keyCodes: [String: CGKeyCode] = [
    "return": 36, "enter": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53, "esc": 53,
    "left": 123, "right": 124, "down": 125, "up": 126,
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
    "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
]

/// "cmd+shift+n" → modifier flags plus a key code.
func sendKey(_ spec: String) {
    var flags: CGEventFlags = []
    var keyName = spec.lowercased()
    for part in spec.lowercased().split(separator: "+").map(String.init) {
        switch part {
        case "cmd", "command": flags.insert(.maskCommand)
        case "shift": flags.insert(.maskShift)
        case "opt", "option", "alt": flags.insert(.maskAlternate)
        case "ctrl", "control": flags.insert(.maskControl)
        default: keyName = part
        }
    }
    guard let code = keyCodes[keyName] else {
        fail("unknown key \(spec.debugDescription)", hint: "known: \(keyCodes.keys.sorted().joined(separator: ", "))")
    }
    let source = CGEventSource(stateID: .combinedSessionState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
    let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
    down?.flags = flags
    up?.flags = flags
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

// MARK: - Geometry audit
//
// The native counterpart of the DOM geometry audit: same questions (are
// siblings the same size, do edges line up, is spacing even, does anything
// spill out of its container) asked of accessibility frames instead of
// getBoundingClientRect.

struct Violation {
    let kind: String
    let detail: String
    let elements: [String]
}

func geometryAudit(window: AXUIElement) -> [Violation] {
    let nodes = walk(window)
    let windowRect = frame(window) ?? .zero
    var violations: [Violation] = []

    // 1. Anything drawn outside its window is clipped or spilling.
    for node in nodes.dropFirst() {
        guard let rect = node.rect, rect.width > 1, rect.height > 1 else { continue }
        if rect.maxX > windowRect.maxX + 2 || rect.minX < windowRect.minX - 2 {
            violations.append(
                Violation(
                    kind: "overflow-horizontal",
                    detail:
                        "\(node.role)\(node.displayLabel.map { " \($0.debugDescription)" } ?? "") extends past the window horizontally (element \(Int(rect.minX))–\(Int(rect.maxX)), window \(Int(windowRect.minX))–\(Int(windowRect.maxX)))",
                    elements: [node.path]))
        }
    }

    // 2. Sibling consistency. Group by parent and role: a row of buttons or a
    //    list of cards should share a size and sit on a common edge.
    var byParentRole: [String: [Node]] = [:]
    for node in nodes.dropFirst() {
        guard node.rect != nil else { continue }
        let parent = node.path.split(separator: ".").dropLast().joined(separator: ".")
        byParentRole["\(parent)|\(node.role)", default: []].append(node)
    }

    for (key, group) in byParentRole.sorted(by: { $0.key < $1.key }) {
        let sized = group.compactMap { node -> (Node, CGRect)? in
            guard let rect = node.rect, rect.width > 2, rect.height > 2 else { return nil }
            return (node, rect)
        }
        guard sized.count >= 3 else { continue }
        let role = key.split(separator: "|").last.map(String.init) ?? "?"

        let heights = sized.map { $0.1.height }
        if let minHeight = heights.min(), let maxHeight = heights.max(),
            minHeight > 0, maxHeight - minHeight > max(3, minHeight * 0.15)
        {
            violations.append(
                Violation(
                    kind: "uneven-sibling-height",
                    detail:
                        "\(sized.count) sibling \(role) elements vary in height from \(Int(minHeight))pt to \(Int(maxHeight))pt",
                    elements: sized.map { $0.0.path }))
        }

        // Stacked siblings should share a left edge; side-by-side ones a top edge.
        let verticallyStacked = Set(sized.map { Int($0.1.minY / 4) }).count == sized.count
        if verticallyStacked {
            let lefts = sized.map { $0.1.minX }
            if let minLeft = lefts.min(), let maxLeft = lefts.max(), maxLeft - minLeft > 2 {
                violations.append(
                    Violation(
                        kind: "left-edge-drift",
                        detail:
                            "\(sized.count) stacked \(role) elements start at x between \(Int(minLeft)) and \(Int(maxLeft)) instead of one left edge",
                        elements: sized.map { $0.0.path }))
            }

            // Uneven vertical rhythm between stacked siblings.
            let ordered = sized.sorted { $0.1.minY < $1.1.minY }
            var gaps: [CGFloat] = []
            for (a, b) in zip(ordered, ordered.dropFirst()) {
                gaps.append(b.1.minY - a.1.maxY)
            }
            if let minGap = gaps.min(), let maxGap = gaps.max(), gaps.count >= 2,
                maxGap - minGap > max(4, abs(minGap) * 0.5)
            {
                violations.append(
                    Violation(
                        kind: "uneven-gaps",
                        detail:
                            "gaps between \(sized.count) stacked \(role) elements range \(Int(minGap))pt–\(Int(maxGap))pt",
                        elements: ordered.map { $0.0.path }))
            }
        }
    }

    // 3. A control noticeably taller than its peers is usually a wrapped label.
    var byRole: [String: [(Node, CGRect)]] = [:]
    for node in nodes.dropFirst() where node.isInteractive {
        guard let rect = node.rect, rect.height > 2 else { continue }
        byRole[node.role, default: []].append((node, rect))
    }
    for (role, group) in byRole.sorted(by: { $0.key < $1.key }) where group.count >= 4 {
        let heights = group.map { $0.1.height }.sorted()
        let median = heights[heights.count / 2]
        for (node, rect) in group where rect.height > median * 1.7 && median > 0 {
            violations.append(
                Violation(
                    kind: "possible-wrapped-control",
                    detail:
                        "\(role)\(node.displayLabel.map { " \($0.debugDescription)" } ?? "") is \(Int(rect.height))pt tall against a median of \(Int(median))pt for its peers — its label may be wrapping",
                    elements: [node.path]))
        }
    }

    return violations
}

// MARK: - Argument parsing

var arguments = Array(CommandLine.arguments.dropFirst())

func takeOption(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: "--\(name)"), index + 1 < arguments.count else {
        return nil
    }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...(index + 1))
    return value
}

func takeFlag(_ name: String) -> Bool {
    guard let index = arguments.firstIndex(of: "--\(name)") else { return false }
    arguments.remove(at: index)
    return true
}

let appName = takeOption("app")
let wantAll = takeFlag("all")

guard let command = arguments.first else {
    print(
        """
        nativeui — inspect and drive a native macOS app for UX walking

          doctor                          check Accessibility permission
          apps                            list running apps that have windows
          snapshot --app <name> [--all]   interactive elements (or the whole tree)
          click <ref|label> --app <name>  press a control
          type <ref|label> <text> --app <name>
          key <spec> --app <name>         e.g. return, cmd+n, escape
          screenshot <path> --app <name>  capture just that app's window
          geometry --app <name>           layout audit over element frames
          resize <w> <h> --app <name>     resize the window
          window --app <name>             window title, frame, screen size
          focus --app <name>              bring the app forward

        Every command except doctor/apps needs Accessibility permission.
        """)
    exit(0)
}
arguments.removeFirst()

func requireApp() -> NSRunningApplication {
    guard let appName else {
        fail("this command needs --app <name>", hint: "list candidates with `nativeui apps`")
    }
    return runningApp(named: appName)
}

// MARK: - Commands

switch command {
case "doctor":
    // `--prompt` asks macOS to show the "open System Settings" dialog. The
    // grant applies to the terminal that owns this process, not to the binary,
    // which is why the terminal must be restarted afterwards.
    if takeFlag("prompt") {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    let trusted = AXIsProcessTrusted()
    emit([
        "ok": trusted,
        "accessibility_trusted": trusted,
        "process": ProcessInfo.processInfo.processName,
        "hint": trusted
            ? "ready — snapshot and drive any running app"
            : "System Settings › Privacy & Security › Accessibility → enable your terminal, then restart it. Screenshots work without this; nothing else does.",
    ])

case "apps":
    let apps = NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }
        .compactMap { app -> [String: Any]? in
            guard let name = app.localizedName else { return nil }
            return [
                "name": name,
                "bundle": app.bundleIdentifier ?? "",
                "pid": Int(app.processIdentifier),
                "active": app.isActive,
            ]
        }
        .sorted { ($0["name"] as! String) < ($1["name"] as! String) }
    emit(["ok": true, "apps": apps])

case "snapshot":
    requireTrust()
    let app = requireApp()
    let window = mainWindow(of: app)
    let nodes = walk(window)
    var refMap: [String: String] = [:]
    var listed: [[String: Any]] = []
    var counter = 0
    for node in nodes {
        let keep = wantAll || node.isInteractive || (node.role == "AXStaticText" && node.value != nil)
        guard keep else { continue }
        counter += 1
        let ref = "e\(counter)"
        refMap[ref] = node.path
        listed.append(json(node, ref: ref))
    }
    writeCache(refMap, for: app)
    let rect = frame(window)
    emit([
        "ok": true,
        "app": app.localizedName ?? "",
        "window": stringAttribute(window, kAXTitleAttribute as String) ?? "",
        "frame": rect.map { [Int($0.origin.x), Int($0.origin.y), Int($0.width), Int($0.height)] }
            ?? [],
        "count": listed.count,
        "elements": listed,
    ])

case "click":
    requireTrust()
    let app = requireApp()
    guard let target = arguments.first else { fail("usage: nativeui click <ref|label> --app <name>") }
    let window = mainWindow(of: app)
    let node = resolveTarget(target, app: app, window: window)

    if node.actions.contains(kAXPressAction as String) {
        let status = AXUIElementPerformAction(node.element, kAXPressAction as CFString)
        guard status == .success else {
            fail("press failed on \(target) with AXError \(status.rawValue)")
        }
    } else if let rect = node.rect {
        // No press action: click the middle of its frame. Screen coordinates
        // from AX are already top-left origin, which is what CGEvent wants.
        let point = CGPoint(x: rect.midX, y: rect.midY)
        let source = CGEventSource(stateID: .combinedSessionState)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    } else {
        fail("\(node.role) has neither a press action nor a frame to click")
    }
    emit(["ok": true, "clicked": json(node, ref: target)])

case "type":
    requireTrust()
    let app = requireApp()
    guard arguments.count >= 2 else {
        fail("usage: nativeui type <ref|label> <text> --app <name>")
    }
    let target = arguments[0]
    let text = arguments.dropFirst().joined(separator: " ")
    let window = mainWindow(of: app)
    let node = resolveTarget(target, app: app, window: window)

    // Setting the value directly is more reliable than synthesising keystrokes,
    // but some fields only accept typed input, so fall back to that.
    let status = AXUIElementSetAttributeValue(
        node.element, kAXValueAttribute as CFString, text as CFTypeRef)
    if status != .success {
        AXUIElementSetAttributeValue(node.element, kAXFocusedAttribute as CFString, true as CFTypeRef)
        usleep(120_000)
        let source = CGEventSource(stateID: .combinedSessionState)
        for scalar in Array(text.utf16) {
            var unit = scalar
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
            up?.post(tap: .cghidEventTap)
        }
    }
    emit(["ok": true, "typed": text, "into": json(node, ref: target)])

case "key":
    requireTrust()
    let app = requireApp()
    guard let spec = arguments.first else { fail("usage: nativeui key <spec> --app <name>") }
    app.activate()
    usleep(150_000)
    sendKey(spec)
    emit(["ok": true, "key": spec])

case "screenshot":
    let app = requireApp()
    guard let path = arguments.first else {
        fail("usage: nativeui screenshot <path> --app <name>")
    }
    guard let id = windowID(for: app) else {
        fail(
            "could not find an on-screen window for \(app.localizedName ?? "app")",
            hint: "the window may be minimised or on another Space")
    }
    // -o drops the drop shadow, -x silences the shutter sound.
    let status = shell("/usr/sbin/screencapture", ["-l", String(id), "-o", "-x", path])
    guard status == 0, FileManager.default.fileExists(atPath: path) else {
        fail("screencapture failed with status \(status)", hint: "check Screen Recording permission")
    }
    emit(["ok": true, "path": path, "window_id": Int(id)])

case "geometry":
    requireTrust()
    let app = requireApp()
    let window = mainWindow(of: app)
    let violations = geometryAudit(window: window)
    emit([
        "ok": true,
        "violations": violations.map {
            ["kind": $0.kind, "detail": $0.detail, "elements": $0.elements]
        },
        "clean": violations.isEmpty,
    ])

case "resize":
    requireTrust()
    let app = requireApp()
    guard arguments.count >= 2, let width = Double(arguments[0]), let height = Double(arguments[1])
    else { fail("usage: nativeui resize <width> <height> --app <name>") }
    let window = mainWindow(of: app)
    var size = CGSize(width: width, height: height)
    guard let value = AXValueCreate(.cgSize, &size) else { fail("could not build a size value") }
    let status = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    guard status == .success else {
        fail("resize failed with AXError \(status.rawValue)", hint: "the window may not be resizable")
    }
    emit(["ok": true, "size": [Int(width), Int(height)]])

case "window":
    requireTrust()
    let app = requireApp()
    let window = mainWindow(of: app)
    let rect = frame(window)
    emit([
        "ok": true,
        "app": app.localizedName ?? "",
        "title": stringAttribute(window, kAXTitleAttribute as String) ?? "",
        "frame": rect.map { [Int($0.origin.x), Int($0.origin.y), Int($0.width), Int($0.height)] }
            ?? [],
        "screen": NSScreen.main.map { [Int($0.frame.width), Int($0.frame.height)] } ?? [],
    ])

case "focus":
    let app = requireApp()
    app.activate()
    emit(["ok": true, "focused": app.localizedName ?? ""])

default:
    fail("unknown command \(command.debugDescription)", hint: "run `nativeui` with no arguments for usage")
}
