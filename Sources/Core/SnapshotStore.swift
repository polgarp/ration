import Foundation

/// Keeps the best-known reading across every Claude Code session.
///
/// All sessions share one snapshot file and each writes it every 10 seconds,
/// so the file is last-write-wins. That is the wrong rule: `rate_limits` only
/// refresh after an API response, so a session left idle since last week
/// rebroadcasts last week's windows indefinitely and clobbers current data.
///
/// Rate limit windows only ever move forward, which makes `resets_at` a
/// version number. A window is accepted only when it is at least as new as the
/// best one seen. No coordination between writers is needed, and the tap stays
/// free of the JSON parsing we deliberately kept out of the hot path.
public struct SnapshotStore {

    public private(set) var best: Snapshot?

    public init() {}

    public mutating func accept(_ incoming: Snapshot) {
        guard let current = best else { best = incoming; return }

        let fiveHour = newer(current.fiveHour, incoming.fiveHour)
        let sevenDay = newer(current.sevenDay, incoming.sevenDay)

        // Freshness follows what was learned, not what was written. If every
        // window in this payload was rejected, nothing new arrived and the
        // reading must be allowed to go stale — even though some process is
        // still dutifully writing the file every 10 seconds.
        let learned = fiveHour.accepted || sevenDay.accepted
        best = Snapshot(fiveHour: fiveHour.window,
                        sevenDay: sevenDay.window,
                        capturedAt: learned ? incoming.capturedAt : current.capturedAt)
    }

    /// Windows are judged independently: one session can hold a current week
    /// alongside a session window that expired hours ago.
    private func newer(_ current: UsageWindow?,
                       _ incoming: UsageWindow?) -> (window: UsageWindow?, accepted: Bool) {
        guard let incoming else { return (current, false) }
        guard let current else { return (incoming, true) }
        // Ties go to the incoming write: same window, more recent usage.
        return incoming.resetsAt >= current.resetsAt ? (incoming, true) : (current, false)
    }
}
