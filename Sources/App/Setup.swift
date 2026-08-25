import AppKit

/// Installing and removing the tap on this machine.
///
/// `Installer` decides what the file should contain; this does the filesystem
/// work — backing up first, and writing the tap outside the app bundle so
/// deleting Ration cannot break a status line.
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
        let updated: Data
        do { updated = try Installer.install(into: existing, tap: resolvedTapCommand) }
        catch { throw Problem.unreadableSettings }

        try? FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try backUpSettings(existing)

        do {
            // Atomic: live sessions execute this script on their refresh
            // interval, and bash reading a half-written file is a broken
            // status line. A rename swaps it whole.
            try script.write(to: tapURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tapURL.path)
        } catch { throw Problem.cannotWrite("the tap script") }

        // Atomic for the same reason: Claude Code re-reads settings.json
        // concurrently, and a truncated read is an unparseable config.
        do { try updated.write(to: settingsURL, options: .atomic) }
        catch { throw Problem.cannotWrite("settings.json") }

        // Recorded only once the write lands, so a failed install cannot leave
        // a flag that makes uninstall strip an interval it never added.
        UserDefaults.standard.set(addedRefresh, forKey: addedRefreshKey)
        cachedState = nil
    }

    static func uninstall() throws {
        let existing = (try? Data(contentsOf: settingsURL)) ?? Data("{}".utf8)
        let updated: Data
        do {
            updated = try Installer.uninstall(
                from: existing, tap: resolvedTapCommand,
                removeRefreshInterval: UserDefaults.standard.bool(forKey: addedRefreshKey))
        } catch { throw Problem.unreadableSettings }
        try backUpSettings(existing)
        do { try updated.write(to: settingsURL, options: .atomic) }
        catch { throw Problem.cannotWrite("settings.json") }
        // Leave nothing of ours behind.
        try? FileManager.default.removeItem(at: tapURL)
        try? FileManager.default.removeItem(at: snapshotURL)
        UserDefaults.standard.removeObject(forKey: addedRefreshKey)
        cachedState = nil
    }

    /// One backup per day, so repeated attempts cannot bury the version that
    /// worked. Throws rather than shrugging: the alert promises a backup, and
    /// overwriting after a silent copy failure is the outcome to prevent.
    ///
    /// The copy inherits the original's permissions. settings.json may hold
    /// environment variables and permission rules, and a user who restricted it
    /// to 0600 has not consented to a world-readable duplicate.
    private static func backUpSettings(_ data: Data) throws {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd"
        let url = claudeDirectory.appendingPathComponent("settings.json.ration-backup-\(stamp.string(from: Date()))")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try data.write(to: url, options: .atomic)
            let mode = (try? FileManager.default.attributesOfItem(atPath: settingsURL.path))?[.posixPermissions]
            try FileManager.default.setAttributes([.posixPermissions: mode ?? 0o600],
                                                  ofItemAtPath: url.path)
        } catch { throw Problem.cannotBackUp }
    }
}
