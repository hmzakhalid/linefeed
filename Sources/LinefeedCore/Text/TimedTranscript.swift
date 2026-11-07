import Foundation

public struct TimedTranscriptWord: Codable, Equatable, Sendable {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.text = text
        self.startTime = max(0, startTime)
        self.endTime = max(self.startTime, endTime)
    }
}

public struct TimedTranscript: Codable, Equatable, Sendable {
    public static let empty = TimedTranscript(text: "", rawText: "", duration: 0, words: [])

    public let text: String
    public let rawText: String
    public let duration: TimeInterval
    public let words: [TimedTranscriptWord]

    public init(
        text: String,
        rawText: String,
        duration: TimeInterval,
        words: [TimedTranscriptWord]
    ) {
        self.text = text
        self.rawText = rawText
        self.duration = max(0, duration)
        self.words = words
    }
}
