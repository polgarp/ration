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
    let now = Date()
    switch MenuModel.bar(snapshot, now: now) {
    case .none:                  print("bar: —")
    case .weekRemaining(let p):  print("bar: \(Int(p))%")
    case .backIn(let s):         print("bar: \(Format.duration(s))")
    }
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
