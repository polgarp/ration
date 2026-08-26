import Foundation

func runFormatTests(_ t: Harness) {
    t.describe("Format.duration — time until a reset")
    // Under a minute the app is counting you back in, and "0m" is useless there.
    t.expect("seconds when the reset is imminent", Format.duration(45), "45s")
    t.expect("minutes only, under an hour", Format.duration(11 * 60), "11m")
    t.expect("hours and minutes", Format.duration(4 * 3600 + 21 * 60), "4h 21m")
    t.expect("drops minutes past a day, where they stop mattering",
             Format.duration(2 * 86400 + 3 * 3600 + 40 * 60), "2d 3h")
    t.expect("a passed deadline reads as now, never negative", Format.duration(-500), "now")

    t.describe("Format.ago — how old the reading is")
    t.expect("seconds are just now", Format.ago(9), "just now")
    t.expect("minutes", Format.ago(4 * 60 + 30), "4m ago")
    t.expect("hours", Format.ago(3 * 3600), "3h ago")

    t.describe("Format.pace — the differentiating line")
    let weekEnd = Date(timeIntervalSince1970: 1_787_526_000)
    func paceAt(used: Double, fraction: Double) -> WeeklyPace {
        Metrics.weeklyPace(UsageWindow(usedPercentage: used, resetsAt: weekEnd),
                           now: weekEnd.addingTimeInterval(-Metrics.weekLength * (1 - fraction)))
    }
    t.expect("ahead of pace is signed, because the sign is the point",
             Format.pace(paceAt(used: 84, fraction: 0.69)), "+15% ahead of pace")
    t.expect("under pace drops the sign and says under",
             Format.pace(paceAt(used: 20, fraction: 0.50)), "30% under pace")
    t.expect("within a point either way is simply on pace",
             Format.pace(paceAt(used: 50, fraction: 0.50)), "on pace")

    t.describe("Formatting.when — a concrete time, not a countdown")
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
    let fmt = Formatting(timeZone: utc, calendar: cal, locale: Locale(identifier: "en_GB"))
    let base = Date(timeIntervalSince1970: 1_787_400_000)   // Sat 22 Aug 12:00 UTC
    func when(_ offset: TimeInterval) -> String { fmt.when(base.addingTimeInterval(offset), now: base) }
    t.expect("later today needs no date", when(5 * 3600), "today 17:00")
    t.expect("tomorrow says tomorrow", when(20 * 3600), "tomorrow 08:00")
    t.expect("within the week names the day", when(3 * 86400), "Tue 12:00")
    t.expect("further out names the date", when(9 * 86400), "Mon, 31 Aug 12:00")
    // A weekly window is exactly 7 days, so for the first day after every reset
    // the next one is ~6d23h away. A bare weekday then matches today's, and
    // "resets Sat 12:00" on a Saturday reads as an hour ago.
    t.expect("almost a week out is dated, not just named",
             when(7 * 86400 - 60), "Sat, 29 Aug 11:59")

    t.describe("Formatting — clock format follows the Mac's setting")
    // A hardcoded HH:mm shows 17:00 to someone whose Mac is set to 12-hour.
    let noon = Date(timeIntervalSince1970: 1_787_400_000)   // 12:00 UTC
    let evening = noon.addingTimeInterval(5 * 3600)
    func at(_ id: String) -> String {
        Formatting(timeZone: utc, calendar: cal, locale: Locale(identifier: id)).clock(evening)
    }
    t.expect("24-hour locale", at("en_GB"), "17:00")
    // macOS separates the time from AM/PM with a narrow no-break space, which
    // is an OS detail rather than something to pin down.
    let twelve = at("en_US")
    t.expect("12-hour locale keeps the hour", twelve.hasPrefix("5:00"), true)
    t.expect("12-hour locale marks the meridiem", twelve.hasSuffix("PM"), true)
}
