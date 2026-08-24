import Foundation

/// What the menu bar shows: two slots, either of which may be empty.
///
/// The week owns the first slot permanently. Claude Code's own status line
/// already shows session usage on screen while you work, so a session
/// percentage here would be a second copy of a number you are already looking
/// at — the week is the number nothing else reports.
///
/// The countdown *appends*, it never replaces. An earlier version swapped the
/// percentage out for the countdown, which meant the same slot changed units
/// and a glance could not tell which reading it was seeing.
public struct BarContent: Equatable {
    public let weekRemaining: Double?
    /// Time until the session resets, present only once you are locked out.
    public let backIn: TimeInterval?

    public var isEmpty: Bool { weekRemaining == nil && backIn == nil }

    public init(weekRemaining: Double?, backIn: TimeInterval?) {
        self.weekRemaining = weekRemaining
        self.backIn = backIn
    }
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
        guard let s else { return BarContent(weekRemaining: nil, backIn: nil) }

        var week: Double?
        if let w = s.sevenDay, !w.hasRolledOver(at: now) {
            week = max(0, 100 - w.usedPercentage).rounded()
        }

        var backIn: TimeInterval?
        if let session = s.fiveHour, !session.hasRolledOver(at: now),
           session.usedPercentage >= sessionSpentAt {
            backIn = max(0, session.resetsAt.timeIntervalSince(now))
        }

        return BarContent(weekRemaining: week, backIn: backIn)
    }

    /// The bar's text. A missing week still renders its slot as a dash, so the
    /// countdown never slides into the position the percentage normally holds.
    public static func barText(_ content: BarContent) -> String {
        let week = content.weekRemaining.map { "\(Int($0))%" }
        guard let backIn = content.backIn else { return week ?? "—" }
        return "\(week ?? "—") · \(Format.duration(backIn))"
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
