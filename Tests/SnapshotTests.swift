import Foundation

func fixture(_ name: String) -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    return (try? Data(contentsOf: url)) ?? Data()
}

func decodeFixture(_ name: String) -> Snapshot? {
    Snapshot.decode(fixture(name), capturedAt: Date(timeIntervalSince1970: 1_787_400_000))
}

func runSnapshotTests(_ t: Harness) {
    t.describe("Snapshot — decoding a well-formed payload")
    let healthy = decodeFixture("healthy")
    t.expectNotNil("decodes", healthy)
    t.expect("reads the 5-hour percentage", healthy?.fiveHour?.usedPercentage ?? -1, 23.5)
    t.expect("reads the 7-day percentage", healthy?.sevenDay?.usedPercentage ?? -1, 41.2)
    t.expect("reads resets_at as a date",
             healthy?.fiveHour?.resetsAt ?? Date.distantPast,
             Date(timeIntervalSince1970: 1_787_356_800))

    t.describe("Snapshot — absent and partial rate limits")
    // The docs warn rate_limits appears only for Pro/Max, only after the first
    // API response, and that each window may be independently absent.
    t.expectNil("missing rate_limits yields no windows", decodeFixture("no-rate-limits")?.fiveHour)
    t.expectNil("explicitly null rate_limits yields no windows", decodeFixture("null-rate-limits")?.fiveHour)
    let partial = decodeFixture("five-hour-only")
    t.expectNotNil("a lone 5-hour window still decodes", partial?.fiveHour)
    t.expectNil("the absent 7-day window stays nil", partial?.sevenDay)

    t.describe("Snapshot — hostile input")
    t.expectNil("malformed JSON decodes to nothing", decodeFixture("malformed"))
    t.expectNotNil("an empty object is valid, just empty", decodeFixture("empty"))
    t.expectNil("...and carries no windows", decodeFixture("empty")?.fiveHour)

    t.describe("Snapshot — a real captured payload")
    // Real payloads carry fields the docs never mention (cost, fast_mode,
    // exceeds_200k_tokens). Decoding must not care.
    let live = decodeFixture("live-capture")
    t.expectNotNil("decodes a live capture", live)
    t.expectNotNil("with a 5-hour window", live?.fiveHour)
    t.expectNotNil("with a 7-day window", live?.sevenDay)

    t.describe("Snapshot — model-scoped and per-model buckets")
    // Undocumented but present: seven_day_opus / seven_day_sonnet, plus a
    // model_scoped list whose display_name is server-supplied ("e.g. 'Fable'").
    // Rendering whatever arrives, labelled however the server labels it, means
    // new buckets need no release.
    let scoped = decodeFixture("model-scoped")
    t.expect("keeps the two documented windows", scoped?.fiveHour?.usedPercentage ?? -1, 29.0)
    t.expect("picks up a per-model weekly bucket",
             scoped?.extra.first(where: { $0.label == "Opus" })?.window.usedPercentage ?? -1, 44.0)
    t.expect("picks up a server-labelled bucket",
             scoped?.extra.first(where: { $0.label == "Fable" }) != nil, true)
    // model_scoped reports a 0-1 fraction where the documented windows report 0-100.
    t.expect("converts the fraction to a percentage",
             scoped?.extra.first(where: { $0.label == "Fable" })?.window.usedPercentage ?? -1, 12.0)
    t.expect("parses an ISO reset time",
             scoped?.extra.first(where: { $0.label == "Fable" })?.window.resetsAt ?? Date.distantPast,
             Date(timeIntervalSince1970: 1787734800))

    // The precision of an undocumented field is not ours to assume: a formatter
    // that only accepts whole seconds drops the bucket without a word.
    let fractional = Snapshot.decode(Data(#"""
    {"rate_limits": {"model_scoped": [
        {"display_name": "Fable", "utilization": 0.12,
         "resets_at": "2026-08-26T09:00:00.000Z"}]}}
    """#.utf8), capturedAt: Date(timeIntervalSince1970: 1_787_400_000))
    t.expect("an ISO reset time with fractional seconds still parses",
             fractional?.extra.first?.window.resetsAt ?? Date.distantPast,
             Date(timeIntervalSince1970: 1787734800))

    t.describe("Snapshot — payloads without extras")
    t.expect("no buckets is simply an empty list", decodeFixture("healthy")?.extra.count ?? -1, 0)
}
