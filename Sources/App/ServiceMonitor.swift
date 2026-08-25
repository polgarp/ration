import Foundation

/// Polls Claude's public status page — the only network call Ration makes,
/// unauthenticated and carrying nothing about the user.
///
/// A failed check yields no status rather than a bad one: an unreachable status
/// page is our problem, not Anthropic's.
final class ServiceMonitor {

    private(set) var status: ServiceStatus?
    var onUpdate: (() -> Void)?

    /// The page a reader is sent to; the endpoint below is its JSON summary.
    static let statusPage = URL(string: "https://status.claude.com/")!

    private let url = URL(string: "https://status.claude.com/api/v2/summary.json")!
    /// Incidents are measured in minutes at best, and a public status page
    /// deserves polite traffic.
    private let interval: TimeInterval = 300
    private var timer: Timer?

    func start() {
        fetch()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.fetch() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func fetch() {
        var request = URLRequest(url: url, timeoutInterval: 10)
        // Identify the client, so the operators can see who is calling.
        request.setValue("Ration/0.1 (+https://github.com/polgarp/ration)",
                         forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            guard let data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let parsed = ServiceStatus.decode(data)
            else { return }   // Keep the previous reading rather than inventing one.
            DispatchQueue.main.async {
                self.status = parsed
                self.onUpdate?()
            }
        }.resume()
    }
}
