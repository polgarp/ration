import Foundation

/// A usage window with a label, for buckets beyond the two documented ones.
public struct NamedWindow: Equatable {
    public let label: String
    public let window: UsageWindow
    public init(label: String, window: UsageWindow) {
        self.label = label
        self.window = window
    }
}

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
    /// Per-model and server-labelled buckets — `seven_day_opus`,
    /// `seven_day_sonnet`, and the `model_scoped` list whose `display_name` the
    /// server supplies ("e.g. 'Fable'"). All undocumented, so every one is
    /// optional and nothing downstream may depend on a particular label
    /// existing. Rendering whatever arrives is what lets a new bucket appear
    /// without a release.
    public let extra: [NamedWindow]
    public let capturedAt: Date

    public init(fiveHour: UsageWindow?, sevenDay: UsageWindow?,
                extra: [NamedWindow] = [], capturedAt: Date) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.extra = extra
        self.capturedAt = capturedAt
    }

    // MARK: - Decoding

    /// `resets_at` is epoch seconds on the documented windows but an ISO string
    /// inside `model_scoped`, so it has to accept either.
    private struct Instant: Decodable {
        let date: Date?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let seconds = try? c.decode(Double.self) {
                date = Date(timeIntervalSince1970: seconds)
            } else if let text = try? c.decode(String.self) {
                date = Snapshot.parseISO(text)
            } else {
                date = nil
            }
        }
    }

    /// `ISO8601DateFormatter` matches exactly one shape at a time: the default
    /// options reject fractional seconds outright. `model_scoped` is
    /// undocumented, so its precision is not ours to assume — and a formatter
    /// that says no drops the whole bucket silently rather than failing loudly.
    private static let isoFormatters: [ISO8601DateFormatter] = {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [plain, fractional]
    }()

    static func parseISO(_ text: String) -> Date? {
        for formatter in isoFormatters {
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private struct Payload: Decodable {
        struct Window: Decodable {
            let usedPercentage: Double?
            let resetsAt: Instant?
        }
        struct Scoped: Decodable {
            let displayName: String?
            /// A 0–1 fraction here, where the documented windows use 0–100.
            let utilization: Double?
            let resetsAt: Instant?
        }
        struct RateLimits: Decodable {
            let fiveHour: Window?
            let sevenDay: Window?
            let sevenDayOpus: Window?
            let sevenDaySonnet: Window?
            let modelScoped: [Scoped]?
        }
        let rateLimits: RateLimits?
    }

    public static func decode(_ data: Data, capturedAt: Date) -> Snapshot? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let payload = try? decoder.decode(Payload.self, from: data) else { return nil }
        let limits = payload.rateLimits

        func window(_ w: Payload.Window?) -> UsageWindow? {
            guard let w, let used = w.usedPercentage, let resets = w.resetsAt?.date else { return nil }
            return UsageWindow(usedPercentage: used, resetsAt: resets)
        }

        var extra: [NamedWindow] = []
        if let opus = window(limits?.sevenDayOpus) { extra.append(NamedWindow(label: "Opus", window: opus)) }
        if let sonnet = window(limits?.sevenDaySonnet) { extra.append(NamedWindow(label: "Sonnet", window: sonnet)) }
        for scoped in limits?.modelScoped ?? [] {
            guard let label = scoped.displayName,
                  let utilization = scoped.utilization,
                  let resets = scoped.resetsAt?.date else { continue }
            extra.append(NamedWindow(label: label,
                                     window: UsageWindow(usedPercentage: utilization * 100,
                                                         resetsAt: resets)))
        }

        return Snapshot(fiveHour: window(limits?.fiveHour),
                        sevenDay: window(limits?.sevenDay),
                        extra: extra,
                        capturedAt: capturedAt)
    }

    /// Reads a snapshot from disk, taking the capture time from the file's
    /// modification date — the tap writes no timestamp of its own, precisely so
    /// it can stay out of the status line's hot path.
    public static func load(from url: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mtime = FileFreshness.modificationDate(of: url) ?? Date()
        return decode(data, capturedAt: mtime)
    }
}
