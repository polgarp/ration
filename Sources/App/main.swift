import AppKit

// The tap writes here; CLAUDE_USAGE_SNAPSHOT overrides it, which is how the
// state fixtures get driven during development.
let snapshotPath = ProcessInfo.processInfo.environment["CLAUDE_USAGE_SNAPSHOT"]
    ?? NSString(string: "~/.claude/usage-snapshot.json").expandingTildeInPath
let snapshotURL = URL(fileURLWithPath: snapshotPath)

// `--dump` prints what the dropdown would say and exits, so states can be
// inspected and diffed without opening a menu by hand.
if CommandLine.arguments.contains("--dump") {
    // Every Claude Code session writes this file on its own 10s timer, and an
    // idle one rebroadcasts expired windows — so a single read has a real
    // chance of catching a stale write. Sampling across one refresh interval
    // lets the store settle on the newest reading, the same way the running
    // app does continuously.
    var store = SnapshotStore()
    var lastModified: Date?
    for _ in 0..<55 {
        let modified = FileFreshness.modificationDate(of: snapshotURL)
        if modified != lastModified {
            lastModified = modified
            if let s = Snapshot.load(from: snapshotURL) { store.accept(s) }
        }
        Thread.sleep(forTimeInterval: 0.2)
    }
    let snapshot = store.best
    let now = Date()
    print("bar: \(MenuModel.barText(MenuModel.bar(snapshot, now: now)))")
    for row in MenuModel.rows(snapshot, now: now, staleAfter: 90) {
        switch row {
        case .headline(let s):    print("  \(s)")
        case .stat(let l, let v): print("  \(l.padding(toLength: max(8, l.count), withPad: " ", startingAt: 0)) \(v)")
        case .note(let s):        print("  \(s)")
        case .separator:          print("  ──────────")
        }
    }
    exit(0)
}

let app = NSApplication.shared
// .accessory keeps Ration out of the Dock and the app switcher. LSUIElement in
// Info.plist does the same; set here too so a bare binary behaves.
app.setActivationPolicy(.accessory)

// Held in a global so ARC doesn't collect the status item out of the menu bar.
let controller = MenuBarController(snapshotURL: snapshotURL)

app.run()
