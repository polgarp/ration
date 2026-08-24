import Foundation

public enum Format {

    /// Time remaining until a window resets. Precision drops as the number
    /// grows: minutes matter when a session is nearly gone, and nobody
    /// counts minutes two days out.
    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "now" }
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// Age of the current reading.
    public static func ago(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        if total < 60 { return "just now" }
        if total < 3600 { return "\(total / 60)m ago" }
        if total < 86400 { return "\(total / 3600)h ago" }
        return "\(total / 86400)d ago"
    }

    /// Whether the week is being burned faster than it is elapsing.
    ///
    /// The sign is carried explicitly when ahead, because "+15" reads as a
    /// warning while a bare "15" reads as a measurement.
    public static func pace(_ pace: WeeklyPace) -> String {
        let delta = pace.delta
        if abs(delta) < 1 { return "on pace" }
        if delta > 0 { return "+\(Int(delta.rounded())) ahead of pace" }
        return "\(Int((-delta).rounded())) under pace"
    }

    /// A weekday and time, for reset and cap-out moments.
    public static func dayAndTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "EEE HH:mm"
        return f.string(from: date)
    }
}
