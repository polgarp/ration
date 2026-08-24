import Foundation

/// Reads a file's modification date without caching.
///
/// `URL.resourceValues(forKeys:)` memoises its answers on the URL instance, so
/// a long-lived URL keeps reporting the date it saw the first time. The menu
/// bar polls this date every second to decide whether to re-read the snapshot,
/// and a cached answer froze the entire app at its first reading — it looked
/// like it was updating because the clock in the countdown kept ticking.
///
/// `FileManager.attributesOfItem` stats the path each call.
public enum FileFreshness {
    public static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
