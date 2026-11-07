import FluidAudio
import Foundation
import NaturalLanguage

enum SpeechModel: String, CaseIterable, Codable, Identifiable {
    case accurate
    case english
    case fast

    var id: String { rawValue }

    var version: AsrModelVersion {
        switch self {
        case .accurate: return .v3
        case .english: return .v2
        case .fast: return .tdtCtc110m
        }
    }

    var title: String {
        switch self {
        case .accurate: return "Accurate"
        case .english: return "English"
        case .fast: return "Fast"
        }
    }

    var detail: String {
        switch self {
        case .accurate: return "English and European languages"
        case .english: return "Tuned for English speech"
        case .fast: return "Quickest and lightest"
        }
    }

    var badge: String {
        switch self {
        case .accurate: return "Recommended"
        case .english, .fast: return "English only"
        }
    }

    var symbol: String {
        switch self {
        case .accurate: return "sparkles"
        case .english: return "character.bubble"
        case .fast: return "bolt.fill"
        }
    }

    var understandsEveryLanguage: Bool {
        self == .accurate
    }

    func language(for chosen: DictationLanguage) -> DictationLanguage {
        understandsEveryLanguage ? chosen : .english
    }
}

struct DictationLanguage: Hashable, Codable, Identifiable {
    /// An ISO 639-1 code, or `auto`.
    let code: String

    var id: String { code }

    static let automatic = DictationLanguage(code: "auto")
    static let english = DictationLanguage(code: Language.english.rawValue)

    /// Every language the multilingual model's script filter knows.
    static let spoken: [DictationLanguage] = Language.allCases.map { DictationLanguage(code: $0.rawValue) }

    static let all: [DictationLanguage] = [.automatic, .english]
        + spoken.filter { $0 != .english }.sorted { $0.title < $1.title }

    var title: String {
        guard self != .automatic else { return "Automatic" }
        return Locale.current.localizedString(forLanguageCode: code)?.capitalized(with: .current) ?? code
    }

    var nativeTitle: String {
        guard self != .automatic else { return "Detects as you speak" }
        let native = Locale(identifier: code)
        return native.localizedString(forLanguageCode: code)?.capitalized(with: native) ?? title
    }

    /// The listed language `text` is most likely in, for when Automatic
    /// didn't say which one was spoken.
    static func detected(in text: String) -> DictationLanguage {
        guard let code = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue,
              let language = spoken.first(where: { $0.code == code })
        else { return .automatic }
        return language
    }

    /// Steers the decoder toward this language's script; `nil` leaves it free.
    var hint: Language? {
        Language(rawValue: code)
    }
}
