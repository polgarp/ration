import Foundation

/// Keeps the newest reading across every Claude Code session.
///
/// All sessions write the same snapshot file, and `rate_limits` refresh only
/// after an API response — so an idle session rebroadcasts expired windows
/// forever. Last-write-wins is therefore wrong.
///
/// Windows only move forward, so `resets_at` orders them; usage only climbs, so
/// it orders writes sharing a `resets_at`.
public struct SnapshotStore {

    public private(set) var best: Snapshot?

    public init() {}

    public mutating func accept(_ incoming: Snapshot) {
        guard let current = best else { best = incoming; return }

        let fiveHour = newer(current.fiveHour, incoming.fiveHour)
        let sevenDay = newer(current.sevenDay, incoming.sevenDay)

        // Freshness follows what was learned, not what was written: a payload
        // of nothing but rejected windows must still be allowed to go stale.
        // Server-labelled buckets come and go, so they merge by label.
        var buckets: [String: UsageWindow] = [:]
        for b in current.extra { buckets[b.label] = b.window }
        var adoptedBucket = false
        for b in incoming.extra {
            let merged = newer(buckets[b.label], b.window)
            buckets[b.label] = merged.window
            adoptedBucket = adoptedBucket || merged.accepted
        }

        let learned = fiveHour.accepted || sevenDay.accepted || adoptedBucket

        // A current payload's bucket list is authoritative, so a withdrawn or
        // renamed bucket disappears instead of reading "waiting for a fresh
        // reading" forever. A stale payload's list is not.
        if learned {
            let present = Set(incoming.extra.map(\.label))
            buckets = buckets.filter { present.contains($0.key) }
        }
        let extra = buckets
            .map { NamedWindow(label: $0.key, window: $0.value) }
            .sorted { $0.label < $1.label }
        best = Snapshot(fiveHour: fiveHour.window,
                        sevenDay: sevenDay.window,
                        extra: extra,
                        capturedAt: learned ? incoming.capturedAt : current.capturedAt)
    }

    /// Judged per window: a session can hold a current week beside an expired
    /// 5-hour one.
    ///
    /// - Returns: the window to keep, and whether the write concerned a current
    ///   window — which is what freshness turns on, even if its value lost.
    private func newer(_ current: UsageWindow?,
                       _ incoming: UsageWindow?) -> (window: UsageWindow?, accepted: Bool) {
        guard let incoming else { return (current, false) }
        guard let current else { return (incoming, true) }
        if incoming.resetsAt > current.resetsAt { return (incoming, true) }
        if incoming.resetsAt < current.resetsAt { return (current, false) }
        // Every session shares the weekly resets_at for a whole week, so ties
        // are the ordinary case. Usage only climbs, so the higher reading is
        // the later one; deferring to whoever wrote last lets an idle session
        // drag the week backwards.
        return (incoming.usedPercentage >= current.usedPercentage ? incoming : current, true)
    }
}
