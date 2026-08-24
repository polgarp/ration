import AppKit

/// Installing and removing the status line tap on this machine.
///
/// `Installer` decides what the settings file should contain; this does the
/// filesystem work around it — backing up first, writing the tap where deleting
/// the app cannot break anything, and never touching a settings file it could
/// not parse.
enum Setup {

    /// RATION_CLAUDE_DIR redirects every path below, so the installer can be
    /// exercised end to end against fixtures without going near a real
    /// ~/.claude. Nothing that rewrites someone's configuration should be
    /// testable only in production.
    static var claudeDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["RATION_CLAUDE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
        }
        return URL(fileURLWithPath: NSString(string: "~/.claude").expandingTildeInPath)
    }

    /// The tap command written into settings.json points at the resolved
    /// directory, so an overridden install is self-consistent.
    static var resolvedTapCommand: String {
        let override = ProcessInfo.processInfo.environment["RATION_CLAUDE_DIR"]
        guard let override, !override.isEmpty else { return tapCommand }
        return "bash \(NSString(string: override).expandingTildeInPath)/claude-usage-tap.sh"
    }
    static var settingsURL: URL { claudeDirectory.appendingPathComponent("settings.json") }
    static var tapURL: URL { claudeDirectory.appendingPathComponent("claude-usage-tap.sh") }
    static var snapshotURL: URL { claudeDirectory.appendingPathComponent("usage-snapshot.json") }

    /// The command written into `settings.json`. Uses `~` so the file stays
    /// readable and portable between accounts.
    static let tapCommand = "bash ~/.claude/claude-usage-tap.sh"

    enum Problem: LocalizedError {
        case unreadableSettings
        case tapMissingFromBundle
        case cannotWrite(String)
        case cannotBackUp

        var errorDescription: String? {
            switch self {
            case .unreadableSettings:
                return "~/.claude/settings.json could not be parsed, so nothing was changed. "
                     + "Fix the file by hand and try again."
            case .tapMissingFromBundle:
                return "This copy of Ration is missing its tap script. Re-download the app."
            case .cannotWrite(let what):
                return "Could not write \(what). Nothing was changed."
            case .cannotBackUp:
                return "Could not back up ~/.claude/settings.json, so nothing was changed. "
                     + "Check that ~/.claude is writable and try again."
            }
        }
    }

    private static var cachedState: (modified: Date?, state: Installer.State)?

    /// Cached against settings.json's modification date: the menu bar asks on
    /// every tick, and re-reading and re-parsing an unchanged file forever is
    /// work an always-running app should not be doing.
    static func currentState() -> Installer.State {
        let modified = FileFreshness.modificationDate(of: settingsURL)
        if let cached = cachedState, cached.modified == modified { return cached.state }
        let data = (try? Data(contentsOf: settingsURL)) ?? Data("{}".utf8)
        let state = Installer.inspect(data, tap: resolvedTapCommand)
        cachedState = (modified, state)
        return state
    }

    /// Recorded in Ration's own preferences, never in the user's settings
    /// file: their configuration should carry no trace of us beyond the one
    /// command we wrap.
    private static let addedRefreshKey = "ration.addedRefreshInterval"

    static func install() throws {
        guard let bundled = Bundle.main.url(forResource: "claude-usage-tap", withExtension: "sh"),
              let script = try? Data(contentsOf: bundled)
        else { throw Problem.tapMissingFromBundle }

        let existing = (try? Data(contentsOf: settingsURL)) ?? Data("{}".utf8)
        // Parse before touching anything, so an unreadable file fails with the
        // user's configuration exactly as it was.
        let addedRefresh = Installer.addsRefreshInterval(to: existing)
        let updated = try Installer.install(into: existing, tap: resolvedTapCommand)

        try? FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try backUpSettings(existing)

        do {
            // Atomic: on a re-install the old tap is being executed by every
            // live Claude Code session on its refresh interval, and bash
            // reading a half-written script is exactly the broken status line
            // this app promises never to cause. A rename swaps it whole.
            try script.write(to: tapURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tapURL.path)
        } catch { throw Problem.cannotWrite("the tap script") }

        // Atomic for the same reason: Claude Code re-reads settings.json while
        // we are writing it, and a truncated read is an unparseable config.
        do { try updated.write(to: settingsURL, options: .atomic) }
        catch { throw Problem.cannotWrite("settings.json") }

        // Recorded only once the change actually landed: a flag left behind by
        // a failed install would make a later uninstall strip a refreshInterval
        // it never added.
        UserDefaults.standard.set(addedRefresh, forKey: addedRefreshKey)
        cachedState = nil
    }

    static func uninstall() throws {
        let existing = (try? Data(contentsOf: settingsURL)) ?? Data("{}".utf8)
        let updated = try Installer.uninstall(
            from: existing, tap: resolvedTapCommand,
            removeRefreshInterval: UserDefaults.standard.bool(forKey: addedRefreshKey))
        try backUpSettings(existing)
        do { try updated.write(to: settingsURL, options: .atomic) }
        catch { throw Problem.cannotWrite("settings.json") }
        // Leave nothing of ours behind.
        try? FileManager.default.removeItem(at: tapURL)
        try? FileManager.default.removeItem(at: snapshotURL)
        UserDefaults.standard.removeObject(forKey: addedRefreshKey)
        cachedState = nil
    }

    /// Keeps one backup per day rather than one per attempt, so repeated
    /// fiddling cannot bury the version that actually worked.
    ///
    /// Throws rather than shrugging: the alert promises the file is backed up
    /// first, and overwriting someone's settings after silently failing to copy
    /// them is the one outcome this whole path exists to prevent.
    private static func backUpSettings(_ data: Data) throws {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd"
        let url = claudeDirectory.appendingPathComponent("settings.json.ration-backup-\(stamp.string(from: Date()))")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do { try data.write(to: url, options: .atomic) }
        catch { throw Problem.cannotBackUp }
    }
}
