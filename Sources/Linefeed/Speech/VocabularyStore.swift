import AppKit
import LinefeedCore

@MainActor
final class VocabularyStore {
    let url = AppDirectory.support.appendingPathComponent(VocabularyFile.fileName)
    private var loadedAt: Date?
    private var cachedTerms: [VocabularyTerm] = []

    var terms: [VocabularyTerm] {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if modified != loadedAt {
            loadedAt = modified
            cachedTerms = (try? Data(contentsOf: url)).map(VocabularyFile.terms(from:)) ?? []
        }
        return cachedTerms
    }

    func openForEditing() throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(VocabularyFile.template.utf8).write(to: url, options: .atomic)
        }
        NSWorkspace.shared.open(url)
    }
}
