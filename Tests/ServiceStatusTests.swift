import Foundation

func runServiceStatusTests(_ t: Harness) {
    func decode(_ name: String) -> ServiceStatus? {
        ServiceStatus.decode(fixture(name))
    }

    t.describe("ServiceStatus — everything is fine")
    let ok = decode("status-ok")
    t.expectNotNil("decodes the live summary endpoint", ok)
    t.expect("Claude Code is operational", ok?.claudeCode ?? .unknown, .operational)
    t.expect("nothing worth saying", ok?.isNoteworthy ?? true, false)

    t.describe("ServiceStatus — degraded")
    let degraded = decode("status-degraded")
    t.expect("reads the component, not just the banner",
             degraded?.claudeCode ?? .unknown, .degraded)
    t.expect("worth saying", degraded?.isNoteworthy ?? false, true)
    t.expect("names the component in the row", degraded?.summary ?? "", "Claude Code degraded")

    t.describe("ServiceStatus — outage")
    t.expect("major outage reads as an outage", decode("status-outage")?.claudeCode ?? .unknown, .outage)
    t.expect("and says so plainly", decode("status-outage")?.summary ?? "", "Claude Code is down")

    t.describe("ServiceStatus — the component we care about is Claude Code")
    // The page lists six components; a wobble in Claude for Government is not
    // a reason to alarm someone in a terminal.
    let othersBroken = ServiceStatus.decode(fixture("status-ok").replacingName("Claude for Government",
                                                                              status: "major_outage"))
    t.expect("an unrelated component does not raise an alarm",
             othersBroken?.isNoteworthy ?? true, false)

    t.describe("ServiceStatus — hostile input")
    t.expectNil("malformed JSON yields nothing", ServiceStatus.decode(Data("nonsense".utf8)))
    t.expectNil("an empty object yields nothing", ServiceStatus.decode(Data("{}".utf8)))
}

private extension Data {
    /// Rewrites one component's status, for building variants from a fixture.
    func replacingName(_ name: String, status: String) -> Data {
        guard var json = try? JSONSerialization.jsonObject(with: self) as? [String: Any],
              var components = json["components"] as? [[String: Any]] else { return self }
        for i in components.indices where components[i]["name"] as? String == name {
            components[i]["status"] = status
        }
        json["components"] = components
        return (try? JSONSerialization.data(withJSONObject: json)) ?? self
    }
}
