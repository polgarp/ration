import Foundation

/// Date rendering bound to a time zone, calendar and locale.
///
/// Held as a value rather than read from `.current` per call so tests can pin
/// all three. The formatters are built once: `DateFormatter` is expensive to
/// create and this runs on the menu bar's timer.
public struct Formatting {
    public let timeZone: TimeZone
    public let calendar: Calendar
    public let locale: Locale

    private let time: DateFormatter
    private let weekday: DateFormatter
    private let weekdayAndDate: DateFormatter

    public init(timeZone: TimeZone = .current,
                calendar: Calendar = .current,
                locale: Locale = .autoupdatingCurrent) {
        self.timeZone = timeZone
        self.locale = locale
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal

        func formatter(_ configure: (DateFormatter) -> Void) -> DateFormatter {
            let f = DateFormatter()
            f.locale = locale
            f.timeZone = timeZone
            configure(f)
            return f
        }
        // A short time style follows the System Settings 24-hour switch; a
        // hardcoded "HH:mm" shows 17:50 to someone whose Mac says 5:50 PM.
        time = formatter { $0.timeStyle = .short; $0.dateStyle = .none }
        // Templates rather than literal patterns, so day and month order follow
        // the locale too.
        weekday = formatter { $0.setLocalizedDateFormatFromTemplate("EEE") }
        weekdayAndDate = formatter { $0.setLocalizedDateFormatFromTemplate("EEEdMMM") }
    }

    /// A concrete moment, carrying only as much date as you need. A countdown
    /// makes you do arithmetic to answer "can I go to lunch?".
    public func when(_ date: Date, now: Date) -> String {
        let clock = time.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "today \(clock)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "tomorrow \(clock)" }
        // A weekday alone locates a date only while it is unambiguous. A weekly
        // window is exactly 7 days, so the next reset is ~6d23h out for the day
        // after every reset, and its weekday is today's.
        let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        let prefix = days < 6 ? weekday.string(from: date) : weekdayAndDate.string(from: date)
        return "\(prefix) \(clock)"
    }

    public func clock(_ date: Date) -> String { time.string(from: date) }
}
