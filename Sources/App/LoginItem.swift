import AppKit

/// Starting Ration when the user logs in.
///
/// A LaunchAgent plist rather than `SMAppService`, because Ration is ad-hoc
/// signed: with no Developer ID, macOS identifies a registered app by the hash
/// of its binary, so a registration stops matching the moment the app is
/// rebuilt — silently, on every `brew upgrade`. A plist is keyed on the app's
/// path, and Homebrew's `opt` path is stable across upgrades.
///
/// launchd reads `~/Library/LaunchAgents` at login, so writing the file is the
/// whole operation; nothing needs loading now, and Ration spawns no
/// subprocesses to do it.
enum LoginItem {

    static let label = "com.polgarp.ration"

    /// Overridable so tests never write into a real LaunchAgents folder.
    static var directory: URL {
        if let override = ProcessInfo.processInfo.environment["RATION_LAUNCH_AGENTS_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
        }
        return URL(fileURLWithPath: NSString(string: "~/Library/LaunchAgents").expandingTildeInPath)
    }

    static var plistURL: URL { directory.appendingPathComponent("\(label).plist") }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    /// The bundle's own path, deliberately unresolved: under Homebrew this is
    /// the `opt` symlink, which keeps pointing at the current version.
    static var executablePath: String {
        Bundle.main.executableURL?.path
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/Ration").path
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard enabled else {
            try? FileManager.default.removeItem(at: plistURL)
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                      format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }
}
