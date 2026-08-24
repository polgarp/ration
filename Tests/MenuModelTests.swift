import Foundation

func runMenuModelTests(_ t: Harness) {
    let now = Date(timeIntervalSince1970: 1_787_400_000)
    let weekEnd = Date(timeIntervalSince1970: 1_787_526_000)

    func snap(fiveHourUsed: Double?, sevenDayUsed: Double?, age: TimeInterval = 5) -> Snapshot {
        Snapshot(
            fiveHour: fiveHourUsed.map { UsageWindow(usedPercentage: $0, resetsAt: now.addingTimeInterval(3600)) },
            sevenDay: sevenDayUsed.map { UsageWindow(usedPercentage: $0, resetsAt: weekEnd) },
            capturedAt: now.addingTimeInterval(-age))
    }
    func rows(_ s: Snapshot?, age: TimeInterval = 5) -> [MenuRow] {
        MenuModel.rows(s, now: now, staleAfter: 90)
    }

    t.describe("MenuModel — the bar title")
    t.expect("shows what is left, not what is spent", MenuModel.barTitle(snap(fiveHourUsed: 8, sevenDayUsed: 1)), "92%")
    t.expect("no data reads as a dash, never as zero", MenuModel.barTitle(nil), "—")
    t.expect("a payload with no rate limits also reads as a dash",
             MenuModel.barTitle(snap(fiveHourUsed: nil, sevenDayUsed: nil)), "—")

    t.describe("MenuModel — before any data arrives")
    t.expect("says what it is waiting for", rows(nil), [.note("Waiting for Claude Code…"), .separator])

    t.describe("MenuModel — a normal reading")
    let normal = rows(snap(fiveHourUsed: 8, sevenDayUsed: 1))
    t.expect("opens with the session", normal.first, .heading("Session"))
    t.expect("session remaining", normal.contains(.detail("92% left")), true)
    t.expect("names the week", normal.contains(.heading("Week")), true)
    t.expect("week remaining", normal.contains(.detail("99% left")), true)
    t.expect("reports freshness", normal.contains(.note("Updated just now")), true)
    t.expect("no cap-out row when under pace",
             normal.contains(where: { if case .detail(let s) = $0 { return s.hasPrefix("caps out") }; return false }), false)

    t.describe("MenuModel — burning the week too fast")
    // 84% used against a week that is 69% elapsed.
    let hotWeek = Snapshot(
        fiveHour: UsageWindow(usedPercentage: 8, resetsAt: now.addingTimeInterval(3600)),
        sevenDay: UsageWindow(usedPercentage: 84,
                              resetsAt: now.addingTimeInterval(Metrics.weekLength * 0.31)),
        capturedAt: now)
    let hot = MenuModel.rows(hotWeek, now: now, staleAfter: 90)
    t.expect("states the pace", hot.contains(.detail("+15 ahead of pace")), true)
    t.expect("warns when the cap arrives before the reset",
             hot.contains(where: { if case .detail(let s) = $0 { return s.hasPrefix("caps out") }; return false }), true)

    t.describe("MenuModel — Claude Code not running")
    let old = rows(snap(fiveHourUsed: 8, sevenDayUsed: 1, age: 3600))
    t.expect("says so rather than presenting a leftover as live",
             old.contains(.note("Claude Code not running · 1h ago")), true)
}
