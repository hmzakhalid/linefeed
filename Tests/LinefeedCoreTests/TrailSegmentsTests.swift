import CoreGraphics
import Testing
@testable import LinefeedCore

@Suite("Pointer trail segmentation")
struct TrailSegmentsTests {
    @Test("Nearby samples become drawable segments")
    func connectsNearbySamples() {
        let segments = trailSegments(
            points: [.zero, CGPoint(x: 4, y: 3), CGPoint(x: 10, y: 3)],
            times: [0, 0.05, 0.1]
        )

        #expect(segments == [TrailSegment(from: 0, to: 1), TrailSegment(from: 1, to: 2)])
    }

    @Test("Pauses, reversed clocks, and pointer jumps split the trail")
    func separatesDiscontinuousSamples() {
        #expect(trailSegments(
            points: [.zero, CGPoint(x: 2, y: 2)],
            times: [0, 0.3]
        ).isEmpty)
        #expect(trailSegments(
            points: [.zero, CGPoint(x: 2, y: 2)],
            times: [1, 0.9]
        ).isEmpty)
        #expect(trailSegments(
            points: [.zero, CGPoint(x: 240, y: 0)],
            times: [0, 0.01]
        ).isEmpty)
    }

    @Test("Mismatched inputs and invalid limits produce no segments")
    func invalidInput() {
        #expect(trailSegments(points: [.zero], times: []).isEmpty)
        #expect(trailSegments(
            points: [.zero, CGPoint(x: 1, y: 1)],
            times: [0, 0.1],
            maximumGap: -1
        ).isEmpty)
    }
}
