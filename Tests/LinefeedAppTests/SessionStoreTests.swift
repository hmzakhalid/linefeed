import Foundation
import LinefeedCore
import Testing
@testable import Linefeed

@Suite("Session store")
@MainActor
struct SessionStoreTests {
    @Test("A saved session reads back with its transcript and timeline")
    func roundTrip() throws {
        let store = SessionStore(root: try temporaryFolder())
        defer { try? FileManager.default.removeItem(at: store.root) }

        let draft = try store.begin(microphone: "MacBook Microphone", model: "Accurate", language: "English", mode: .quick)
        draft.mode = .handsFree
        let saved = draft.session(with: transcript("Review the account page."))
        try store.save(saved)

        let loaded = try #require(store.latest())
        #expect(loaded.id == saved.id)
        #expect(loaded.manifest.transcript.text == "Review the account page.")
        #expect(loaded.manifest.recordingMode == RecordingMode.handsFree.title)
        #expect(FileManager.default.fileExists(atPath: loaded.folder.appendingPathComponent("context.md").path))
    }

    @Test("Newest sessions come first and unknown folders are ignored")
    func ordering() throws {
        let store = SessionStore(root: try temporaryFolder())
        defer { try? FileManager.default.removeItem(at: store.root) }
        try FileManager.default.createDirectory(at: store.root.appendingPathComponent("Notes"), withIntermediateDirectories: true)

        let first = try record("first", in: store)
        Thread.sleep(forTimeInterval: 1.1)
        let second = try record("second", in: store)

        #expect(store.sessions().map(\.id) == [second.id, first.id])
        try store.clear()
        #expect(store.sessions().isEmpty)
        #expect(FileManager.default.fileExists(atPath: store.root.appendingPathComponent("Notes").path))
    }

    @Test("Search finds sessions by what was said")
    func search() throws {
        let store = SessionStore(root: try temporaryFolder())
        defer { try? FileManager.default.removeItem(at: store.root) }
        _ = try record("Scroll to billing", in: store)
        let model = HistoryModel(store: store)
        model.refresh()

        model.query = "billing"
        #expect(model.filteredSessions.count == 1)
        model.query = "not present"
        #expect(model.filteredSessions.isEmpty)
    }

    @Test("Clearing History spares the session being recorded, and launch sweeps abandoned ones")
    func activeAndAbandoned() throws {
        let store = SessionStore(root: try temporaryFolder())
        defer { try? FileManager.default.removeItem(at: store.root) }
        _ = try record("kept until cleared", in: store)
        let recording = try store.begin(microphone: "", model: "", language: "", mode: .quick)

        try store.clear()
        #expect(FileManager.default.fileExists(atPath: recording.folder.path))
        #expect(store.sessions().isEmpty)

        let relaunched = SessionStore(root: store.root)
        relaunched.removeAbandonedDrafts()
        #expect(!FileManager.default.fileExists(atPath: recording.folder.path))
    }

    private func record(_ text: String, in store: SessionStore) throws -> SavedSession {
        let session = try store.begin(microphone: "", model: "", language: "", mode: .quick).session(with: transcript(text))
        try store.save(session)
        return session
    }

    private func transcript(_ text: String) -> TimedTranscript {
        TimedTranscript(text: text, rawText: text, duration: 2, words: [])
    }

    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("linefeed-history-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
