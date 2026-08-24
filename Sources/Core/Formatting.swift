import Foundation

/// Date rendering bound to a time zone and calendar.
///
/// Held as a value rather than read from `.current` per call so tests can pin a
/// zone. The formatters are built once: `DateFormatter` is expensive to create
/// and this runs on the menu bar's timer.
public struct Formatting {
    public let timeZone: TimeZone
    public let calendar: Calendar

    private let time: DateFormatter
    private let weekday: DateFormatter
    private let weekdayAndDate: DateFormatter

    public init(timeZone: TimeZone = .current, calendar: Calendar = .current) {
        self.timeZone = timeZone
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal

        func formatter(_ format: String) -> DateFormatter {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = timeZone
            f.dateFormat = format
            return f
        }
        time = formatter("HH:mm")
        weekday = formatter("EEE")
        weekdayAndDate = formatter("EEE d MMM")
    }

    /// A concrete moment, carrying only as much date as you need. A countdown
    /// makes you do arithmetic to answer "can I go to lunch?".
    public func when(_ date: Date, now: Date) -> String {
        let clock = time.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "today \(clock)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "tomorrow \(clock)" }
        // Inside a week the weekday alone locates it; beyond that it does not.
        let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        let prefix = days < 7 ? weekday.string(from: date) : weekdayAndDate.string(from: date)
        return "\(prefix) \(clock)"
    }

    public func clock(_ date: Date) -> String { time.string(from: date) }
}
