import Foundation

func runMenuModelTests(_ t: Harness) {
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
    let now = Date(timeIntervalSince1970: 1_787_400_000)   // Sat 22 Aug 12:00 UTC
    let fmt = Formatting(timeZone: utc, calendar: cal)

    func snap(session: Double?, sessionResetsIn: TimeInterval = 3600,
              week: Double?, weekElapsed: Double = 0.5,
              extra: [NamedWindow] = [], age: TimeInterval = 5) -> Snapshot {
        Snapshot(
            fiveHour: session.map {
                UsageWindow(usedPercentage: $0, resetsAt: now.addingTimeInterval(sessionResetsIn))
            },
            sevenDay: week.map {
                UsageWindow(usedPercentage: $0,
                            resetsAt: now.addingTimeInterval(Metrics.weekLength * (1 - weekElapsed)))
            },
            extra: extra,
            capturedAt: now.addingTimeInterval(-age))
    }
    func rows(_ s: Snapshot?) -> [MenuRow] {
        MenuModel.rows(s, now: now, staleAfter: 90, formatting: fmt)
    }
    func bar(_ s: Snapshot?) -> BarContent { MenuModel.bar(s, now: now) }

    t.describe("bar — the number counts what the disc fills with")
    // The disc fills as you spend, so the number must count spend too. Showing
    // remaining beside a fill-as-you-spend disc had the two halves moving in
    // opposite directions.
    t.expect("reports usage, matching the mark", bar(snap(session: 8, week: 7)).weekUsed ?? -1, 7.0)
    t.expect("renders as a bare percentage", MenuModel.barText(bar(snap(session: 8, week: 7))), "7%")
    t.expect("glyph reads the same window and the same direction",
             MenuModel.markUsage(snap(session: 8, week: 7)) ?? -1, 7.0)
    t.expect("nothing at all without data", bar(nil).isEmpty, true)
    t.expect("empty renders as a dash", MenuModel.barText(bar(nil)), "—")

    t.describe("bar — a spent session appends, never replaces")
    let locked = bar(snap(session: 100, sessionResetsIn: 4320, week: 7))
    t.expect("the week keeps its slot", locked.weekUsed ?? -1, 7.0)
    t.expect("with the countdown beside it", locked.backIn ?? -1, 4320)
    // A bare wall-clock time in the menu bar sits inches from the system clock
    // and reads as a duplicate of it, so the bar keeps a duration. The dropdown,
    // where the row is labelled, uses the concrete time.
    t.expect("rendered as a duration", MenuModel.barText(locked), "7% · 1h 12m")

    t.describe("headline — names its subject")
    // "Comfortable" alone left you asking: comfortable about what?
    t.expect("says which window is fine",
             MenuModel.headline(snap(session: 10, week: 41, weekElapsed: 0.5), now: now, formatting: fmt),
             "Week on pace")
    let hot = snap(session: 10, week: 84, weekElapsed: 0.69)
    let capsOut = Metrics.weeklyPace(hot.sevenDay!, now: now).capsOutAt!
    t.expect("names the window that will run out",
             MenuModel.headline(hot, now: now, formatting: fmt),
             "Week runs out \(fmt.when(capsOut, now: now))")
    t.expect("being locked out outranks everything",
             MenuModel.headline(snap(session: 100, sessionResetsIn: 4320, week: 20), now: now, formatting: fmt),
             "Session resumes \(fmt.when(now.addingTimeInterval(4320), now: now))")

    t.describe("rows — week and session share one structure")
    let normal = rows(snap(session: 29, sessionResetsIn: 5 * 3600, week: 7, weekElapsed: 0.5))
    t.expect("opens with the conclusion", normal.first, .headline("Week on pace"))
    t.expect("week states usage and pace", normal.contains(.stat("Week", "7% used · 43 under pace")), true)
    t.expect("week reset is a concrete time",
             normal.contains(.stat("", "resets \(fmt.when(now.addingTimeInterval(Metrics.weekLength * 0.5), now: now))")), true)
    t.expect("session states usage the same way", normal.contains(.stat("Session", "29% used")), true)
    t.expect("session reset gets its own line, like the week's",
             normal.contains(.stat("", "resets \(fmt.when(now.addingTimeInterval(5 * 3600), now: now))")), true)
    t.expect("freshness is the last word", normal.last, .note("Updated just now"))

    t.describe("rows — a spent session")
    let spent = rows(snap(session: 100, sessionResetsIn: 4320, week: 7))
    t.expect("says it is spent", spent.contains(.stat("Session", "spent")), true)
    t.expect("and when it comes back",
             spent.contains(.stat("", "resumes \(fmt.when(now.addingTimeInterval(4320), now: now))")), true)

    t.describe("rows — extra model buckets get the same structure")
    // Labels are server-supplied, so whatever arrives is rendered as-is.
    let fable = NamedWindow(label: "Fable",
                            window: UsageWindow(usedPercentage: 12, resetsAt: now.addingTimeInterval(200_000)))
    let withExtra = rows(snap(session: 29, week: 7, extra: [fable]))
    t.expect("the bucket appears under its server label",
             withExtra.contains(.stat("Fable", "12% used")), true)
    t.expect("with its own reset line",
             withExtra.contains(.stat("", "resets \(fmt.when(now.addingTimeInterval(200_000), now: now))")), true)

    t.describe("rows — nothing installed yet")
    t.expect("tells you what to do", rows(nil), [.headline("Not set up"),
                                                 .separator,
                                                 .note("Install the status line tap to start")])

    t.describe("rows — no rate limits in the payload")
    t.expect("names the actual requirement",
             rows(snap(session: nil, week: nil)).contains(.note("Needs a Claude Pro or Max subscription")), true)

    t.describe("rows — a window whose reset time has already passed")
    let rolled = Snapshot(fiveHour: UsageWindow(usedPercentage: 80, resetsAt: now.addingTimeInterval(-600)),
                          sevenDay: UsageWindow(usedPercentage: 82, resetsAt: now.addingTimeInterval(-3600)),
                          capturedAt: now)
    t.expect("says it is waiting rather than reporting a dead window",
             rows(rolled).contains(.stat("Week", "waiting for a fresh reading")), true)
    t.expect("and the bar has nothing honest to show", bar(rolled).isEmpty, true)

    t.describe("staleness")
    let old = snap(session: 10, week: 7, age: 3600)
    t.expect("says Claude Code is not running",
             rows(old).contains(.note("Claude Code not running · 1h ago")), true)
    t.expect("flags the reading", MenuModel.isStale(old, now: now, staleAfter: 90), true)
    t.expect("fresh readings are not stale",
             MenuModel.isStale(snap(session: 10, week: 7, age: 5), now: now, staleAfter: 90), false)
}
