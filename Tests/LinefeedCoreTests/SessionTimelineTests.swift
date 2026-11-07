import Foundation
import Testing
@testable import LinefeedCore

@Suite("Session timeline")
struct SessionTimelineTests {
    @Test("Capture excerpt follows the recording clock")
    func excerptAtCaptureTime() {
        let words = [
            word("Open", 0.0), word("the", 0.4), word("first", 0.8), word("panel", 1.2),
            word("then", 5.0), word("scroll", 5.4), word("to", 5.8), word("billing", 6.2),
            word("and", 10.0), word("change", 10.4), word("the", 10.8), word("plan", 11.2),
        ]

        let excerpt = ContextTimeline.excerpt(
            at: 10.8,
            from: words,
            secondsBefore: 1.2,
            secondsAfter: 1.2,
            maximumWords: 5
        )

        #expect(excerpt.contains("change the plan"))
        #expect(!excerpt.contains("first panel"))
    }

    @Test("A capture between words uses the nearest spoken phrase")
    func nearestPhrase() {
        let words = [word("before", 1), word("nearby", 8), word("phrase", 8.4)]

        let excerpt = ContextTimeline.excerpt(
            at: 7.8,
            from: words,
            secondsBefore: 0,
            secondsAfter: 0,
            maximumWords: 2
        )

        #expect(excerpt.contains("nearby phrase"))
    }

    @Test("Timecodes support long recordings")
    func timecodes() {
        #expect(SessionTimecode.string(for: 17.9) == "00:17")
        #expect(SessionTimecode.string(for: 125) == "02:05")
        #expect(SessionTimecode.string(for: 3_661) == "01:01:01")
        #expect(SessionTimecode.string(for: nil) == "--:--")
    }

    @Test("Clipboard text maps every screenshot to its attachment and phrase")
    func contextualClipboardText() {
        let manifest = makeManifest(captures: [
            SessionCaptureRecord(index: 1, imageFilename: "visual-001.png", offset: 4.2, excerpt: "open settings"),
            SessionCaptureRecord(index: 2, imageFilename: "visual-002.png", offset: 12.0, excerpt: "enable the switch"),
        ])

        #expect(manifest.contextualClipboardText.contains("Screenshot 1 = attached image 1 · 00:04"))
        #expect(manifest.contextualClipboardText.contains("Spoken context: “enable the switch”"))
    }

    private func word(_ text: String, _ time: TimeInterval) -> TimedTranscriptWord {
        TimedTranscriptWord(text: text, startTime: time, endTime: time + 0.3)
    }

    private func makeManifest(captures: [SessionCaptureRecord]) -> SessionManifest {
        SessionManifest(
            id: "session-test",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 120),
            duration: 20,
            microphone: "MacBook Microphone",
            speechModel: "Accurate",
            language: "English",
            recordingMode: "Hands-free",
            transcript: TimedTranscript(
                text: "Open settings, then enable the switch.",
                rawText: "Open settings then enable the switch",
                duration: 20,
                words: []
            ),
            captures: captures
        )
    }
}
