import AppKit

/// The menu bar item and its dropdown.
///
/// Deliberately thin: what the item *says* lives in `MenuModel`, which has no
/// AppKit and is covered by tests. This file only turns rows into views.
final class MenuBarController: NSObject {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let snapshotURL: URL
    private var store = SnapshotStore()
    private var snapshot: Snapshot? { store.best }
    private var lastModified: Date?
    private var timer: Timer?
    /// What the dropdown currently says, so it is only rebuilt when it would
    /// say something different.
    private var shownRows: [MenuRow]?
    private var shownSetup: Installer.State?
    private var shownLogin: LoginItem.State?
    private var isMenuOpen = false
    private let formatting = Formatting()
    private let service = ServiceMonitor()

    /// Older than this means Claude Code is not running. The tap fires on a 10s
    /// refreshInterval, so this tolerates several missed beats.
    private let staleAfter: TimeInterval = 90

    /// A countdown has to tick every second; nothing else here changes faster
    /// than the tap writes. Waking once a second forever is a battery cost an
    /// always-running menu bar app has no reason to pay.
    private let idleTick: TimeInterval = 5
    private let countdownTick: TimeInterval = 1
    private var currentTick: TimeInterval = 0

    init(snapshotURL: URL) {
        self.snapshotURL = snapshotURL
        super.init()

        reload()
        render()

        service.onUpdate = { [weak self] in self?.render() }
        service.start()

        // One timer does both jobs. A DispatchSource vnode watch is the obvious
        // choice, but the tap replaces the file by atomic rename, so the watched
        // descriptor would point at a dead inode after every write and need
        // re-arming. Countdowns must re-render every second anyway, and
        // comparing an mtime is one stat() — cheaper than being clever.
        schedule(every: idleTick)
    }

    private func schedule(every interval: TimeInterval) {
        guard interval != currentTick else { return }
        timer?.invalidate()
        currentTick = interval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.reload()
            self?.render()
        }
        // .common so the timer keeps firing while a menu is tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Re-reads the snapshot only when the file has actually changed.
    private func reload() {
        let modified = FileFreshness.modificationDate(of: snapshotURL)
        guard modified != lastModified else { return }
        lastModified = modified
        guard let incoming = Snapshot.load(from: snapshotURL) else {
            // The file is gone — uninstalled, or deleted by hand. Holding the
            // last reading would leave a percentage on screen that nothing is
            // updating any more.
            store = SnapshotStore()
            return
        }
        // Every session writes this file, and an idle one rebroadcasts expired
        // windows. The store keeps the newest reading, not the last-written.
        store.accept(incoming)
    }

    // MARK: - Rendering

    private func render() {
        let now = Date()
        let stale = MenuModel.isStale(snapshot, now: now, staleAfter: staleAfter)

        let content = MenuModel.bar(snapshot, now: now)
        renderBar(content, stale: stale)
        renderMenu(now: now)
        // Only a live countdown needs second-by-second wake-ups.
        schedule(every: content.backIn == nil ? idleTick : countdownTick)
    }

    /// Rebuilt only when it would read differently, and never while open:
    /// assigning `statusItem.menu` dismisses a menu AppKit is tracking.
    private func renderMenu(now: Date) {
        guard !isMenuOpen else { return }
        let setup = Setup.currentState()
        let login = LoginItem.state
        let rows = MenuModel.rows(snapshot, now: now, staleAfter: staleAfter, formatting: formatting,
                                  service: service.status, isInstalled: setup == .wrapped)
        guard rows != shownRows || setup != shownSetup || login != shownLogin
                || statusItem.menu == nil else { return }
        shownLogin = login
        shownRows = rows
        shownSetup = setup

        let menu = NSMenu()
        menu.delegate = self
        // AppKit greys actionless items unless auto-enabling is off, and most
        // rows here are text.
        menu.autoenablesItems = false
        for row in rows {
            menu.addItem(view(for: row))
        }
        // The only actionable items in the dropdown, kept at the bottom so the
        // reading is never competing with a control.
        switch setup {
        case .wrapped:
            menu.addItem(action("Undo Setup…", #selector(confirmUninstall)))
        case .notConfigured, .unwrapped:
            menu.addItem(action("Set up Ration…", #selector(confirmInstall)))
        case .unreadable:
            menu.addItem(action("settings.json needs fixing…", #selector(explainUnreadable)))
        }
        let loginItem = action("Open at Login", #selector(toggleLoginItem))
        // A tick when it is on, a dash when macOS is still waiting for the user
        // to confirm it in System Settings.
        switch login {
        case .on:            loginItem.state = .on
        case .needsApproval: loginItem.state = .mixed
        case .off:           loginItem.state = .off
        }
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit Ration",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func renderBar(_ content: BarContent, stale: Bool) {
        guard let button = statusItem.button else { return }
        let now = Date()

        // The mark is always drawn from the week, so the glyph and the number
        // can never make competing claims about different windows.
        if let used = MenuModel.markUsage(snapshot, now: now) {
            let overPace = snapshot?.sevenDay
                .map { Metrics.weeklyPace($0, now: now).isOverPace } ?? false
            button.image = Mark.image(style: Mark.Style.fromEnvironment(),
                                      used: used, overPace: overPace)
        } else {
            button.image = nil
        }
        button.imagePosition = .imageLeading

        let content = MenuModel.bar(snapshot, now: now)

        // No explicit foreground colour. macOS dims a status item's template
        // image when the menu bar goes inactive; text pinned to .labelColor
        // does not follow, so the glyph and the number drifted apart. Leaving
        // the colour to the button keeps them in step.
        button.attributedTitle = NSAttributedString(
            string: MenuModel.barText(content),
            // Monospaced digits so the item doesn't jitter as it counts down.
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)])

        // Staleness dims image and text together. Not a pending countdown
        // though: it derives from an absolute `resets_at`, so it stays exact —
        // and being locked out is exactly when the snapshot goes stale.
        button.appearsDisabled = stale && content.backIn == nil
    }

    // MARK: - Rows

    private func view(for row: MenuRow) -> NSMenuItem {
        switch row {
        case .separator:
            return .separator()

        case .headline(let text):
            return item(NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]))

        case .status(let text, let level):
            // Semantic colour on the dot only; the text stays in the menu's own
            // ink so a healthy row reads as quiet rather than decorated.
            let dot = NSMutableAttributedString(string: "● ", attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: colour(for: level)
            ])
            dot.append(NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
            let statusItem = item(dot, spoken: MenuModel.spokenRow(row) + ", opens the status page")
            statusItem.action = #selector(openStatusPage)
            statusItem.target = self
            return statusItem

        case .note(let text):
            return item(NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))

        case .stat(let label, let value):
            // A tab stop keeps the value column aligned whether or not the row
            // carries a label, so continuation lines sit under their value.
            let style = NSMutableParagraphStyle()
            style.tabStops = [NSTextTab(textAlignment: .left, location: 68)]
            let s = NSMutableAttributedString(string: "\(label)\t\(value)", attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ])
            s.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor,
                           range: NSRange(location: 0, length: label.utf16.count))
            return item(s, spoken: MenuModel.spokenRow(row))
        }
    }

    // MARK: - Setup

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func confirmInstall() {
        let state = Setup.currentState()
        let alert = NSAlert()
        alert.messageText = "Set up Ration"
        // Show the exact strings that will be written. Nothing is changed
        // without the user reading precisely what changes.
        alert.informativeText = Installer.preview(for: state, tap: Setup.resolvedTapCommand)
            + "\n\nYour settings.json is backed up first."
        alert.addButton(withTitle: "Set up")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try Setup.install()
            report("Ration is set up.",
                   "Usage will appear within a few seconds. Existing Claude Code sessions "
                 + "pick up the change on their next status line refresh.")
        } catch {
            report("Nothing was changed.", error.localizedDescription, style: .warning)
        }
    }

    @objc private func confirmUninstall() {
        let alert = NSAlert()
        alert.messageText = "Undo Ration's setup?"
        alert.informativeText = "Ration stops reading Claude Code's status line. Your own "
            + "status line command is restored exactly as it was, and the saved usage data "
            + "is deleted. Ration keeps running, with nothing to show, until you set it up again."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try Setup.uninstall()
            report("Removed.", "Your status line is back to what it was.")
        } catch {
            report("Nothing was changed.", error.localizedDescription, style: .warning)
        }
    }

    @objc private func toggleLoginItem() {
        let wasOn = LoginItem.state == .on
        do {
            try LoginItem.setEnabled(!wasOn)
        } catch let error as NSError {
            // Report what macOS actually said. Guessing at a cause produces an
            // explanation that is confidently wrong.
            report("Could not change the login item.",
                   "\(error.localizedDescription)\n\n(\(error.domain) \(error.code))",
                   style: .warning)
        }
        shownLogin = nil   // force the tick to redraw
        renderMenu(now: Date())

        if LoginItem.state == .needsApproval {
            report("Almost there.",
                   "macOS needs you to confirm this in System Settings → General → "
                 + "Login Items, under \"Open at Login\".")
        }
    }

    @objc private func openStatusPage() {
        NSWorkspace.shared.open(ServiceMonitor.statusPage)
    }

    @objc private func explainUnreadable() {
        report("settings.json could not be parsed",
               "Ration will not modify a settings file it cannot read, because a wrong guess "
             + "would break Claude Code. Fix ~/.claude/settings.json by hand, then try again.",
               style: .warning)
    }

    private func report(_ title: String, _ detail: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func colour(for level: ServiceStatus.Level) -> NSColor {
        switch level {
        case .operational:            return .systemGreen
        case .degraded, .maintenance: return .systemOrange
        case .outage:                 return .systemRed
        case .unknown:                return .secondaryLabelColor
        }
    }

    private func item(_ title: NSAttributedString, spoken: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title.string, action: nil, keyEquivalent: "")
        item.attributedTitle = title
        // The tab stop that aligns the value column reads as a gap, and the
        // dot on a status row carries no meaning aloud.
        if let spoken, !spoken.isEmpty { item.setAccessibilityLabel(spoken) }
        return item
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true }
    func menuDidClose(_ menu: NSMenu) { isMenuOpen = false }
}
