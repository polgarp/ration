import Foundation

/// One capture of Claude Code's status line payload.
///
/// Decoding is deliberately forgiving. The documented schema is narrower than
/// what actually arrives, and the docs warn that `rate_limits` shows up only
/// for Pro/Max subscribers, only after the first API response of a session,
/// and that each window may be independently absent. Anything unreadable
/// becomes `nil` rather than a crash or a misleading zero.
public struct Snapshot {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?
    public let capturedAt: Date

    public init(fiveHour: UsageWindow?, sevenDay: UsageWindow?, capturedAt: Date) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.capturedAt = capturedAt
    }

    private struct Payload: Decodable {
        struct Window: Decodable {
            let usedPercentage: Double?
            let resetsAt: Double?
        }
        struct RateLimits: Decodable {
            let fiveHour: Window?
            let sevenDay: Window?
        }
        let rateLimits: RateLimits?
    }

    public static func decode(_ data: Data, capturedAt: Date) -> Snapshot? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let payload = try? decoder.decode(Payload.self, from: data) else { return nil }

        func window(_ w: Payload.Window?) -> UsageWindow? {
            guard let w, let used = w.usedPercentage, let resets = w.resetsAt else { return nil }
            return UsageWindow(usedPercentage: used, resetsAt: Date(timeIntervalSince1970: resets))
        }

        return Snapshot(fiveHour: window(payload.rateLimits?.fiveHour),
                        sevenDay: window(payload.rateLimits?.sevenDay),
                        capturedAt: capturedAt)
    }

    /// Reads a snapshot from disk, taking the capture time from the file's
    /// modification date — the tap writes no timestamp of its own, precisely so
    /// it can stay out of the status line's hot path.
    public static func load(from url: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date()
        return decode(data, capturedAt: mtime)
    }
}
