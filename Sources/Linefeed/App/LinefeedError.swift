import Foundation

/// What can go wrong; `RecordingReport` decides what to tell the person.
enum LinefeedError: Error {
    case speechNotReady
    case microphoneUnavailable
    case microphoneFailed(String)
    case screenRecordingOff
    case screenshotFailed
    case historyFull
}

enum AppDirectory {
    /// `~/Library/Application Support/Linefeed`, which never syncs to iCloud.
    static let support: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Linefeed", isDirectory: true)

    /// Holds a lock on a file in `support` for the life of the process.
    /// Returns `false` when another Linefeed already holds it, however it
    /// was launched.
    static func claimSingleInstance() -> Bool {
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let descriptor = open(support.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
        return descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0
    }
}
