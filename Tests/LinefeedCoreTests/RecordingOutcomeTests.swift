import Testing
@testable import LinefeedCore

@Suite("Recording outcome")
struct RecordingOutcomeTests {
    @Test("Silence with no screenshots resolves quietly, even when the decoder fails")
    func silence() {
        #expect(RecordingOutcome(transcript: "", screenshotCount: 0, heardSpeech: false) == .nothingCaptured)
        #expect(RecordingOutcome(transcript: nil, screenshotCount: 0, heardSpeech: false) == .nothingCaptured)
        #expect(RecordingOutcome(transcript: "  ", screenshotCount: 0, heardSpeech: true) == .nothingCaptured)
        #expect(RecordingOutcome(transcript: ".", screenshotCount: 0, heardSpeech: true) == .nothingCaptured)
    }

    @Test("A failed transcription stays actionable when there was something to lose")
    func failure() {
        #expect(RecordingOutcome(transcript: nil, screenshotCount: 0, heardSpeech: true) == .transcriptionFailed)
        #expect(RecordingOutcome(transcript: nil, screenshotCount: 2, heardSpeech: false) == .transcriptionFailed)
    }

    @Test("Words or screenshots are always delivered")
    func captured() {
        #expect(RecordingOutcome(transcript: "Ship it.", screenshotCount: 0, heardSpeech: false) == .captured)
        #expect(RecordingOutcome(transcript: "", screenshotCount: 1, heardSpeech: false) == .captured)
    }
}
