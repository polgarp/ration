import Foundation

func runFileFreshnessTests(_ t: Harness) {
    // URL.resourceValues(forKeys:) caches its answers on the URL instance, so a
    // long-lived URL keeps reporting the modification date it saw first. The
    // menu bar polls that date to decide whether to re-read the snapshot, so a
    // cached answer silently froze the whole app at its first reading.
    t.describe("modification date must not be cached")

    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ration-freshness-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let file = dir.appendingPathComponent("snapshot.json")
    try? Data("{}".utf8).write(to: file)
    let first = FileFreshness.modificationDate(of: file)
    t.expectNotNil("reads a date", first)

    // Push the file's timestamp forward rather than waiting for a clock tick.
    let later = Date().addingTimeInterval(60)
    try? FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: file.path)

    let second = FileFreshness.modificationDate(of: file)
    t.expect("sees the new date through the same URL",
             (second?.timeIntervalSince1970 ?? 0).rounded(), later.timeIntervalSince1970.rounded())
    t.expect("which is not the first answer", first != second, true)
}
