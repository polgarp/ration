import Foundation

/// Reads a file's modification date without caching.
///
/// `URL.resourceValues` memoises on the URL instance, so a long-lived URL keeps
/// reporting the first date it saw — which froze the app at its first reading.
/// `FileManager.attributesOfItem` stats the path each call.
public enum FileFreshness {
    public static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
