import Foundation
import LinefeedCore

struct SavedSession: Identifiable, Equatable {
    let manifest: SessionManifest
    let folder: URL

    var id: String { manifest.id }

    var screenshotURLs: [URL] {
        manifest.captures.map(imageURL(for:))
    }

    func imageURL(for capture: SessionCaptureRecord) -> URL {
        folder.appendingPathComponent(capture.imageFilename)
    }
}

/// Owns the History folder: where sessions live, how they are named, and how
/// much room they may take.
@MainActor
final class SessionStore {
    static let budget = SessionBudget(maxBytes: 500_000_000)

    let root: URL
    /// Sessions still being recorded; pruning and clearing leave them alone.
    private var active: Set<String> = []

    init(root: URL = AppDirectory.support.appendingPathComponent("History", isDirectory: true)) {
        self.root = root
    }

    func begin(microphone: String, model: String, language: String, mode: RecordingMode) throws -> SessionDraft {
        try? prune()
        let startedAt = Date()
        let folder = root.appendingPathComponent(SessionFolderName.make(startedAt: startedAt), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        active.insert(folder.lastPathComponent)
        return SessionDraft(store: self, folder: folder, startedAt: startedAt, details: (microphone, model, language), mode: mode)
    }

    func save(_ session: SavedSession) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(session.manifest).write(to: session.folder.appendingPathComponent("session.json"), options: .atomic)
        try session.manifest.markdown.write(to: session.folder.appendingPathComponent("context.md"), atomically: true, encoding: .utf8)
        try? prune(keeping: session.folder.lastPathComponent)
        active.remove(session.folder.lastPathComponent)
    }

    fileprivate func discard(_ folder: URL) {
        active.remove(folder.lastPathComponent)
        try? FileManager.default.removeItem(at: folder)
    }

    /// Newest first.
    func sessions() -> [SavedSession] {
        folders().reversed().compactMap(load)
    }

    func latest() -> SavedSession? {
        for folder in folders().reversed() {
            if let session = load(folder) { return session }
        }
        return nil
    }

    func clear() throws {
        for folder in folders() where !active.contains(folder.lastPathComponent) {
            try FileManager.default.removeItem(at: folder)
        }
    }

    /// Folders left without a manifest by a recording that never finished.
    func removeAbandonedDrafts() {
        let manager = FileManager.default
        for folder in folders() where !active.contains(folder.lastPathComponent) {
            if !manager.fileExists(atPath: folder.appendingPathComponent("session.json").path) {
                try? manager.removeItem(at: folder)
            }
        }
    }

    var usedBytes: Int64 {
        folders().reduce(0) { $0 + Self.allocatedBytes(in: $1) }
    }

    /// Makes room by removing the oldest sessions; ones still being recorded,
    /// and `kept`, stay even when they alone exceed the budget.
    func prune(keeping kept: String? = nil) throws {
        let stored = folders().map { StoredSession(name: $0.lastPathComponent, bytes: Self.allocatedBytes(in: $0)) }
        for name in Self.budget.sessionsToRemove(from: stored, protecting: active.union([kept].compactMap { $0 })) {
            try FileManager.default.removeItem(at: root.appendingPathComponent(name, isDirectory: true))
        }
    }

    /// Session folders Linefeed created, oldest first.
    private func folders() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents
            .filter { SessionFolderName.isValid($0.lastPathComponent) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func load(_ folder: URL) -> SavedSession? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("session.json")) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(SessionManifest.self, from: data) else { return nil }
        return SavedSession(manifest: manifest, folder: folder)
    }

    static func allocatedBytes(in url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey]
        func size(of url: URL) -> Int64 {
            let values = try? url.resourceValues(forKeys: keys)
            return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        guard (try? url.resourceValues(forKeys: keys))?.isDirectory == true else { return size(of: url) }
        let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys))
        return (files?.allObjects ?? []).compactMap { $0 as? URL }.reduce(0) { $0 + size(of: $1) }
    }
}

@MainActor
final class SessionDraft {
    private struct Screenshot {
        let url: URL
        let offset: TimeInterval
    }

    private unowned let store: SessionStore
    let folder: URL
    private var startedAt: Date
    private var startedUptime = ProcessInfo.processInfo.systemUptime
    private var duration: TimeInterval?
    private let details: (microphone: String, model: String, language: String)
    var mode: RecordingMode
    private var screenshots: [Screenshot] = []
    private var bytes: Int64 = 0

    fileprivate init(
        store: SessionStore,
        folder: URL,
        startedAt: Date,
        details: (microphone: String, model: String, language: String),
        mode: RecordingMode
    ) {
        self.store = store
        self.folder = folder
        self.startedAt = startedAt
        self.details = details
        self.mode = mode
    }

    var screenshotURLs: [URL] { screenshots.map(\.url) }

    /// The audio clock starts when the microphone does, not when the folder was made.
    func markRecordingStarted() {
        startedAt = Date()
        startedUptime = ProcessInfo.processInfo.systemUptime
    }

    func markRecordingEnded() {
        duration = offset(at: ProcessInfo.processInfo.systemUptime)
    }

    func offset(at uptime: TimeInterval) -> TimeInterval {
        max(0, uptime - startedUptime)
    }

    /// Older sessions make room for this one; only a single session larger
    /// than all of History is refused.
    func addScreenshot(for gesture: CircleGesture, at uptime: TimeInterval) async throws -> URL {
        let url = folder.appendingPathComponent(String(format: "screenshot-%03d.png", screenshots.count + 1))
        try await ScreenshotCapture.capture(gesture: gesture, to: url)
        let added = SessionStore.allocatedBytes(in: url)
        guard SessionStore.budget.canStore(additionalBytes: added, usedBytes: bytes) else {
            try? FileManager.default.removeItem(at: url)
            throw LinefeedError.historyFull
        }
        bytes += added
        screenshots.append(Screenshot(url: url, offset: offset(at: uptime)))
        try? store.prune()
        return url
    }

    /// Keeps a recording that couldn't be transcribed, so nothing is lost.
    /// Returns whether it was kept.
    func keepAudio(_ audio: URL) -> Bool {
        (try? FileManager.default.moveItem(at: audio, to: folder.appendingPathComponent("recording.caf"))) != nil
    }

    func discard() {
        store.discard(folder)
    }

    func session(with transcript: TimedTranscript) -> SavedSession {
        let length = duration ?? max(0, transcript.duration)
        let manifest = SessionManifest(
            id: folder.lastPathComponent,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(length),
            duration: length,
            microphone: details.microphone,
            speechModel: details.model,
            language: details.language,
            recordingMode: mode.title,
            transcript: transcript,
            captures: screenshots.enumerated().map { index, screenshot in
                SessionCaptureRecord(
                    index: index + 1,
                    imageFilename: screenshot.url.lastPathComponent,
                    offset: screenshot.offset,
                    excerpt: ContextTimeline.excerpt(at: screenshot.offset, from: transcript.words)
                )
            }
        )
        return SavedSession(manifest: manifest, folder: folder)
    }
}
