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

    /// Older than this means Claude Code is not running. The tap fires on a 10s
    /// refreshInterval, so this tolerates several missed beats.
    private let staleAfter: TimeInterval = 90

    init(snapshotURL: URL) {
        self.snapshotURL = snapshotURL
        super.init()

        reload()
        render()

        // One timer does both jobs. A DispatchSource vnode watch is the obvious
        // choice, but the tap replaces the file by atomic rename, so the watched
        // descriptor would point at a dead inode after every write and need
        // re-arming. Countdowns must re-render every second anyway, and
        // comparing an mtime is one stat() — cheaper than being clever.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.reload()
            self?.render()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Re-reads the snapshot only when the file has actually changed.
    private func reload() {
        let modified = (try? snapshotURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        guard modified != lastModified else { return }
        lastModified = modified
        // Every Claude Code session writes this same file, and an idle one
        // rebroadcasts expired windows. The store keeps whichever reading is
        // actually newest rather than whichever landed last.
        if let incoming = Snapshot.load(from: snapshotURL) { store.accept(incoming) }
    }

    // MARK: - Rendering

    private func render() {
        let now = Date()
        let stale = MenuModel.isStale(snapshot, now: now, staleAfter: staleAfter)

        renderBar(now: now, stale: stale)

        let menu = NSMenu()
        for row in MenuModel.rows(snapshot, now: now, staleAfter: staleAfter) {
            menu.addItem(view(for: row))
        }
        menu.addItem(NSMenuItem(title: "Quit Ration",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func renderBar(now: Date, stale: Bool) {
        guard let button = statusItem.button else { return }

        // The mark is always drawn from the week, so the glyph and the number
        // can never make competing claims about different windows.
        if let used = MenuModel.markUsage(snapshot, now: now) {
            let overPace = snapshot?.sevenDay
                .map { Metrics.weeklyPace($0, now: now).delta > 1 } ?? false
            button.image = Mark.image(style: Mark.Style.fromEnvironment(),
                                      used: used, overPace: overPace)
        } else {
            button.image = nil
        }
        button.imagePosition = .imageLeading

        let content = MenuModel.bar(snapshot, now: now)
        let text = MenuModel.barText(content)

        let title = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: NSColor.labelColor,
            // Monospaced digits so the item doesn't jitter as it counts down.
            .font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)
        ])

        // Staleness does not rot everything equally. A percentage from an hour
        // ago is genuinely unknown, so it dims. `resets_at` is an absolute
        // timestamp, so a countdown derived from it stays exact however old the
        // snapshot is — and being locked out is precisely when Claude Code is
        // closed and the snapshot goes stale. Dimming the one number still
        // worth trusting would be exactly backwards.
        if stale {
            title.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                               range: NSRange(location: 0, length: title.length))
            if let backIn = content.backIn {
                let countdown = Format.duration(backIn)
                if let r = text.range(of: countdown, options: .backwards) {
                    title.addAttribute(.foregroundColor, value: NSColor.labelColor,
                                       range: NSRange(r, in: text))
                }
            }
        }

        button.attributedTitle = title
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
            return item(s)
        }
    }

    private func item(_ title: NSAttributedString) -> NSMenuItem {
        let item = NSMenuItem(title: title.string, action: nil, keyEquivalent: "")
        item.attributedTitle = title
        item.isEnabled = false
        return item
    }
}
