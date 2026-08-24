import Foundation

/// Date rendering bound to a time zone and calendar.
///
/// Held as a value rather than read from `.current` inside each call so tests
/// can pin a zone and produce the same strings wherever they run.
public struct Formatting {
    public let timeZone: TimeZone
    public let calendar: Calendar

    public init(timeZone: TimeZone = .current, calendar: Calendar = .current) {
        self.timeZone = timeZone
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal
    }

    /// A concrete moment, carrying only as much date as you actually need.
    ///
    /// "resets in 4h 4m" makes you do arithmetic to answer "can I go to lunch?".
    /// A wall-clock time answers it directly.
    public func when(_ date: Date, now: Date) -> String {
        let time = clock(date)
        if calendar.isDate(date, inSameDayAs: now) { return "today \(time)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "tomorrow \(time)" }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        // Inside a week the weekday alone locates it; beyond that it does not.
        let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        f.dateFormat = days < 7 ? "EEE" : "EEE d MMM"
        return "\(f.string(from: date)) \(time)"
    }

    public func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
