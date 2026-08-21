import Foundation

// Minimal test harness. XCTest is unavailable with Command Line Tools only
// (`swift test` fails with "XCTest not available"), and requiring a 10GB Xcode
// install to run four assertions would be a poor trade for contributors. This
// is enough: named checks, a tolerance for doubles, a non-zero exit on failure.

final class Harness {
    private var passes = 0
    private var failures = 0
    private var group = ""

    func describe(_ name: String) {
        group = name
        print("\n\(name)")
    }

    func expect<T: Equatable>(_ label: String, _ actual: T, _ expected: T) {
        if actual == expected { ok(label) } else { no(label, "\(expected)", "\(actual)") }
    }

    func expect(_ label: String, _ actual: Double, _ expected: Double, tolerance: Double = 0.01) {
        if abs(actual - expected) <= tolerance { ok(label) }
        else { no(label, "\(expected) ±\(tolerance)", "\(actual)") }
    }

    func expectNil<T>(_ label: String, _ actual: T?) {
        if actual == nil { ok(label) } else { no(label, "nil", "\(actual!)") }
    }

    func expectNotNil<T>(_ label: String, _ actual: T?) {
        if actual != nil { ok(label) } else { no(label, "non-nil", "nil") }
    }

    private func ok(_ label: String) {
        passes += 1
        print("  \u{1B}[32mPASS\u{1B}[0m  \(label)")
    }

    private func no(_ label: String, _ expected: String, _ actual: String) {
        failures += 1
        print("  \u{1B}[31mFAIL\u{1B}[0m  \(label)")
        print("        expected \(expected)")
        print("        actual   \(actual)")
    }

    func finish() -> Never {
        print("\n\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
