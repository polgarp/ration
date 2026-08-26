import Foundation

/// Every URL the app can open, in one place.
enum Links {
    static let repository = URL(string: "https://github.com/polgarp/ration")!
    static let statusPage = URL(string: "https://status.claude.com/")!
    static let statusSummary = URL(string: "https://status.claude.com/api/v2/summary.json")!

    /// Identifies the client to the status page's operators.
    static let userAgent = "Ration/0.1 (+\(repository.absoluteString))"
}
