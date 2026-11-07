import Foundation

public struct SessionCaptureRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let index: Int
    public let imageFilename: String
    public let offset: TimeInterval?
    public let excerpt: String

    public init(
        id: String = UUID().uuidString,
        index: Int,
        imageFilename: String,
        offset: TimeInterval?,
        excerpt: String
    ) {
        self.id = id
        self.index = index
        self.imageFilename = imageFilename
        self.offset = offset
        self.excerpt = excerpt
    }
}

public struct SessionManifest: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public let startedAt: Date
    public let endedAt: Date
    public let duration: TimeInterval
    public let microphone: String
    public let speechModel: String
    public let language: String
    public let recordingMode: String
    public let transcript: TimedTranscript
    public let captures: [SessionCaptureRecord]

    public init(
        schemaVersion: Int = SessionManifest.currentSchemaVersion,
        id: String,
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        microphone: String,
        speechModel: String,
        language: String,
        recordingMode: String,
        transcript: TimedTranscript,
        captures: [SessionCaptureRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = max(0, duration)
        self.microphone = microphone
        self.speechModel = speechModel
        self.language = language
        self.recordingMode = recordingMode
        self.transcript = transcript
        self.captures = captures.sorted { $0.index < $1.index }
    }

    public var title: String {
        let collapsed = transcript.text
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        if !collapsed.isEmpty { return String(collapsed.prefix(72)) }
        if captures.count == 1 { return "One visual note" }
        if !captures.isEmpty { return "\(captures.count) visual notes" }
        return "Empty session"
    }

    public var contextualClipboardText: String {
        let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !captures.isEmpty else { return trimmed }

        var sections: [String] = []
        if !trimmed.isEmpty { sections.append(trimmed) }
        var timeline = "Context timeline (screenshots are attached in this same order):"
        for capture in captures {
            let time = SessionTimecode.string(for: capture.offset)
            timeline += "\n- Screenshot \(capture.index) = attached image \(capture.index) · \(time)"
            if !capture.excerpt.isEmpty {
                timeline += "\n  Spoken context: “\(capture.excerpt)”"
            }
        }
        sections.append(timeline)
        return sections.joined(separator: "\n\n")
    }

    public var markdown: String {
        let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = "# Linefeed session\n\n"
        result += "Started: \(startedAt.formatted(.iso8601))\n\n"
        result += "## Transcript\n\n"
        result += trimmed.isEmpty ? "_No transcript captured._\n" : "\(trimmed)\n"
        guard !captures.isEmpty else { return result }

        result += "\n## Context timeline\n"
        for capture in captures {
            result += "\n### Screenshot \(capture.index) · \(SessionTimecode.string(for: capture.offset))\n\n"
            if !capture.excerpt.isEmpty {
                result += "> \(capture.excerpt)\n\n"
            }
            result += "![Screenshot \(capture.index)](\(capture.imageFilename))\n"
        }
        return result
    }

    public var searchableText: String {
        ([title, transcript.text] + captures.map(\.excerpt)).joined(separator: " ")
    }
}
