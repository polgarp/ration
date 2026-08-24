import Foundation

public struct UsageWindow: Equatable {
    public let usedPercentage: Double
    public let resetsAt: Date
    public init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    /// True once the reset time has passed.
    ///
    /// `rate_limits` refresh only after an API response, so a payload can
    /// outlive its window — every number derived from it then describes the past.
    public func hasRolledOver(at now: Date) -> Bool { resetsAt <= now }
}

public struct WeeklyPace {
    public let elapsedPercentage: Double
    public let usedPercentage: Double
    public let projectedEndOfWeek: Double?
    public let capsOutAt: Date?
    public var delta: Double { usedPercentage - elapsedPercentage }

    /// One threshold, used by the wording, the headline and the mark alike.
    /// They previously disagreed: "on pace" allowed a point of slack while the
    /// cap-out headline fired on any positive delta, so half a point ahead
    /// produced a dropdown saying "on pace" above a headline naming the day the
    /// week runs out.
    public var isOverPace: Bool { delta >= Metrics.paceTolerance }
}

public enum Metrics {
    public static let weekLength: TimeInterval = 7 * 24 * 3600

    /// Slack either side of perfectly on pace, below which no claim is made.
    public static let paceTolerance: Double = 1.0

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
            // Gated on the shared tolerance, not merely on end > 100, so a
            // hair over the line does not produce an alarming date.
            if used - elapsed >= paceTolerance, end > 100 {
                // Percent per second, extended until it reaches 100.
                let rate = used / secondsElapsed
                if rate > 0 { capsOutAt = start.addingTimeInterval(100 / rate) }
            }
        }

        return WeeklyPace(elapsedPercentage: elapsed, usedPercentage: used,
                          projectedEndOfWeek: projected, capsOutAt: capsOutAt)
    }
}
