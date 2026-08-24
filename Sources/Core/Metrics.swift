import Foundation

public struct UsageWindow {
    public let usedPercentage: Double
    public let resetsAt: Date
    public init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    /// True once the window's reset time has passed.
    ///
    /// Claude Code refreshes `rate_limits` only after a new API response, so a
    /// payload can outlive its own window: the percentages then describe a
    /// window that no longer exists, and every number derived from them —
    /// remaining, pace, projection — is about the past.
    public func hasRolledOver(at now: Date) -> Bool { resetsAt <= now }
}

public struct WeeklyPace {
    public let elapsedPercentage: Double
    public let usedPercentage: Double
    public let projectedEndOfWeek: Double?
    public let capsOutAt: Date?
    public var delta: Double { usedPercentage - elapsedPercentage }
}

public enum Metrics {
    public static let weekLength: TimeInterval = 7 * 24 * 3600

    /// Below this much of the window elapsed, a projection is noise, not signal.
    public static let minimumElapsedForProjection: Double = 1.0

    public static func weeklyPace(_ window: UsageWindow, now: Date) -> WeeklyPace {
        let start = window.resetsAt.addingTimeInterval(-weekLength)
        let elapsed = now.timeIntervalSince(start) / weekLength * 100
        let used = window.usedPercentage

        // Extrapolating from a sliver of elapsed time divides by ~zero and
        // yields a confidently wrong number, so say nothing until the window
        // has actually run for a while.
        var projected: Double?
        var capsOutAt: Date?
        let secondsElapsed = now.timeIntervalSince(start)
        if elapsed >= minimumElapsedForProjection, secondsElapsed > 0 {
            let end = used / elapsed * 100
            projected = end
            if end > 100 {
                // Percent per second, extended until it reaches 100.
                let rate = used / secondsElapsed
                if rate > 0 { capsOutAt = start.addingTimeInterval(100 / rate) }
            }
        }

        return WeeklyPace(elapsedPercentage: elapsed, usedPercentage: used,
                          projectedEndOfWeek: projected, capsOutAt: capsOutAt)
    }
}
