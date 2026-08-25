import Foundation

/// What the menu bar shows: two slots, either of which may be empty.
///
/// The week owns the first slot permanently — Claude Code's status line already
/// shows session usage, so the week is the number nothing else reports. The
/// countdown appends rather than replacing: a slot that changes units cannot be
/// read at a glance.
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

    /// A missing week renders as a dash so the countdown never takes the
    /// percentage's position. It stays a duration here, unlike in the dropdown:
    /// a bare "17:50" beside the system clock reads as a second clock.
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
        if let service, service.isCurrent(at: now), service.isNoteworthy { return service.summary }
        guard let s else { return "Not set up" }
        if let session = s.fiveHour, !session.hasRolledOver(at: now),
           session.usedPercentage >= sessionSpentAt {
            return "Session resumes \(formatting.when(session.resetsAt, now: now))"
        }
        guard let week = s.sevenDay else {
            // Model buckets are usage data too.
            return s.extra.isEmpty ? "No usage data" : "Tracking model limits"
        }
        if week.hasRolledOver(at: now) { return "Waiting for a fresh reading" }
        let pace = Metrics.weeklyPace(week, now: now)
        if pace.isEarly { return "Week just started" }
        if let capsOut = pace.capsOutAt { return "Week runs out \(formatting.when(capsOut, now: now))" }
        return "Week on pace"
    }

    // MARK: Freshness

    public static func isStale(_ s: Snapshot?, now: Date, staleAfter: TimeInterval) -> Bool {
        guard let capturedAt = s?.capturedAt else { return true }
        return now.timeIntervalSince(capturedAt) > staleAfter
    }

    // MARK: Accessibility

    /// What VoiceOver announces for the status item. The fill conveys
    /// direction visually; without this the item read as a bare "12%".
    public static func spoken(_ s: Snapshot?, now: Date, formatting: Formatting,
                              service: ServiceStatus? = nil) -> String {
        var parts = ["Ration."]
        if let service, service.isCurrent(at: now), service.isNoteworthy { parts.append(service.summary + ".") }

        guard let s else { return (parts + ["Not set up."]).joined(separator: " ") }

        if let week = s.sevenDay, !week.hasRolledOver(at: now) {
            let pace = Metrics.weeklyPace(week, now: now)
            // Aloud, "plus" is redundant beside "ahead", and "%" is read as a
            // symbol rather than a word.
            let spokenPace = Format.pace(pace)
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "%", with: " percent")
            parts.append("Week \(Int(week.usedPercentage.rounded())) percent used, \(spokenPace).")
        }
        if let session = s.fiveHour, !session.hasRolledOver(at: now) {
            parts.append(session.usedPercentage >= sessionSpentAt
                ? "Session spent, back \(formatting.when(session.resetsAt, now: now))."
                : "Session \(Int(session.usedPercentage.rounded())) percent used.")
        }
        if parts.count == 1 { parts.append("Waiting for a fresh reading.") }
        return parts.joined(separator: " ")
    }

    /// A row as a phrase: the tab stop that aligns columns reads as a gap.
    public static func spokenRow(_ row: MenuRow) -> String {
        switch row {
        case .headline(let text), .note(let text), .status(let text, _):
            return text
        case .stat(let label, let value):
            let phrase = value.replacingOccurrences(of: " · ", with: ", ")
            return label.isEmpty ? phrase : "\(label): \(phrase)"
        case .separator:
            return ""
        }
    }

    // MARK: Rows

    public static func rows(_ s: Snapshot?, now: Date, staleAfter: TimeInterval,
                            formatting: Formatting = Formatting(),
                            service: ServiceStatus? = nil,
                            isInstalled: Bool = false) -> [MenuRow] {
        guard let s else {
            // Installed but no payload yet is the ordinary first few seconds,
            // not a prompt to install something already installed.
            return isInstalled
                ? [.headline("Waiting for Claude Code"), .separator,
                   .note("Usage appears at the next status line refresh")]
                : [.headline("Not set up"), .separator,
                   .note("Install the status line tap to start")]
        }

        var rows: [MenuRow] = [.headline(headline(s, now: now, formatting: formatting, service: service)),
                               .separator]
        // A problem is repeated as a row so it reads as a distinct fact rather
        // than only as a headline that displaced the usage conclusion.
        if let service, service.isCurrent(at: now), service.isNoteworthy {
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
                           suffix: pace.isEarly ? "" : " · \(Format.pace(pace))")
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
        if let service, service.isCurrent(at: now), !service.isNoteworthy {
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
