import Foundation

/// What the menu bar shows: two slots, either of which may be empty.
///
/// The week owns the first slot permanently. Claude Code's own status line
/// already shows session usage on screen while you work, so a session
/// percentage here would be a second copy of a number you are already looking
/// at — the week is the number nothing else reports.
///
/// The countdown *appends*, it never replaces. An earlier version swapped the
/// percentage out, which meant the same slot changed units and a glance could
/// not tell which reading it was seeing.
public struct BarContent: Equatable {
    /// Percentage **used**, not remaining: the disc fills as you spend, so the
    /// number has to count in the same direction or the two halves of the item
    /// move opposite ways.
    public let weekUsed: Double?
    /// Time until the session resets, present only once you are locked out.
    public let backIn: TimeInterval?

    public var isEmpty: Bool { weekUsed == nil && backIn == nil }

    public init(weekUsed: Double?, backIn: TimeInterval?) {
        self.weekUsed = weekUsed
        self.backIn = backIn
    }
}

public enum MenuRow: Equatable {
    case headline(String)
    case stat(String, String)
    case note(String)
    /// Carries a level so the view can draw a semantic dot.
    case status(String, ServiceStatus.Level)
    case separator
}

public enum MenuModel {

    /// At or above this the session is effectively gone.
    public static let sessionSpentAt: Double = 99

    /// Said when a window has rolled over and Claude Code has not yet served a
    /// payload for the new one.
    static let waitingText = "waiting for a fresh reading"

    // MARK: Bar

    public static func bar(_ s: Snapshot?, now: Date) -> BarContent {
        guard let s else { return BarContent(weekUsed: nil, backIn: nil) }

        var week: Double?
        if let w = s.sevenDay, !w.hasRolledOver(at: now) { week = w.usedPercentage.rounded() }

        var backIn: TimeInterval?
        if let session = s.fiveHour, !session.hasRolledOver(at: now),
           session.usedPercentage >= sessionSpentAt {
            backIn = max(0, session.resetsAt.timeIntervalSince(now))
        }

        return BarContent(weekUsed: week, backIn: backIn)
    }

    /// A missing week still renders its slot as a dash, so the countdown never
    /// slides into the position the percentage normally holds.
    ///
    /// The countdown stays a *duration* here even though the dropdown gives a
    /// concrete time: a bare "17:50" in the menu bar sits inches from the
    /// system clock and reads as a duplicate of it.
    public static func barText(_ content: BarContent) -> String {
        let week = content.weekUsed.map { "\(Int($0))%" }
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

    /// The conclusion, in words — and always naming which window it is about,
    /// because a bare "Comfortable" leaves you asking comfortable about what.
    public static func headline(_ s: Snapshot?, now: Date, formatting: Formatting,
                                service: ServiceStatus? = nil) -> String {
        // If Claude itself is down, your quota is beside the point.
        if let service, service.isNoteworthy { return service.summary }
        guard let s else { return "Not set up" }
        if let session = s.fiveHour, !session.hasRolledOver(at: now),
           session.usedPercentage >= sessionSpentAt {
            return "Session resumes \(formatting.when(session.resetsAt, now: now))"
        }
        guard let week = s.sevenDay else { return "No usage data" }
        if week.hasRolledOver(at: now) { return "Waiting for a fresh reading" }
        let pace = Metrics.weeklyPace(week, now: now)
        if let capsOut = pace.capsOutAt { return "Week runs out \(formatting.when(capsOut, now: now))" }
        return "Week on pace"
    }

    // MARK: Freshness

    public static func isStale(_ s: Snapshot?, now: Date, staleAfter: TimeInterval) -> Bool {
        guard let capturedAt = s?.capturedAt else { return true }
        return now.timeIntervalSince(capturedAt) > staleAfter
    }

    // MARK: Rows

    public static func rows(_ s: Snapshot?, now: Date, staleAfter: TimeInterval,
                            formatting: Formatting = Formatting(),
                            service: ServiceStatus? = nil) -> [MenuRow] {
        guard let s else {
            return [.headline("Not set up"), .separator,
                    .note("Install the status line tap to start")]
        }

        var rows: [MenuRow] = [.headline(headline(s, now: now, formatting: formatting, service: service)),
                               .separator]
        // A problem is repeated as a row so it reads as a distinct fact rather
        // than only as a headline that displaced the usage conclusion.
        if let service, service.isNoteworthy {
            rows.append(.status(service.summary, service.claudeCode))
            rows.append(.separator)
        }

        if s.fiveHour == nil && s.sevenDay == nil && s.extra.isEmpty {
            rows.append(.note("Needs a Claude Pro or Max subscription"))
            rows.append(.separator)
            rows.append(freshness(s, now: now, staleAfter: staleAfter))
            return rows
        }

        // Every window gets the same two-line shape: what it has cost, then
        // when it comes back.
        if let week = s.sevenDay {
            let pace = Metrics.weeklyPace(week, now: now)
            rows += window("Week", week, now: now, formatting: formatting,
                           suffix: " · \(Format.pace(pace))")
        }
        if let session = s.fiveHour {
            rows += window("Session", session, now: now, formatting: formatting,
                           spentAt: sessionSpentAt)
        }
        for bucket in s.extra {
            rows += window(bucket.label, bucket.window, now: now, formatting: formatting)
        }

        rows.append(.separator)
        // When all is well the confirmation stays small and last: enough to see
        // the watch is running, not enough to be told daily that nothing is
        // wrong.
        if let service, !service.isNoteworthy {
            rows.append(.status(service.summary, service.claudeCode))
        }
        rows.append(freshness(s, now: now, staleAfter: staleAfter))
        return rows
    }

    private static func window(_ label: String, _ w: UsageWindow, now: Date,
                               formatting: Formatting,
                               suffix: String = "", spentAt: Double? = nil) -> [MenuRow] {
        if w.hasRolledOver(at: now) { return [.stat(label, waitingText)] }
        if let spentAt, w.usedPercentage >= spentAt {
            return [.stat(label, "spent"),
                    .stat("", "resumes \(formatting.when(w.resetsAt, now: now))")]
        }
        return [.stat(label, "\(Int(w.usedPercentage.rounded()))% used\(suffix)"),
                .stat("", "resets \(formatting.when(w.resetsAt, now: now))")]
    }

    private static func freshness(_ s: Snapshot, now: Date, staleAfter: TimeInterval) -> MenuRow {
        let age = now.timeIntervalSince(s.capturedAt)
        return .note(age > staleAfter
            ? "Claude Code not running · \(Format.ago(age))"
            : "Updated \(Format.ago(age))")
    }
}
