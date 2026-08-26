import Foundation

func runMenuModelTests(_ t: Harness) {
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
    let now = Date(timeIntervalSince1970: 1_787_400_000)   // Sat 22 Aug 12:00 UTC
    let fmt = Formatting(timeZone: utc, calendar: cal, locale: Locale(identifier: "en_GB"))

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
    func rows(_ s: Snapshot?, service: ServiceStatus? = nil) -> [MenuRow] {
        MenuModel.rows(s, now: now, staleAfter: 90, formatting: fmt, service: service)
    }
    func bar(_ s: Snapshot?) -> BarContent { MenuModel.bar(s, now: now) }

    t.describe("bar — the number counts what the disc fills with")
    // The disc fills as you spend, so the number counts spend too: the two
    // halves of one item must move in the same direction.
    t.expect("reports usage, matching the mark", bar(snap(session: 8, week: 7)).weekUsed ?? -1, 7.0)
    t.expect("renders as a bare percentage", MenuModel.barText(bar(snap(session: 8, week: 7))), "7%")
    t.expect("glyph reads the same window and the same direction",
             MenuModel.markUsage(snap(session: 8, week: 7), now: now) ?? -1, 7.0)
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
    // The headline names its window; "Comfortable" alone says nothing about
    // which limit it means.
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
    t.expect("week states usage and pace", normal.contains(.stat("Week", "7% used · 43% under pace")), true)
    t.expect("week reset is a concrete time",
             normal.contains(.stat("", "resets \(fmt.when(now.addingTimeInterval(Metrics.weekLength * 0.5), now: now))")), true)
    t.expect("session states usage the same way", normal.contains(.stat("Session", "29% used")), true)
    t.expect("session reset gets its own line, like the week's",
             normal.contains(.stat("", "resets \(fmt.when(now.addingTimeInterval(5 * 3600), now: now))")), true)
    t.expect("freshness is the last word", normal.last, .stat("", "updated just now"))

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
             rows(old).contains(.stat("", "Claude Code not running · 1h ago")), true)
    t.expect("flags the reading", MenuModel.isStale(old, now: now, staleAfter: 90), true)
    t.expect("fresh readings are not stale",
             MenuModel.isStale(snap(session: 10, week: 7, age: 5), now: now, staleAfter: 90), false)

    t.describe("service health — quiet when everything is fine")
    // A row saying "all is well" every single day is noise. It stays, but small
    // and at the bottom, so you can see the watch is running without being told
    // something you already assumed.
    let healthy = rows(snap(session: 29, week: 7), service: ServiceStatus(claudeCode: .operational))
    t.expect("the headline still belongs to the week", healthy.first, .headline("Week on pace"))
    t.expect("status sits in the same block as the windows",
             healthy.contains(.status("Status", "Claude Code operational", .operational)), true)

    t.describe("service health — loud when it is not")
    // If Claude is down, your quota is beside the point. It takes the headline.
    let down = rows(snap(session: 29, week: 7), service: ServiceStatus(claudeCode: .outage))
    t.expect("an outage outranks every usage conclusion", down.first, .headline("Claude Code is down"))
    t.expect("and is repeated as a status row",
             down.contains(.status("Status", "Claude Code is down", .outage)), true)

    t.describe("service health — an outage outranks even a spent session")
    let both = rows(snap(session: 100, sessionResetsIn: 4320, week: 7),
                    service: ServiceStatus(claudeCode: .degraded))
    t.expect("degradation leads", both.first, .headline("Claude Code degraded"))

    t.describe("service health — no reading at all")
    // The status page being unreachable is our problem, not Anthropic's, and
    // is not worth a row.
    t.expect("says nothing when the check has not landed",
             rows(snap(session: 29, week: 7), service: nil)
                .contains(where: { if case .status = $0 { return true }; return false }), false)

    t.describe("accessibility — the bar reads as a sentence, not as digits")
    // VoiceOver on the status item announced only "12%", with no clue what the
    // number counts or that the disc beside it means anything.
    t.expect("names the app, the window and the direction",
             MenuModel.spoken(snap(session: 29, week: 12, weekElapsed: 0.1), now: now, formatting: fmt),
             "Ration. Week 12 percent used, 2 percent ahead of pace. Session 29 percent used.")
    t.expect("a spent session says when you are back",
             MenuModel.spoken(snap(session: 100, sessionResetsIn: 4320, week: 12, weekElapsed: 0.1),
                              now: now, formatting: fmt),
             "Ration. Week 12 percent used, 2 percent ahead of pace. "
             + "Session spent, back \(fmt.when(now.addingTimeInterval(4320), now: now)).")
    t.expect("no data says so rather than reading a dash",
             MenuModel.spoken(nil, now: now, formatting: fmt), "Ration. Not set up.")
    t.expect("a service problem is announced first",
             MenuModel.spoken(snap(session: 29, week: 12), now: now, formatting: fmt,
                              service: ServiceStatus(claudeCode: .outage)),
             "Ration. Claude Code is down. Week 12 percent used, 38 percent under pace. Session 29 percent used.")

    t.describe("accessibility — each row reads without its tab")
    // Rows are laid out with a tab stop, which VoiceOver reads as a gap.
    t.expect("label and value are joined into a phrase",
             MenuModel.spokenRow(.stat("Week", "12% used · on pace")), "Week: 12% used, on pace")
    t.expect("a continuation row carries no stray colon",
             MenuModel.spokenRow(.stat("", "resets Mon 01:00")), "resets Mon 01:00")
    t.expect("status rows say the level, so colour is never the only signal",
             MenuModel.spokenRow(.status("Status", "Claude Code operational", .operational)),
             "Status: Claude Code operational")

    t.describe("pace — no claim before the window has run")
    // The projection is suppressed below 1% elapsed, but the pace clause was
    // not: 3% burned in the first hour read "+3 ahead of pace" beneath a
    // headline of "Week on pace".
    let justStarted = rows(snap(session: 5, week: 3, weekElapsed: 0.005))
    t.expect("the row states usage only",
             justStarted.contains(.stat("Week", "3% used")), true)
    t.expect("and the headline makes no claim either",
             MenuModel.headline(snap(session: 5, week: 3, weekElapsed: 0.005),
                                now: now, formatting: fmt), "Week just started")

    t.describe("headline — model buckets are usage data")
    // "No usage data" appeared above rows listing real per-model percentages.
    let onlyBuckets = Snapshot(fiveHour: nil, sevenDay: nil,
                               extra: [NamedWindow(label: "Fable",
                                                   window: UsageWindow(usedPercentage: 12,
                                                                       resetsAt: now.addingTimeInterval(90_000)))],
                               capturedAt: now)
    t.expect("does not claim there is none",
             MenuModel.headline(onlyBuckets, now: now, formatting: fmt) != "No usage data", true)

    t.describe("service health — a reading that stopped refreshing goes quiet")
    // An outage seen just before going offline pinned the headline and, because
    // it short-circuits, suppressed the usage conclusion for as long as the
    // machine stayed offline.
    let staleOutage = ServiceStatus(claudeCode: .outage,
                                    checkedAt: now.addingTimeInterval(-ServiceStatus.maximumAge - 60))
    t.expect("it no longer takes the headline",
             MenuModel.headline(snap(session: 29, week: 12), now: now, formatting: fmt,
                                service: staleOutage),
             MenuModel.headline(snap(session: 29, week: 12), now: now, formatting: fmt))
    t.expect("and no status row is shown",
             rows(snap(session: 29, week: 12), service: staleOutage)
                .contains(where: { if case .status = $0 { return true }; return false }), false)
    t.expect("a fresh reading still speaks",
             MenuModel.headline(snap(session: 29, week: 12), now: now, formatting: fmt,
                                service: ServiceStatus(claudeCode: .outage, checkedAt: now)),
             "Claude Code is down")
}
