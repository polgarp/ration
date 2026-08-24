import AppKit

/// The menu bar item and its dropdown.
///
/// Deliberately thin: what the dropdown *says* lives in `MenuModel`, which has
/// no AppKit and is covered by tests. This file only turns rows into views.
final class MenuBarController: NSObject {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let snapshotURL: URL
    private var snapshot: Snapshot?
    private var lastModified: Date?
    private var timer: Timer?

    /// Older than this means Claude Code is not running, so the reading is a
    /// leftover rather than current truth. The tap fires on a 10s
    /// refreshInterval, so this tolerates several missed beats.
    private let staleAfter: TimeInterval = 90

    init(snapshotURL: URL) {
        self.snapshotURL = snapshotURL
        super.init()

        reload()
        render()

        // One timer does both jobs. A DispatchSource vnode watch is the
        // obvious choice, but the tap replaces the file by atomic rename, so
        // the watched descriptor would point at a dead inode after every write
        // and need re-arming. Countdowns must re-render every second anyway,
        // and comparing an mtime is one stat() — cheaper than being clever.
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
        snapshot = Snapshot.load(from: snapshotURL)
    }

    private var isStale: Bool {
        guard let capturedAt = snapshot?.capturedAt else { return true }
        return Date().timeIntervalSince(capturedAt) > staleAfter
    }

    private func render() {
        let now = Date()

        // Monospaced digits so the item doesn't jitter as the number changes.
        // Colours come from semantic NSColors, which resolve correctly in both
        // light and dark menu bars without a second palette.
        statusItem.button?.attributedTitle = NSAttributedString(
            string: MenuModel.barTitle(snapshot),
            attributes: [
                .foregroundColor: isStale ? NSColor.tertiaryLabelColor : NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)
            ])

        let menu = NSMenu()
        for row in MenuModel.rows(snapshot, now: now, staleAfter: staleAfter) {
            menu.addItem(view(for: row))
        }
        menu.addItem(NSMenuItem(title: "Quit Ration",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func view(for row: MenuRow) -> NSMenuItem {
        switch row {
        case .separator:
            return .separator()
        case .heading(let text):
            return styled(text, font: .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                          colour: .secondaryLabelColor)
        case .detail(let text):
            return styled("   " + text, font: .menuFont(ofSize: 0), colour: .labelColor)
        case .note(let text):
            return styled(text, font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                          colour: .secondaryLabelColor)
        }
    }

    private func styled(_ text: String, font: NSFont, colour: NSColor) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: colour])
        item.isEnabled = false
        return item
    }
}
