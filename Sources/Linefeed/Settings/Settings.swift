import Foundation
import LinefeedCore
import Observation

/// Every preference Linefeed has, in one observable place. Views bind to it
/// directly; AppKit parts register for the properties they react to.
@MainActor
@Observable
final class Settings {
    private enum Key: String {
        case shortcuts
        case speechModel
        case language = "dictationLanguage"
        case writingStyle
        case fixesTechnicalTerms
        case smartCleanup
        case insertsAutomatically = "autoInsertEnabled"
        case playsSounds
        case microphone = "selectedMicrophoneUID"
        case island = "islandAppearance"
        case completedOnboarding
        case onboardingCheckpoint = "setupCheckpoint"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observers: [(keyPath: PartialKeyPath<Settings>, handler: () -> Void)] = []

    var shortcuts: ShortcutSettings {
        didSet { save(shortcuts, as: .shortcuts); changed(\.shortcuts) }
    }
    var speechModel: SpeechModel {
        didSet { defaults.set(speechModel.rawValue, forKey: Key.speechModel.rawValue); changed(\.speechModel) }
    }
    var language: DictationLanguage {
        didSet { defaults.set(language.code, forKey: Key.language.rawValue); changed(\.language) }
    }
    var writingStyle: WritingStyle {
        didSet { defaults.set(writingStyle.rawValue, forKey: Key.writingStyle.rawValue); changed(\.writingStyle) }
    }
    var fixesTechnicalTerms: Bool {
        didSet { defaults.set(fixesTechnicalTerms, forKey: Key.fixesTechnicalTerms.rawValue); changed(\.fixesTechnicalTerms) }
    }
    var usesSmartCleanup: Bool {
        didSet { defaults.set(usesSmartCleanup, forKey: Key.smartCleanup.rawValue); changed(\.usesSmartCleanup) }
    }
    var insertsAutomatically: Bool {
        didSet { defaults.set(insertsAutomatically, forKey: Key.insertsAutomatically.rawValue); changed(\.insertsAutomatically) }
    }
    var playsSounds: Bool {
        didSet { defaults.set(playsSounds, forKey: Key.playsSounds.rawValue); changed(\.playsSounds) }
    }
    /// `nil` follows the system's choice.
    var microphoneID: String? {
        didSet { defaults.set(microphoneID, forKey: Key.microphone.rawValue); changed(\.microphoneID) }
    }
    var island: IslandAppearance {
        didSet { save(island, as: .island); changed(\.island) }
    }
    var completedOnboarding: Bool {
        didSet { defaults.set(completedOnboarding, forKey: Key.completedOnboarding.rawValue); changed(\.completedOnboarding) }
    }
    /// Where first-run setup resumes after a relaunch. Unused once complete.
    var onboardingCheckpoint: SetupStage? {
        didSet { defaults.set(onboardingCheckpoint?.rawValue, forKey: Key.onboardingCheckpoint.rawValue); changed(\.onboardingCheckpoint) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcuts = Self.decoded(ShortcutSettings.self, from: defaults, key: .shortcuts)?.normalized ?? .standard
        speechModel = defaults.string(forKey: Key.speechModel.rawValue).flatMap(SpeechModel.init(rawValue:)) ?? .accurate
        language = defaults.string(forKey: Key.language.rawValue)
            .map(DictationLanguage.init(code:))
            .flatMap { DictationLanguage.all.contains($0) ? $0 : nil } ?? .english
        writingStyle = defaults.string(forKey: Key.writingStyle.rawValue).flatMap(WritingStyle.init(rawValue:)) ?? .polished
        fixesTechnicalTerms = defaults.object(forKey: Key.fixesTechnicalTerms.rawValue) as? Bool ?? true
        usesSmartCleanup = defaults.object(forKey: Key.smartCleanup.rawValue) as? Bool ?? false
        insertsAutomatically = defaults.object(forKey: Key.insertsAutomatically.rawValue) as? Bool ?? true
        playsSounds = defaults.object(forKey: Key.playsSounds.rawValue) as? Bool ?? true
        microphoneID = defaults.string(forKey: Key.microphone.rawValue)
        island = Self.decoded(IslandAppearance.self, from: defaults, key: .island) ?? IslandAppearance()
        completedOnboarding = defaults.bool(forKey: Key.completedOnboarding.rawValue)
        onboardingCheckpoint = (defaults.object(forKey: Key.onboardingCheckpoint.rawValue) as? Int)
            .flatMap(SetupStage.init(rawValue:))
    }

    var effectiveLanguage: DictationLanguage {
        speechModel.language(for: language)
    }

    var appliesSmartCleanup: Bool {
        usesSmartCleanup && writingStyle.allowsSmartCleanup
    }

    func textPolisher(vocabulary: [VocabularyTerm], language: DictationLanguage) -> TextPolisher {
        TextPolisher(
            style: writingStyle,
            fixesTechnicalTerms: fixesTechnicalTerms,
            vocabulary: vocabulary,
            language: language == .automatic ? nil : language.code
        )
    }

    func observe(_ keyPaths: PartialKeyPath<Settings>..., handler: @escaping () -> Void) {
        observers += keyPaths.map { ($0, handler) }
    }

    private func changed(_ keyPath: PartialKeyPath<Settings>) {
        for observer in observers where observer.keyPath == keyPath {
            observer.handler()
        }
    }

    private func save<Value: Encodable>(_ value: Value, as key: Key) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key.rawValue)
    }

    private static func decoded<Value: Decodable>(_ type: Value.Type, from defaults: UserDefaults, key: Key) -> Value? {
        defaults.data(forKey: key.rawValue).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
