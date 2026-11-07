import Foundation

public struct VocabularyTerm: Equatable, Sendable {
    public let spoken: String
    public let written: String

    public init(spoken: String, written: String) {
        self.spoken = spoken
        self.written = written
    }
}

public enum VocabularyFile {
    public static let fileName = "vocabulary.json"

    /// Longest spoken form first, so a phrase wins over a word inside it.
    /// A malformed file yields no terms: a stray comma should never cost a
    /// recording.
    public static func terms(from data: Data) -> [VocabularyTerm] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let table = root["terms"] as? [String: String]
        else { return [] }
        return table
            .map { VocabularyTerm(spoken: $0.key.trimmingCharacters(in: .whitespaces), written: $0.value) }
            .filter { !$0.spoken.isEmpty && !$0.written.isEmpty }
            .sorted { lhs, rhs in
                lhs.spoken.count == rhs.spoken.count ? lhs.spoken < rhs.spoken : lhs.spoken.count > rhs.spoken.count
            }
    }

    /// Ships with no terms: every entry rewrites free speech, so the first one
    /// should be the person's decision.
    public static let template = """
    {
      "_readme": [
        "Corrections for words Linefeed mishears. The key is what it wrote,",
        "the value is what you meant. Phrases of several words work too.",
        "Changes apply to your next recording.",
        "",
        "Example: \\"cube cuttle\\": \\"kubectl\\"",
        "",
        "Never use an ordinary word as a key: \\"read me\\": \\"README\\" would",
        "rewrite every sentence containing “read me”. Matching is whole-word",
        "and ignores case, and it leaves filenames, domains and paths alone."
      ],
      "terms": {
      }
    }

    """
}
