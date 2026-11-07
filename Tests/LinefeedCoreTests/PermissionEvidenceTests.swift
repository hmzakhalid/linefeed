import Testing
@testable import LinefeedCore

@Suite("Permission evidence")
struct PermissionEvidenceTests {
    @Test("A live grant wins over a stale denial")
    func grantedEvidenceWins() {
        #expect(
            PermissionEvidenceResolver.resolve([.denied, .granted]) == .granted
        )
    }

    @Test("An explicit denial wins over undetermined evidence")
    func deniedEvidenceWinsOverUnknown() {
        #expect(
            PermissionEvidenceResolver.resolve([.unknown, .denied]) == .denied
        )
    }

    @Test("Undetermined sources remain unknown")
    func unknownEvidenceRemainsUnknown() {
        #expect(
            PermissionEvidenceResolver.resolve([.unknown, .unknown]) == .unknown
        )
    }
}
