import AppKit
import Observation

@MainActor
@Observable
final class HistoryModel {
    private(set) var sessions: [SavedSession] = []
    var selectedID: String?
    var query = ""
    private(set) var notice: String?
    @ObservationIgnored let store: SessionStore
    @ObservationIgnored private var noticeTask: Task<Void, Never>?

    init(store: SessionStore) {
        self.store = store
    }

    var filteredSessions: [SavedSession] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.manifest.searchableText.localizedCaseInsensitiveContains(query) }
    }

    var selectedSession: SavedSession? {
        let visible = filteredSessions
        return visible.first { $0.id == selectedID } ?? visible.first
    }

    func refresh() {
        sessions = store.sessions()
        if !sessions.contains(where: { $0.id == selectedID }) {
            selectedID = sessions.first?.id
        }
    }

    func copy(_ session: SavedSession) {
        let copied = Clipboard.copy(session)
        showNotice(copied ? (session.manifest.captures.isEmpty ? "Text copied" : "Text + screenshots copied") : "Nothing to copy")
    }

    func reveal(_ session: SavedSession) {
        NSWorkspace.shared.activateFileViewerSelecting([session.folder])
    }

    private func showNotice(_ message: String) {
        noticeTask?.cancel()
        notice = message
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
}
