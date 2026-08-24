import Foundation

// A week ending at a known instant, so "now" can be placed precisely inside it.
let weekEnd = Date(timeIntervalSince1970: 1_787_526_000)   // Mon 24 Aug 01:00
let weekStart = weekEnd.addingTimeInterval(-Metrics.weekLength)

/// A date the given fraction of the way through that week.
func at(_ fraction: Double) -> Date {
    weekStart.addingTimeInterval(Metrics.weekLength * fraction)
}

func runMetricsTests(_ t: Harness) {
    t.describe("weeklyPace — elapsed time")
    let p = Metrics.weeklyPace(UsageWindow(usedPercentage: 0, resetsAt: weekEnd), now: at(0.5))
    t.expect("halfway through the week is 50% elapsed", p.elapsedPercentage, 50.0)
    t.expect("a fresh window is 0% elapsed",
             Metrics.weeklyPace(UsageWindow(usedPercentage: 0, resetsAt: weekEnd), now: at(0)).elapsedPercentage, 0.0)

    t.describe("weeklyPace — pace delta")
    // Peter's real numbers on 2026-08-21: 84% used, 69% of the week gone.
    let hot = Metrics.weeklyPace(UsageWindow(usedPercentage: 84, resetsAt: weekEnd), now: at(0.69))
    t.expect("used percentage passes through", hot.usedPercentage, 84.0)
    t.expect("burning faster than the clock gives a positive delta", hot.delta, 15.0)

    let cool = Metrics.weeklyPace(UsageWindow(usedPercentage: 20, resetsAt: weekEnd), now: at(0.5))
    t.expect("burning slower than the clock gives a negative delta", cool.delta, -30.0)

    t.describe("weeklyPace — projection")
    t.expect("projects the whole week from the burn so far", hot.projectedEndOfWeek ?? -1, 121.74)
    t.expect("under-pace projects below 100", cool.projectedEndOfWeek ?? -1, 40.0)

    // Dividing by a near-zero elapsed fraction produces a meaningless number,
    // so the first minutes of a window must project nothing at all.
    let brandNew = Metrics.weeklyPace(UsageWindow(usedPercentage: 0.5, resetsAt: weekEnd), now: at(0.001))
    t.expectNil("no projection in the opening minutes of a window", brandNew.projectedEndOfWeek)

    t.describe("weeklyPace — capping out")
    t.expectNil("under pace never caps out", cool.capsOutAt)
    t.expectNotNil("over pace caps out", hot.capsOutAt)
    t.expect("caps out at the moment the burn line crosses 100%",
             hot.capsOutAt ?? Date.distantPast,
             Date(timeIntervalSince1970: 1_787_418_000))
    t.expectNil("no cap-out date without a projection", brandNew.capsOutAt)

    t.describe("weeklyPace — one threshold for over pace")
    // "on pace" used |delta| < 1 while the cap-out headline triggered on any
    // delta > 0, so a delta of 0.5 produced a dropdown that said "on pace" and
    // a headline that said the week runs out on Sunday.
    let marginal = Metrics.weeklyPace(UsageWindow(usedPercentage: 50.5, resetsAt: weekEnd), now: at(0.5))
    t.expect("half a point ahead is not over pace", marginal.isOverPace, false)
    t.expect("and claims no cap-out date", marginal.capsOutAt == nil, true)
    t.expect("Format agrees it is on pace", Format.pace(marginal), "on pace")

    let clearlyOver = Metrics.weeklyPace(UsageWindow(usedPercentage: 60, resetsAt: weekEnd), now: at(0.5))
    t.expect("ten points ahead is over pace", clearlyOver.isOverPace, true)
    t.expect("and does claim a cap-out date", clearlyOver.capsOutAt != nil, true)
}
