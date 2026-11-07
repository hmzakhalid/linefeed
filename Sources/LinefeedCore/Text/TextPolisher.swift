import Foundation

public enum WritingStyle: String, CaseIterable, Codable, Sendable {
    case polished
    case verbatim

    public var title: String {
        switch self {
        case .polished: return "Polished"
        case .verbatim: return "Verbatim"
        }
    }

    public var detail: String {
        switch self {
        case .polished: return "Drops fillers, follows “new line”, finishes sentences"
        case .verbatim: return "Keeps every word exactly as spoken"
        }
    }

    /// Smart cleanup builds on the Polished rules; Verbatim promises the words as spoken.
    public var allowsSmartCleanup: Bool {
        self == .polished
    }
}

/// The kind of app a transcript is headed to, which decides how eagerly
/// technical terms are corrected.
public enum TextDestination: String, Sendable {
    case general
    case terminal
    case editor
    case assistant

    public static func infer(bundleIdentifier: String?, applicationName: String?) -> TextDestination {
        let identifier = bundleIdentifier?.lowercased() ?? ""
        let name = applicationName?.lowercased() ?? ""
        if ["com.apple.terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.warp-stable",
            "net.kovidgoyal.kitty", "com.github.wez.wezterm"].contains(identifier)
            || ["terminal", "iterm2", "ghostty", "warp", "kitty", "wezterm"].contains(name) {
            return .terminal
        }
        if ["com.apple.dt.xcode", "com.microsoft.vscode", "com.todesktop.230313mzl4w4u92", "com.exafunction.windsurf",
            "dev.zed.zed"].contains(identifier)
            || ["xcode", "visual studio code", "code", "cursor", "windsurf", "zed", "neovim"].contains(name) {
            return .editor
        }
        if ["com.openai.chat", "com.openai.codex", "com.anthropic.claudefordesktop"].contains(identifier)
            || ["chatgpt", "claude", "codex"].contains(name) {
            return .assistant
        }
        return .general
    }
}

public struct TextPolisher: Sendable {
    public var style: WritingStyle
    public var fixesTechnicalTerms: Bool
    /// The person's own corrections, longest spoken form first.
    public var vocabulary: [VocabularyTerm]
    /// The spoken language's ISO 639-1 code, or `nil` when unknown. Fillers,
    /// spoken layout commands, and the built-in terms are English, so they
    /// apply only to English.
    public var language: String?

    public init(style: WritingStyle, fixesTechnicalTerms: Bool, vocabulary: [VocabularyTerm] = [], language: String? = "en") {
        self.style = style
        self.fixesTechnicalTerms = fixesTechnicalTerms
        self.vocabulary = vocabulary
        self.language = language
    }

    private var isEnglish: Bool { language == "en" }

    public func polish(_ text: String, for destination: TextDestination) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let styled = style == .polished ? PolishedStyle.apply(to: trimmed, english: isEnglish) : trimmed
        guard styled.contains(where: { $0.isLetter || $0.isNumber }) else { return "" }
        return applyTerms(to: styled, for: destination)
    }

    /// Vocabulary and technical terms on their own, for text that another
    /// cleanup step may have re-cased.
    public func applyTerms(to text: String, for destination: TextDestination) -> String {
        TechnicalTerms.apply(
            to: text,
            destination: destination,
            vocabulary: vocabulary,
            includeBuiltIn: fixesTechnicalTerms && isEnglish
        )
    }
}

private enum PolishedStyle {
    private static let terminalCharacters = CharacterSet(charactersIn: ".!?…:;)]}")

    static func apply(to text: String, english: Bool) -> String {
        var result = english ? removeHesitationWords(from: expandLayoutCommands(in: text)) : text
        result = capitalizeLineStarts(in: normalizeLayout(in: result))
        if let finalScalar = result.unicodeScalars.last, !terminalCharacters.contains(finalScalar) {
            result.append(".")
        }
        return result
    }

    private static func expandLayoutCommands(in text: String) -> String {
        replacingMatches(in: text, pattern: #"(?i)(?<![\p{L}\p{N}_])new[ \t]+(paragraph|line)(?![\p{L}\p{N}_])[ \t]*[.,;:!?]?"#) { match, source in
            guard let kindRange = Range(match.range(at: 1), in: source) else { return "\n" }
            return source[kindRange].caseInsensitiveCompare("paragraph") == .orderedSame ? "\n\n" : "\n"
        }
    }

    private static func removeHesitationWords(from text: String) -> String {
        replacingMatches(in: text, pattern: #"(?i)(?<![\p{L}\p{N}_])(?:um+|uh+|erm)(?![\p{L}\p{N}_])[,]?"#) { _, _ in "" }
    }

    private static func normalizeLayout(in text: String) -> String {
        var value = text
        for (pattern, replacement) in [
            (#"[ \t]+"#, " "),
            (#"[ \t]*\n[ \t]*"#, "\n"),
            (#"\n{3,}"#, "\n\n"),
            (#"[ \t]+([,.!?;:])"#, "$1"),
            (#",[ \t]*(?=\n|$)"#, ""),
        ] {
            value = value.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func capitalizeLineStarts(in text: String) -> String {
        text.components(separatedBy: "\n").map { line in
            guard let letter = line.firstIndex(where: \.isLetter) else { return line }
            var result = line
            result.replaceSubrange(letter...letter, with: String(line[letter]).uppercased())
            return result
        }.joined(separator: "\n")
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        replacement: (NSTextCheckingResult, String) -> String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: replacement(match, text))
        }
        return result
    }
}
