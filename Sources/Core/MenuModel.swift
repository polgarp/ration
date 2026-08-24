import Foundation

public enum MenuRow: Equatable {
    case heading(String)
    case detail(String)
    case note(String)
    case separator
}

/// Everything the dropdown says, as data.
///
/// Kept free of AppKit so the wording can be tested and dumped without
/// clicking a menu open — which is also how the state fixtures get compared.
public enum MenuModel {

    /// The menu bar shows what is left, not what is spent: the number you act
    /// on is your remaining headroom.
    public static func barTitle(_ snapshot: Snapshot?) -> String {
        guard let used = snapshot?.fiveHour?.usedPercentage else { return "—" }
        return "\(Int(max(0, 100 - used).rounded()))%"
    }

    public static func rows(_ snapshot: Snapshot?, now: Date, staleAfter: TimeInterval) -> [MenuRow] {
        guard let snapshot else {
            return [.note("Waiting for Claude Code…"), .separator]
        }

        var rows: [MenuRow] = []

        if let fiveHour = snapshot.fiveHour {
            rows.append(.heading("Session"))
            rows.append(.detail("\(Int(max(0, 100 - fiveHour.usedPercentage).rounded()))% left"))
            rows.append(.detail("resets in \(Format.duration(fiveHour.resetsAt.timeIntervalSince(now)))"))
        } else {
            rows.append(.note("No usage data yet"))
        }

        if let sevenDay = snapshot.sevenDay {
            let pace = Metrics.weeklyPace(sevenDay, now: now)
            rows.append(.separator)
            rows.append(.heading("Week"))
            rows.append(.detail("\(Int(max(0, 100 - sevenDay.usedPercentage).rounded()))% left"))
            rows.append(.detail(Format.pace(pace)))
            if let capsOut = pace.capsOutAt {
                rows.append(.detail("caps out \(Format.dayAndTime(capsOut))"))
            }
            rows.append(.detail("resets \(Format.dayAndTime(sevenDay.resetsAt))"))
        }

        let age = now.timeIntervalSince(snapshot.capturedAt)
        rows.append(.separator)
        rows.append(.note(age > staleAfter
            ? "Claude Code not running · \(Format.ago(age))"
            : "Updated \(Format.ago(age))"))
        rows.append(.separator)

        return rows
    }
}
