import Foundation
import Testing
@testable import LinefeedCore

@Suite("Audio activity evidence")
struct AudioActivityEvidenceTests {
    @Test("Requires sustained input instead of a single noise spike")
    func ignoresBriefSpike() {
        var evidence = AudioActivityEvidence(threshold: 0.1, requiredConsecutiveSamples: 3)

        evidence.observe(level: 0.14)
        evidence.observe(level: 0.02)
        evidence.observe(level: 0.15)
        evidence.observe(level: 0.15)

        #expect(!evidence.detected)
    }

    @Test("Recognizes sustained audible input")
    func recognizesSustainedInput() {
        var evidence = AudioActivityEvidence(threshold: 0.1, requiredConsecutiveSamples: 3)

        evidence.observe(level: 0.12)
        evidence.observe(level: 0.18)
        evidence.observe(level: 0.11)

        #expect(evidence.detected)
    }

    @Test("Ordinary speech counts as activity with the shipped thresholds; room noise does not")
    func shippedThresholds() {
        func level(_ amplitude: Float) -> Float {
            let samples = (0..<1_024).map { amplitude * sin(Float($0) * 0.3) }
            return samples.withUnsafeBufferPointer(AudioLevel.of)
        }
        var speech = AudioActivityEvidence()
        var noise = AudioActivityEvidence()
        for _ in 0..<8 {
            speech.observe(level: level(0.05))
            noise.observe(level: level(0.002))
        }
        #expect(speech.detected)
        #expect(!noise.detected)
    }

    @Test("Reset clears prior evidence")
    func resets() {
        var evidence = AudioActivityEvidence(threshold: 0.1, requiredConsecutiveSamples: 1)
        evidence.observe(level: 0.2)

        evidence.reset()

        #expect(!evidence.detected)
    }
}
