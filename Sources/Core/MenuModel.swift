import Foundation

/// What the menu bar shows: two slots, either of which may be empty.
///
/// The week owns the first slot permanently — Claude Code's status line covers
/// the session, so the week is the number nothing else reports. The countdown
/// appends rather than replacing: a slot that changes units cannot be read at
/// a glance.
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
    /// Label, text, and a level so the view can draw a semantic dot.
    case status(String, String, ServiceStatus.Level)
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

    /// Always the week, so the glyph and the number report one window.
    public static func markUsage(_ s: Snapshot?, now: Date) -> Double? {
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

    /// Whether Claude Code has stopped writing. Keyed on the last write of any
    /// kind: idle sessions rebroadcast expired windows, and refusing their data
    /// says nothing about whether anything is running.
    public static func isStale(lastWriteAt: Date?, now: Date, staleAfter: TimeInterval) -> Bool {
        guard let lastWriteAt else { return true }
        return now.timeIntervalSince(lastWriteAt) > staleAfter
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
        case .headline(let text), .note(let text):
            return text
        case .status(let label, let text, _):
            return "\(label): \(text)"
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
                            isInstalled: Bool = false,
                            lastWriteAt: Date? = nil) -> [MenuRow] {
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


        if s.fiveHour == nil && s.sevenDay == nil && s.extra.isEmpty {
            rows.append(.note("Needs a Claude Pro or Max subscription"))
            rows.append(.stat("", freshnessText(s, now: now, staleAfter: staleAfter, lastWriteAt: lastWriteAt)))
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

        // Status closes the same three-column block as the windows above it,
        // with freshness as its continuation line.
        if let service, service.isCurrent(at: now) {
            rows.append(.status("Status", service.summary, service.claudeCode))
        }
        rows.append(.stat("", freshnessText(s, now: now, staleAfter: staleAfter, lastWriteAt: lastWriteAt)))
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

    private static func freshnessText(_ s: Snapshot, now: Date, staleAfter: TimeInterval,
                                      lastWriteAt: Date?) -> String {
        if isStale(lastWriteAt: lastWriteAt ?? s.capturedAt, now: now, staleAfter: staleAfter) {
            let since = now.timeIntervalSince(lastWriteAt ?? s.capturedAt)
            return "Claude Code not running · \(Format.ago(since))"
        }
        // Running, but the sessions writing are idle ones carrying expired
        // windows, so the numbers themselves are older than the writes.
        let age = now.timeIntervalSince(s.capturedAt)
        return age > staleAfter ? "numbers from \(Format.ago(age))" : "updated \(Format.ago(age))"
    }
}
