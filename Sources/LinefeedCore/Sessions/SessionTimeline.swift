import Foundation

public enum SessionTimecode {
    public static func string(for seconds: TimeInterval?) -> String {
        guard let seconds else { return "--:--" }
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

public enum ContextTimeline {
    public static func excerpt(
        at offset: TimeInterval,
        from words: [TimedTranscriptWord],
        secondsBefore: TimeInterval = 3.5,
        secondsAfter: TimeInterval = 4.0,
        maximumWords: Int = 22
    ) -> String {
        let words = words.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.startTime < $1.startTime }
        guard !words.isEmpty, maximumWords > 0 else { return "" }

        let range = (offset - secondsBefore)...(offset + secondsAfter)
        let matching = words.indices.filter { index in
            words[index].endTime >= range.lowerBound && words[index].startTime <= range.upperBound
        }
        let centerIndex = matching.isEmpty
            ? nearestWordIndex(to: offset, in: words)
            : matching[matching.count / 2]
        let leadingWords = (maximumWords - 1) / 2
        var lower = max(0, centerIndex - leadingWords)
        var upper = min(words.count, lower + maximumWords)
        lower = max(0, upper - maximumWords)

        if let first = matching.first, let last = matching.last, last - first + 1 <= maximumWords {
            lower = max(0, min(lower, first))
            upper = min(words.count, max(upper, last + 1))
            if upper - lower > maximumWords {
                lower = max(0, centerIndex - leadingWords)
                upper = min(words.count, lower + maximumWords)
            }
        }

        let phrase = join(words[lower..<upper].map(\.text))
        let prefix = lower > 0 ? "…" : ""
        let suffix = upper < words.count ? "…" : ""
        return "\(prefix)\(phrase)\(suffix)"
    }

    private static func nearestWordIndex(
        to offset: TimeInterval,
        in words: [TimedTranscriptWord]
    ) -> Int {
        words.indices.min { left, right in
            distance(from: offset, to: words[left]) < distance(from: offset, to: words[right])
        } ?? 0
    }

    private static func distance(from offset: TimeInterval, to word: TimedTranscriptWord) -> TimeInterval {
        if offset < word.startTime { return word.startTime - offset }
        if offset > word.endTime { return offset - word.endTime }
        return 0
    }

    private static func join(_ words: [String]) -> String {
        let closingPunctuation = CharacterSet(charactersIn: ".,!?;:%)]}”’")
        var result = ""
        for word in words {
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let first = trimmed.unicodeScalars.first
            if result.isEmpty || first.map(closingPunctuation.contains) == true {
                result += trimmed
            } else {
                result += " \(trimmed)"
            }
        }
        return result
    }
}
