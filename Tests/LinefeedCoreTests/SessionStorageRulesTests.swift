import Foundation
import Testing
@testable import LinefeedCore

@Suite("Session storage rules")
struct SessionStorageRulesTests {
    @Test("Over budget, the oldest sessions go first until the rest fit")
    func removalPlan() {
        let budget = SessionBudget(maxBytes: 500)
        let sessions = [
            StoredSession(name: "2026-01-03", bytes: 300),
            StoredSession(name: "2026-01-01", bytes: 100),
            StoredSession(name: "2026-01-02", bytes: 300),
        ]

        #expect(budget.sessionsToRemove(from: sessions) == ["2026-01-01", "2026-01-02"])
        #expect(budget.sessionsToRemove(from: Array(sessions.prefix(1))).isEmpty)
    }

    @Test("A session being recorded is never removed, though it still counts")
    func protectedSession() {
        let budget = SessionBudget(maxBytes: 500)
        let sessions = [StoredSession(name: "2026-01-01", bytes: 300), StoredSession(name: "2026-01-02", bytes: 400)]

        #expect(budget.sessionsToRemove(from: sessions, protecting: ["2026-01-01"]) == ["2026-01-02"])
    }

    @Test("Storage admission handles boundaries and invalid counts")
    func admission() {
        let budget = SessionBudget(maxBytes: 500)

        #expect(budget.canStore(additionalBytes: 100, usedBytes: 400))
        #expect(!budget.canStore(additionalBytes: 101, usedBytes: 400))
        #expect(!budget.canStore(additionalBytes: -1, usedBytes: 0))
        #expect(!budget.canStore(additionalBytes: 1, usedBytes: .max))
    }

    @Test("Folder names round-trip, sort by start time, and only Linefeed's names are recognized")
    func folderNames() throws {
        let id = try #require(UUID(uuidString: "C81A6E98-FD94-4FC6-AF2C-8928EBD938B1"))
        let earlier = SessionFolderName.make(startedAt: Date(timeIntervalSince1970: 1_787_000_000), id: id)
        let later = SessionFolderName.make(startedAt: Date(timeIntervalSince1970: 1_787_000_061), id: id)

        #expect(earlier == "2026-08-17T20-53-20Z-C81A6E98-FD94-4FC6-AF2C-8928EBD938B1")
        #expect(SessionFolderName.isValid(earlier))
        #expect(earlier < later)
        #expect(!SessionFolderName.isValid("2026-13-99T15-16-45Z-C81A6E98-FD94-4FC6-AF2C-8928EBD938B1"))
        #expect(!SessionFolderName.isValid("notes-C81A6E98-FD94-4FC6-AF2C-8928EBD938B1"))
    }
}
