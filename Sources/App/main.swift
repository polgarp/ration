import AppKit

// The tap writes here; CLAUDE_USAGE_SNAPSHOT overrides it, which is how the
// state fixtures get driven during development. Falling back to Setup's path
// rather than a second hardcoded one keeps the app watching the same file the
// installer writes and uninstall deletes, RATION_CLAUDE_DIR included.
let snapshotPath = ProcessInfo.processInfo.environment["CLAUDE_USAGE_SNAPSHOT"]
    ?? Setup.snapshotURL.path
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

    // The monitor is async and belongs to the running app; the debug path just
    // asks once, synchronously, so the dump shows what the menu would.
    var service: ServiceStatus?
    if let data = try? Data(contentsOf: URL(string: "https://status.claude.com/api/v2/summary.json")!) {
        service = ServiceStatus.decode(data)
    }
    let now = Date()
    print("bar: \(MenuModel.barText(MenuModel.bar(snapshot, now: now)))")
    for row in MenuModel.rows(snapshot, now: now, staleAfter: 90, service: service) {
        switch row {
        case .headline(let s):    print("  \(s)")
        case .stat(let l, let v): print("  \(l.padding(toLength: max(8, l.count), withPad: " ", startingAt: 0)) \(v)")
        case .note(let s):        print("  \(s)")
        case .status(let s, let l): print("  ● \(s) [\(l)]")
        case .separator:          print("  ──────────")
        }
    }
    exit(0)
}

// Scriptable equivalents of the menu items, and how the installer is tested.
if CommandLine.arguments.contains("--status") {
    switch Setup.currentState() {
    case .notConfigured:      print("not configured")
    case .wrapped:            print("wrapped")
    case .unwrapped(let c):   print("unwrapped: \(c)")
    case .unreadable:         print("unreadable")
    }
    exit(0)
}
if CommandLine.arguments.contains("--install") {
    do { try Setup.install(); print("installed"); exit(0) }
    catch { FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8)); exit(1) }
}
if CommandLine.arguments.contains("--uninstall") {
    do { try Setup.uninstall(); print("uninstalled"); exit(0) }
    catch { FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8)); exit(1) }
}

let app = NSApplication.shared
// .accessory keeps Ration out of the Dock and the app switcher. LSUIElement in
// Info.plist does the same; set here too so a bare binary behaves.
app.setActivationPolicy(.accessory)

// Held in a global so ARC doesn't collect the status item out of the menu bar.
let controller = MenuBarController(snapshotURL: snapshotURL)

app.run()
