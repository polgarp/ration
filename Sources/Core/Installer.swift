import Foundation

/// Rewrites Claude Code's `settings.json` to wrap the status line.
///
/// A bug here breaks a stranger's Claude Code, so three rules, each a test:
///
/// 1. Never write what we could not read — unparseable settings throw.
/// 2. Never lose their command — wrapping prefixes, unwrapping strips.
/// 3. Never undo a choice they made — a faster `refreshInterval` stays.
///
/// Re-serialising may reorder keys; the caller backs the file up first.
public enum Installer {

    public enum State: Equatable {
        case notConfigured
        case wrapped
        /// Their own status line command, which wrapping must preserve exactly.
        case unwrapped(String)
        case unreadable
    }

    public enum Failure: Error, Equatable {
        case unreadable
    }

    /// Matches the plan's documented default; only applied when unset.
    public static let refreshInterval = 10

    // MARK: Inspecting

    public static func inspect(_ settings: Data, tap: String) -> State {
        guard let root = object(settings) else { return .unreadable }
        let block: [String: Any]?
        do { block = try statusLineBlock(root) } catch { return .unreadable }
        guard let block,
              let command = block["command"] as? String,
              !command.isEmpty
        else { return .notConfigured }
        if command == tap || command.hasPrefix(tap + " ") { return .wrapped }
        return .unwrapped(command)
    }

    // MARK: Changing

    /// Whether installing had to add `refreshInterval` itself. The caller
    /// remembers this so uninstalling can remove exactly what it added and
    /// nothing more — we cannot tell later whether a 10 was ours or theirs.
    public static func addsRefreshInterval(to settings: Data) -> Bool {
        guard let root = object(settings) else { return false }
        let statusLine = root["statusLine"] as? [String: Any]
        return statusLine?["refreshInterval"] == nil
    }

    public static func install(into settings: Data, tap: String) throws -> Data {
        guard var root = object(settings) else { throw Failure.unreadable }

        var statusLine = try statusLineBlock(root) ?? ["type": "command"]
        let existing = statusLine["command"] as? String ?? ""

        // Idempotent: wrapping an already-wrapped command leaves it alone,
        // rather than nesting the tap inside itself.
        if !(existing == tap || existing.hasPrefix(tap + " ")) {
            statusLine["command"] = existing.isEmpty ? tap : "\(tap) \(existing)"
        }
        if statusLine["type"] == nil { statusLine["type"] = "command" }

        // Only fill a gap. A user who chose 2s wants 2s.
        if statusLine["refreshInterval"] == nil {
            statusLine["refreshInterval"] = refreshInterval
        }

        root["statusLine"] = statusLine
        return try serialise(root)
    }

    /// - Parameter removeRefreshInterval: pass what `addsRefreshInterval`
    ///   reported at install time. When in doubt pass `false`: leaving a
    ///   refresh interval behind is harmless, removing one the user chose is not.
    public static func uninstall(from settings: Data, tap: String,
                                 removeRefreshInterval: Bool = false) throws -> Data {
        guard var root = object(settings) else { throw Failure.unreadable }
        guard var statusLine = try statusLineBlock(root),
              let command = statusLine["command"] as? String
        else { return try serialise(root) }

        if removeRefreshInterval { statusLine["refreshInterval"] = nil }

        if command == tap {
            // We were the whole status line, so leave nothing behind.
            root["statusLine"] = nil
        } else if command.hasPrefix(tap + " ") {
            statusLine["command"] = String(command.dropFirst(tap.count + 1))
            root["statusLine"] = statusLine
        }
        return try serialise(root)
    }

    // MARK: Explaining

    /// What the user is agreeing to, in the exact strings that will be written.
    public static func preview(for state: State, tap: String) -> String {
        switch state {
        case .unwrapped(let command):
            return """
            Your status line command changes from

                \(command)

            to

                \(tap) \(command)

            Your status line keeps rendering exactly as it does now — the tap \
            passes it through untouched. refreshInterval is set to \
            \(refreshInterval) seconds if you have not set one.
            """
        case .notConfigured:
            return """
            You have no status line, so one is added that only saves usage data \
            and prints nothing:

                \(tap)

            refreshInterval is set to \(refreshInterval) seconds.
            """
        case .wrapped:
            return "Already set up. Nothing to change."
        case .unreadable:
            return "settings.json could not be parsed, so nothing will be changed."
        }
    }

    // MARK: Helpers

    /// The `statusLine` block, or `nil` when there is none.
    ///
    /// Throws on an unfamiliar shape — `"statusLine": "my-script.sh"` read as
    /// "no status line" would silently overwrite it. Rule 1, one level down.
    private static func statusLineBlock(_ root: [String: Any]) throws -> [String: Any]? {
        guard let raw = root["statusLine"], !(raw is NSNull) else { return nil }
        guard let block = raw as? [String: Any] else { throw Failure.unreadable }
        if let command = block["command"], !(command is NSNull), !(command is String) {
            throw Failure.unreadable
        }
        return block
    }

    private static func object(_ data: Data) -> [String: Any]? {
        guard !data.isEmpty,
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let root = parsed as? [String: Any]
        else { return nil }
        return root
    }

    private static func serialise(_ root: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: root,
                                              options: [.prettyPrinted, .sortedKeys,
                                                        .withoutEscapingSlashes])
        data.append(0x0A)   // Trailing newline, as any hand-edited file would have.
        return data
    }
}
