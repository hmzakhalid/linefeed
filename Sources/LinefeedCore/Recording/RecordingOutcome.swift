public enum RecordingOutcome: Equatable, Sendable {
    /// Words, screenshots, or both: save and deliver.
    case captured
    /// Speech was heard or screenshots were taken, but no text came back.
    case transcriptionFailed
    /// Silence and no screenshots: resolve quietly, keep nothing.
    case nothingCaptured

    /// - Parameter transcript: `nil` when transcription threw.
    public init(transcript: String?, screenshotCount: Int, heardSpeech: Bool) {
        let hasText = (transcript ?? "").contains { $0.isLetter || $0.isNumber }
        if hasText {
            self = .captured
        } else if transcript == nil, screenshotCount > 0 || heardSpeech {
            self = .transcriptionFailed
        } else if screenshotCount > 0 {
            self = .captured
        } else {
            self = .nothingCaptured
        }
    }
}
