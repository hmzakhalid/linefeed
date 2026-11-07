import Foundation
import Testing
@testable import LinefeedCore

@Suite("Text polishing")
struct TextPolisherTests {
    private let polished = TextPolisher(style: .polished, fixesTechnicalTerms: false)

    @Test("Polished text drops hesitation and finishes the sentence")
    func polishedSentence() {
        #expect(polished.polish(" um explain the selected button, uh ", for: .general) == "Explain the selected button.")
        #expect(polished.polish("is this ready?", for: .general) == "Is this ready?")
    }

    @Test("Spoken layout commands become line breaks in any case")
    func layoutCommands() {
        #expect(
            polished.polish("first thought NEW PARAGRAPH second thought New Line detail", for: .general)
                == "First thought\n\nSecond thought\nDetail."
        )
    }

    @Test("Punctuation the recognizer adds around layout commands is tidied")
    func layoutPunctuation() {
        #expect(polished.polish("First point. New line. Second point.", for: .general) == "First point.\nSecond point.")
        #expect(polished.polish("Hello, new paragraph, world.", for: .general) == "Hello\n\nWorld.")
        #expect(polished.polish("Um.", for: .general) == "")
        #expect(polished.polish("  ...  ", for: .general) == "")
    }

    @Test("English-only rules leave other languages untouched")
    func otherLanguages() {
        let german = TextPolisher(style: .polished, fixesTechnicalTerms: true, language: "de")
        #expect(german.polish("wir treffen uns um 5 Uhr", for: .general) == "Wir treffen uns um 5 Uhr.")
        let hungarian = TextPolisher(style: .polished, fixesTechnicalTerms: true, language: "hu")
        #expect(hungarian.polish("gyere ide", for: .general) == "Gyere ide.")
        let automatic = TextPolisher(style: .polished, fixesTechnicalTerms: true, language: nil)
        #expect(automatic.polish("le api est prêt", for: .general) == "Le api est prêt.")
    }

    @Test("Verbatim keeps every word and only trims the edges")
    func verbatim() {
        let verbatim = TextPolisher(style: .verbatim, fixesTechnicalTerms: false)
        #expect(verbatim.polish("  keep um exactly  ", for: .general) == "keep um exactly")
    }

    @Test("Technical terms are cased without touching paths, domains, or ordinary words")
    func technicalTerms() {
        let polisher = TextPolisher(style: .verbatim, fixesTechnicalTerms: true)
        #expect(polisher.polish("push the json to github.", for: .general) == "push the JSON to GitHub.")
        #expect(polisher.polish("open config.json and github.com/api", for: .general) == "open config.json and github.com/api")
        #expect(polisher.polish("take a rest and ask the ai", for: .general) == "take a rest and ask the ai")
        #expect(polisher.polish("call the rest api", for: .editor) == "call the REST API")
        #expect(polisher.polish("run n p m install", for: .terminal) == "run npm install")
        #expect(polisher.polish("run n p m install", for: .general) == "run n p m install")
        #expect(polisher.polish("café api", for: .general) == "café API")
    }

    @Test("Personal vocabulary applies on its own and wins over built-in spellings")
    func vocabulary() {
        let terms = [VocabularyTerm(spoken: "cube cuttle", written: "kubectl"), VocabularyTerm(spoken: "api", written: "Api")]
        #expect(
            TextPolisher(style: .verbatim, fixesTechnicalTerms: false, vocabulary: terms)
                .polish("run cube cuttle against the api", for: .general) == "run kubectl against the Api"
        )
        #expect(
            TextPolisher(style: .verbatim, fixesTechnicalTerms: true, vocabulary: terms)
                .polish("the api returns json", for: .general) == "the Api returns JSON"
        )
        let postgres = [VocabularyTerm(spoken: "post gres", written: "postgres")]
        #expect(
            TextPolisher(style: .verbatim, fixesTechnicalTerms: true, vocabulary: postgres)
                .polish("start post gres", for: .general) == "start postgres"
        )
    }

    @Test("Vocabulary files are read longest phrase first and malformed files are ignored")
    func vocabularyFile() throws {
        let data = Data(#"{"terms": {"engine x": "nginx", "engine x plus": "NGINX Plus", "": "empty", "blank": ""}}"#.utf8)
        #expect(VocabularyFile.terms(from: data).map(\.spoken) == ["engine x plus", "engine x"])
        #expect(VocabularyFile.terms(from: Data("{ not json".utf8)).isEmpty)
        let template = try #require(VocabularyFile.template.data(using: .utf8))
        #expect(VocabularyFile.terms(from: template).isEmpty)
        #expect((try? JSONSerialization.jsonObject(with: template)) != nil)
    }

    @Test("The destination app decides how eagerly terms are corrected")
    func destinations() {
        #expect(TextDestination.infer(bundleIdentifier: "com.apple.Terminal", applicationName: "Terminal") == .terminal)
        #expect(TextDestination.infer(bundleIdentifier: "com.microsoft.VSCode", applicationName: nil) == .editor)
        #expect(TextDestination.infer(bundleIdentifier: "com.openai.chat", applicationName: "ChatGPT") == .assistant)
        #expect(TextDestination.infer(bundleIdentifier: "com.apple.mail", applicationName: "Mail") == .general)
    }
}
