import Foundation

/// Whether Claude itself is healthy, from the public Statuspage summary.
///
/// Answers the question "is it me or is it them?" — the one thing a usage
/// meter cannot tell you from usage alone. The endpoint is public and
/// unauthenticated: no cookie, no token, and nothing about the user is sent.
public struct ServiceStatus: Equatable {

    public enum Level: Equatable {
        case operational, degraded, outage, maintenance, unknown

        init(_ raw: String) {
            switch raw {
            case "operational":                              self = .operational
            case "degraded_performance", "partial_outage":   self = .degraded
            case "major_outage":                             self = .outage
            case "under_maintenance":                        self = .maintenance
            default:                                         self = .unknown
            }
        }
    }

    /// The component this app exists alongside. The page lists six; a wobble in
    /// Claude for Government is not a reason to alarm someone in a terminal.
    public static let componentOfInterest = "Claude Code"

    public let claudeCode: Level
    public let checkedAt: Date

    public var isNoteworthy: Bool {
        switch claudeCode {
        case .operational, .unknown: return false
        case .degraded, .outage, .maintenance: return true
        }
    }

    public var summary: String {
        switch claudeCode {
        case .operational:  return "Claude Code operational"
        case .degraded:     return "Claude Code degraded"
        case .outage:       return "Claude Code is down"
        case .maintenance:  return "Claude Code under maintenance"
        case .unknown:      return "Claude Code status unknown"
        }
    }

    public init(claudeCode: Level, checkedAt: Date = Date()) {
        self.claudeCode = claudeCode
        self.checkedAt = checkedAt
    }

    private struct Payload: Decodable {
        struct Component: Decodable { let name: String?; let status: String? }
        let components: [Component]?
    }

    public static func decode(_ data: Data, checkedAt: Date = Date()) -> ServiceStatus? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let components = payload.components,
              let component = components.first(where: { $0.name == componentOfInterest }),
              let raw = component.status
        else { return nil }
        return ServiceStatus(claudeCode: Level(raw), checkedAt: checkedAt)
    }
}
