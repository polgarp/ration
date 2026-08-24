import AppKit

// The tap writes here; CLAUDE_USAGE_SNAPSHOT overrides it, which is how the
// state fixtures get driven during development.
let snapshotPath = ProcessInfo.processInfo.environment["CLAUDE_USAGE_SNAPSHOT"]
    ?? NSString(string: "~/.claude/usage-snapshot.json").expandingTildeInPath
let snapshotURL = URL(fileURLWithPath: snapshotPath)

// `--dump` prints what the dropdown would say and exits, so states can be
// inspected and diffed without opening a menu by hand.
if CommandLine.arguments.contains("--dump") {
    let snapshot = Snapshot.load(from: snapshotURL)
    print("bar: \(MenuModel.barTitle(snapshot))")
    for row in MenuModel.rows(snapshot, now: Date(), staleAfter: 90) {
        switch row {
        case .heading(let s):  print("  \(s.uppercased())")
        case .detail(let s):   print("     \(s)")
        case .note(let s):     print("  \(s)")
        case .separator:       print("  ──────────")
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
