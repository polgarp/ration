import Foundation

func runFormatTests(_ t: Harness) {
    t.describe("Format.duration — time until a reset")
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
             Format.pace(paceAt(used: 84, fraction: 0.69)), "+15 ahead of pace")
    t.expect("under pace drops the sign and says under",
             Format.pace(paceAt(used: 20, fraction: 0.50)), "30 under pace")
    t.expect("within a point either way is simply on pace",
             Format.pace(paceAt(used: 50, fraction: 0.50)), "on pace")
}
