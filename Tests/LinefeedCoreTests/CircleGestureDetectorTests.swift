import CoreGraphics
import Testing
@testable import LinefeedCore

@Suite("Pointer loop recognition")
struct CircleGestureDetectorTests {
    @Test("A complete circular stroke produces its center and radius")
    func recognizesCircle() {
        let expectedCenter = CGPoint(x: 320, y: 240)
        let capture = feedLoop(
            center: expectedCenter,
            horizontalRadius: 56,
            verticalRadius: 56,
            sampleCount: 52
        )

        #expect(capture != nil)
        #expect(abs((capture?.center.x ?? 0) - expectedCenter.x) < 3)
        #expect(abs((capture?.center.y ?? 0) - expectedCenter.y) < 3)
        #expect(abs((capture?.radius ?? 0) - 56) < 3)
    }

    @Test("A hand-drawn oval is accepted")
    func recognizesLooseOval() {
        let capture = feedLoop(
            center: CGPoint(x: 800, y: 500),
            horizontalRadius: 112,
            verticalRadius: 84,
            sampleCount: 144,
            wobble: 0.09
        )

        #expect(capture != nil)
    }

    @Test("Ordinary pointer travel is rejected")
    func rejectsLine() {
        var detector = CircleGestureDetector()
        var capture: CircleGesture?

        for sample in 0..<64 {
            capture = detector.add(
                point: CGPoint(x: CGFloat(sample * 5), y: 180),
                at: Double(sample) / 90
            ) ?? capture
        }

        #expect(capture == nil)
    }

    @Test("One continuous loop creates only one capture")
    func latchesUntilPointerLeaves() {
        var detector = CircleGestureDetector()
        let center = CGPoint(x: 460, y: 320)
        var captureCount = 0

        for sample in 0..<260 {
            let angle = CGFloat(sample) / 51 * 2 * .pi
            let point = CGPoint(
                x: center.x + 72 * cos(angle),
                y: center.y + 72 * sin(angle)
            )
            if detector.add(point: point, at: Double(sample) / 60) != nil {
                captureCount += 1
            }
        }

        #expect(captureCount == 1)
    }

    @Test("Invalid pointer samples are ignored")
    func ignoresInvalidSamples() {
        var detector = CircleGestureDetector()

        #expect(detector.add(point: CGPoint(x: CGFloat.infinity, y: 1), at: 0) == nil)
        #expect(detector.add(point: .zero, at: .nan) == nil)
    }

    private func feedLoop(
        center: CGPoint,
        horizontalRadius: CGFloat,
        verticalRadius: CGFloat,
        sampleCount: Int,
        wobble: CGFloat = 0
    ) -> CircleGesture? {
        var detector = CircleGestureDetector()
        var capture: CircleGesture?

        for sample in 0..<sampleCount {
            let angle = CGFloat(sample) / CGFloat(sampleCount - 1) * 2 * .pi
            let variation = 1 + wobble * sin(angle * 3)
            let point = CGPoint(
                x: center.x + horizontalRadius * variation * cos(angle),
                y: center.y + verticalRadius * variation * sin(angle)
            )
            capture = detector.add(point: point, at: Double(sample) * 0.02) ?? capture
        }
        return capture
    }
}
