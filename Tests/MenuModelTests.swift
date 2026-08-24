import Foundation

func runMenuModelTests(_ t: Harness) {
    let now = Date(timeIntervalSince1970: 1_787_400_000)

    /// A snapshot whose week is `weekElapsed` of the way through, so pace is controllable.
    func snap(session: Double?, sessionResetsIn: TimeInterval = 3600,
              week: Double?, weekElapsed: Double = 0.5,
              age: TimeInterval = 5) -> Snapshot {
        Snapshot(
            fiveHour: session.map {
                UsageWindow(usedPercentage: $0, resetsAt: now.addingTimeInterval(sessionResetsIn))
            },
            sevenDay: week.map {
                UsageWindow(usedPercentage: $0,
                            resetsAt: now.addingTimeInterval(Metrics.weekLength * (1 - weekElapsed)))
            },
            capturedAt: now.addingTimeInterval(-age))
    }
    func rows(_ s: Snapshot?) -> [MenuRow] { MenuModel.rows(s, now: now, staleAfter: 90) }
    func bar(_ s: Snapshot?) -> BarContent { MenuModel.bar(s, now: now) }
    func weekReset(_ elapsed: Double) -> String {
        Format.dayAndTime(now.addingTimeInterval(Metrics.weekLength * (1 - elapsed)))
    }

    // MARK: The bar

    t.describe("bar — the week owns the slot")
    // The status line already shows session usage while you work, so the menu
    // bar spends its one number on the week, which nothing else reports.
    t.expect("shows week remaining, not session", bar(snap(session: 8, week: 59)), .weekRemaining(41))
    t.expect("nothing to show without data", bar(nil), .none)
    t.expect("nothing to show without rate limits", bar(snap(session: nil, week: nil)), .none)

    t.describe("bar — the countdown takes over when the session is spent")
    // Being rate-limited is the moment the menu bar matters most, and it is
    // also the moment Claude Code is closed and the reading is going stale.
    t.expect("a spent session replaces the percentage with time until you are back",
             bar(snap(session: 100, sessionResetsIn: 4320, week: 59)), .backIn(4320))
    t.expect("still the week while the session has room",
             bar(snap(session: 90, week: 59)), .weekRemaining(41))

    t.describe("bar — the glyph and the number must agree")
    // Both halves report the same window. A disc drawn from the week beside a
    // session percentage was actively misleading.
    t.expect("glyph reads the week", MenuModel.markUsage(snap(session: 8, week: 59)) ?? -1, 59.0)
    t.expect("glyph still reads the week when the countdown is showing",
             MenuModel.markUsage(snap(session: 100, week: 59)) ?? -1, 59.0)

    // MARK: The headline

    t.describe("headline — a conclusion, not another number")
    t.expect("being locked out outranks everything",
             MenuModel.headline(snap(session: 100, sessionResetsIn: 4320, week: 20), now: now),
             "Back at \(Format.clock(now.addingTimeInterval(4320)))")

    // Note there is no separate "ahead of pace" headline: used > elapsed
    // implies projected > 100 by construction, so being ahead of pace and
    // being on course to run out are the same state, and the date is the more
    // useful way to say it.
    let hot = snap(session: 10, week: 84, weekElapsed: 0.69)
    let hotCapsOut = Metrics.weeklyPace(hot.sevenDay!, now: now).capsOutAt!
    t.expect("a week on course to run out names when",
             MenuModel.headline(hot, now: now), "Runs out \(Format.dayAndTime(hotCapsOut))")
    t.expect("under pace is simply comfortable",
             MenuModel.headline(snap(session: 10, week: 41, weekElapsed: 0.5), now: now), "Comfortable")

    // MARK: The rows

    t.describe("rows — every line earning its place")
    let normal = rows(snap(session: 10, week: 59, weekElapsed: 0.68))
    t.expect("opens with the conclusion", normal.first, .headline("Comfortable"))
    t.expect("week carries remaining and pace on one line",
             normal.contains(.stat("Week", "41% left · 9 under pace")), true)
    t.expect("week reset continues under it",
             normal.contains(.stat("", "resets \(weekReset(0.68))")), true)
    t.expect("session is demoted to a single line",
             normal.contains(.stat("Session", "90% left · resets in 1h 0m")), true)
    t.expect("freshness is the last word", normal.last, .note("Updated just now"))
    t.expect("and that is all of it", normal.count, 7)

    t.describe("rows — a spent session says when you are back")
    let spent = rows(snap(session: 100, sessionResetsIn: 4320, week: 59, weekElapsed: 0.68))
    t.expect("session line names the return",
             spent.contains(.stat("Session", "spent · back in 1h 12m")), true)

    // MARK: Absence

    t.describe("rows — nothing installed yet")
    // Not a progress note: nothing is in flight. It is a setup instruction.
    t.expect("tells you what to do", rows(nil), [.headline("Not set up"),
                                                 .separator,
                                                 .note("Install the status line tap to start")])

    t.describe("rows — no rate limits in the payload")
    t.expect("names the actual requirement",
             rows(snap(session: nil, week: nil)).contains(.note("Needs a Claude Pro or Max subscription")), true)

    // MARK: Staleness

    // Caught against live data, not fixtures: Claude Code can serve a payload
    // whose resets_at has already passed, because rate_limits only refresh
    // after a new API response. The window has rolled; the percentages describe
    // a window that no longer exists.
    t.describe("rows — a window whose reset time has already passed")
    let rolled = Snapshot(
        fiveHour: UsageWindow(usedPercentage: 80, resetsAt: now.addingTimeInterval(-600)),
        sevenDay: UsageWindow(usedPercentage: 82, resetsAt: now.addingTimeInterval(-3600)),
        capturedAt: now)
    t.expect("says it is waiting rather than reporting a dead window",
             rows(rolled).contains(.stat("Week", "waiting for a fresh reading")), true)
    t.expect("same for the session",
             rows(rolled).contains(.stat("Session", "waiting for a fresh reading")), true)
    t.expect("never phrases a countdown as \"resets in now\"",
             rows(rolled).contains(where: { if case .stat(_, let v) = $0 { return v.contains("in now") }; return false }), false)
    t.expect("no pace claim from a window that has ended",
             MenuModel.headline(rolled, now: now), "Waiting for a fresh reading")
    t.expect("and the bar has nothing honest to show", bar(rolled), .none)

    t.describe("staleness — the percentages rot, the reset time does not")
    let old = snap(session: 10, week: 59, weekElapsed: 0.68, age: 3600)
    t.expect("says Claude Code is not running",
             rows(old).contains(.note("Claude Code not running · 1h ago")), true)
    t.expect("flags the reading so percentages can be dimmed",
             MenuModel.isStale(old, now: now, staleAfter: 90), true)
    t.expect("fresh readings are not stale",
             MenuModel.isStale(snap(session: 10, week: 59, age: 5), now: now, staleAfter: 90), false)
}
