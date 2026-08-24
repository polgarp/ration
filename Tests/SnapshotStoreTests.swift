import Foundation

func runSnapshotStoreTests(_ t: Harness) {
    let now = Date(timeIntervalSince1970: 1_787_400_000)
    func w(_ used: Double, resetsIn: TimeInterval) -> UsageWindow {
        UsageWindow(usedPercentage: used, resetsAt: now.addingTimeInterval(resetsIn))
    }

    t.describe("SnapshotStore — an idle session cannot drag the data backwards")
    // Every Claude Code session runs the tap and writes the same file, but
    // rate_limits only refresh after an API response. A session idle since last
    // week broadcasts last week's window every 10 seconds. Windows only ever
    // move forward, so resets_at works as a version number.
    var store = SnapshotStore()
    store.accept(Snapshot(fiveHour: w(20, resetsIn: 3600),
                          sevenDay: w(7, resetsIn: 500_000), capturedAt: now))
    store.accept(Snapshot(fiveHour: w(80, resetsIn: -200_000),
                          sevenDay: w(82, resetsIn: -60_000), capturedAt: now.addingTimeInterval(10)))
    t.expect("keeps the current session window", store.best?.fiveHour?.usedPercentage ?? -1, 20.0)
    t.expect("keeps the current week window", store.best?.sevenDay?.usedPercentage ?? -1, 7.0)

    t.describe("SnapshotStore — a genuine reset is newer, so it is accepted")
    var rolling = SnapshotStore()
    rolling.accept(Snapshot(fiveHour: w(96, resetsIn: 60), sevenDay: nil, capturedAt: now))
    rolling.accept(Snapshot(fiveHour: w(3, resetsIn: 18_000), sevenDay: nil,
                            capturedAt: now.addingTimeInterval(70)))
    t.expect("the new window replaces the old", rolling.best?.fiveHour?.usedPercentage ?? -1, 3.0)

    t.describe("SnapshotStore — the same window takes the freshest write")
    var same = SnapshotStore()
    same.accept(Snapshot(fiveHour: w(20, resetsIn: 3600), sevenDay: nil, capturedAt: now))
    same.accept(Snapshot(fiveHour: w(35, resetsIn: 3600), sevenDay: nil,
                         capturedAt: now.addingTimeInterval(10)))
    t.expect("usage moves on within a window", same.best?.fiveHour?.usedPercentage ?? -1, 35.0)

    t.describe("SnapshotStore — an idle session cannot drag the same window backwards")
    // The weekly window resets on a fixed boundary, so every session reports
    // the same resets_at for a whole week: an idle session's write is a tie,
    // not an older window. Handing ties to whoever wrote last let it replay a
    // week-old percentage and the bar flickered between the two readings.
    var tied = SnapshotStore()
    tied.accept(Snapshot(fiveHour: nil, sevenDay: w(85, resetsIn: 500_000), capturedAt: now))
    tied.accept(Snapshot(fiveHour: nil, sevenDay: w(20, resetsIn: 500_000),
                         capturedAt: now.addingTimeInterval(10)))
    t.expect("a stale replay of the current week is ignored",
             tied.best?.sevenDay?.usedPercentage ?? -1, 85.0)
    t.expect("but it still counts as a live report of that window",
             tied.best?.capturedAt ?? Date.distantPast, now.addingTimeInterval(10))

    t.describe("SnapshotStore — windows are judged independently")
    // One session can hold a current week but a stale session window.
    var mixed = SnapshotStore()
    mixed.accept(Snapshot(fiveHour: w(20, resetsIn: 3600), sevenDay: w(7, resetsIn: 500_000), capturedAt: now))
    mixed.accept(Snapshot(fiveHour: w(90, resetsIn: -100), sevenDay: w(9, resetsIn: 500_000),
                          capturedAt: now.addingTimeInterval(10)))
    t.expect("stale session window rejected", mixed.best?.fiveHour?.usedPercentage ?? -1, 20.0)
    t.expect("current week window accepted", mixed.best?.sevenDay?.usedPercentage ?? -1, 9.0)

    t.describe("SnapshotStore — freshness follows accepted data, not writes")
    // A rejected write means nothing new was learned, so the reading must be
    // allowed to go stale even though a process is still writing every 10s.
    var ageing = SnapshotStore()
    ageing.accept(Snapshot(fiveHour: w(20, resetsIn: 3600), sevenDay: nil, capturedAt: now))
    ageing.accept(Snapshot(fiveHour: w(80, resetsIn: -200_000), sevenDay: nil,
                           capturedAt: now.addingTimeInterval(3600)))
    t.expect("capture time does not advance on a rejected write",
             ageing.best?.capturedAt ?? Date.distantPast, now)

    t.describe("SnapshotStore — first write is always accepted")
    var fresh = SnapshotStore()
    t.expectNil("empty to begin with", fresh.best)
    fresh.accept(Snapshot(fiveHour: w(20, resetsIn: 3600), sevenDay: nil, capturedAt: now))
    t.expectNotNil("populated after one write", fresh.best)

    t.describe("SnapshotStore — extra buckets follow the same rule")
    var buckets = SnapshotStore()
    let fresh1 = NamedWindow(label: "Fable", window: w(12, resetsIn: 200_000))
    let stale1 = NamedWindow(label: "Fable", window: w(80, resetsIn: -200_000))
    buckets.accept(Snapshot(fiveHour: nil, sevenDay: nil, extra: [fresh1], capturedAt: now))
    buckets.accept(Snapshot(fiveHour: nil, sevenDay: nil, extra: [stale1],
                            capturedAt: now.addingTimeInterval(10)))
    t.expect("an idle session cannot drag a bucket backwards",
             buckets.best?.extra.first?.window.usedPercentage ?? -1, 12.0)

    t.describe("SnapshotStore — a bucket seen only once is kept")
    var appearing = SnapshotStore()
    appearing.accept(Snapshot(fiveHour: w(20, resetsIn: 3600), sevenDay: nil, capturedAt: now))
    appearing.accept(Snapshot(fiveHour: w(25, resetsIn: 3600), sevenDay: nil,
                              extra: [fresh1], capturedAt: now.addingTimeInterval(10)))
    t.expect("a newly-appearing bucket is adopted", appearing.best?.extra.count ?? -1, 1)
}
