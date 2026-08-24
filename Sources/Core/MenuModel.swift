import Foundation

/// What the menu bar's single number says.
///
/// The week owns the slot by default: Claude Code's own status line already
/// shows session usage on screen while you work, so a session percentage here
/// would be a second copy of a number you are already looking at. The week is
/// the number nothing else reports.
public enum BarContent: Equatable {
    case none
    case weekRemaining(Double)
    /// Time until the session resets. Takes over when you are locked out —
    /// which is both the moment this matters most and the moment Claude Code
    /// is closed, so the percentages are going stale while this stays exact.
    case backIn(TimeInterval)
}

public enum MenuRow: Equatable {
    case headline(String)
    case stat(String, String)
    case note(String)
    case separator
}

public enum MenuModel {

    /// At or above this, the session is effectively gone and the countdown
    /// becomes the useful number.
    public static let sessionSpentAt: Double = 99

    /// Said when a window has rolled over and Claude Code has not yet served a
    /// payload for the new one.
    static let waitingText = "waiting for a fresh reading"

    // MARK: Bar

    public static func bar(_ s: Snapshot?, now: Date) -> BarContent {
        guard let s else { return .none }
        if let session = s.fiveHour, !session.hasRolledOver(at: now),
           session.usedPercentage >= sessionSpentAt {
            return .backIn(max(0, session.resetsAt.timeIntervalSince(now)))
        }
        guard let week = s.sevenDay, !week.hasRolledOver(at: now) else { return .none }
        return .weekRemaining(max(0, 100 - week.usedPercentage).rounded())
    }

    /// What the mark is drawn from — always the week, so the glyph and the
    /// number can never make competing claims.
    public static func markUsage(_ s: Snapshot?, now: Date = Date()) -> Double? {
        guard let week = s?.sevenDay, !week.hasRolledOver(at: now) else { return nil }
        return week.usedPercentage
    }

    // MARK: Headline

    /// The conclusion, in words. The rows below carry the arithmetic.
    public static func headline(_ s: Snapshot?, now: Date) -> String {
        guard let s else { return "Not set up" }
        if let session = s.fiveHour, !session.hasRolledOver(at: now),
           session.usedPercentage >= sessionSpentAt {
            return "Back at \(Format.clock(session.resetsAt))"
        }
        guard let week = s.sevenDay else { return "No usage data" }
        if week.hasRolledOver(at: now) { return waitingText.prefix(1).uppercased() + waitingText.dropFirst() }
        let pace = Metrics.weeklyPace(week, now: now)
        if let capsOut = pace.capsOutAt { return "Runs out \(Format.dayAndTime(capsOut))" }
        return "Comfortable"
    }

    // MARK: Freshness

    public static func isStale(_ s: Snapshot?, now: Date, staleAfter: TimeInterval) -> Bool {
        guard let capturedAt = s?.capturedAt else { return true }
        return now.timeIntervalSince(capturedAt) > staleAfter
    }

    // MARK: Rows

    public static func rows(_ s: Snapshot?, now: Date, staleAfter: TimeInterval) -> [MenuRow] {
        guard let s else {
            return [.headline("Not set up"), .separator,
                    .note("Install the status line tap to start")]
        }

        var rows: [MenuRow] = [.headline(headline(s, now: now)), .separator]

        if s.fiveHour == nil && s.sevenDay == nil {
            rows.append(.note("Needs a Claude Pro or Max subscription"))
            rows.append(.separator)
            rows.append(freshness(s, now: now, staleAfter: staleAfter))
            return rows
        }

        if let week = s.sevenDay {
            if week.hasRolledOver(at: now) {
                rows.append(.stat("Week", waitingText))
            } else {
                let pace = Metrics.weeklyPace(week, now: now)
                rows.append(.stat("Week", "\(remaining(week))% left · \(Format.pace(pace))"))
                rows.append(.stat("", "resets \(Format.dayAndTime(week.resetsAt))"))
            }
        }

        if let session = s.fiveHour {
            if session.hasRolledOver(at: now) {
                rows.append(.stat("Session", waitingText))
            } else {
                let left = session.resetsAt.timeIntervalSince(now)
                rows.append(.stat("Session", session.usedPercentage >= sessionSpentAt
                    ? "spent · back in \(Format.duration(left))"
                    : "\(remaining(session))% left · resets in \(Format.duration(left))"))
            }
        }

        rows.append(.separator)
        rows.append(freshness(s, now: now, staleAfter: staleAfter))
        return rows
    }

    private static func remaining(_ w: UsageWindow) -> Int {
        Int(max(0, 100 - w.usedPercentage).rounded())
    }

    private static func freshness(_ s: Snapshot, now: Date, staleAfter: TimeInterval) -> MenuRow {
        let age = now.timeIntervalSince(s.capturedAt)
        return .note(age > staleAfter
            ? "Claude Code not running · \(Format.ago(age))"
            : "Updated \(Format.ago(age))")
    }
}
