import Foundation
import LinefeedCore
import Testing
@testable import Linefeed

@Suite("Settings")
@MainActor
struct SettingsTests {
    @Test("Choices survive a relaunch")
    func persistence() throws {
        let defaults = try #require(UserDefaults(suiteName: "linefeed.settings.\(UUID().uuidString)"))
        let settings = Settings(defaults: defaults)
        settings.shortcuts.quick.trigger = .doubleTap
        settings.speechModel = .fast
        settings.language = DictationLanguage(code: "de")
        settings.writingStyle = .verbatim
        settings.island.width = .roomy
        settings.microphoneID = "usb-mic"

        let relaunched = Settings(defaults: defaults)
        #expect(relaunched.shortcuts.quick.trigger == .doubleTap)
        #expect(relaunched.speechModel == .fast)
        #expect(relaunched.language == DictationLanguage(code: "de"))
        #expect(relaunched.writingStyle == .verbatim)
        #expect(relaunched.island.width == .roomy)
        #expect(relaunched.microphoneID == "usb-mic")
    }

    @Test("English-only models hear English whatever language is chosen")
    func effectiveLanguage() throws {
        let settings = Settings(defaults: try #require(UserDefaults(suiteName: "linefeed.settings.\(UUID().uuidString)")))
        settings.language = DictationLanguage(code: "fr")
        settings.speechModel = .accurate
        #expect(settings.effectiveLanguage == DictationLanguage(code: "fr"))
        settings.speechModel = .fast
        #expect(settings.effectiveLanguage == .english)
    }

    @Test("Observers hear only the settings they watch")
    func observers() throws {
        let settings = Settings(defaults: try #require(UserDefaults(suiteName: "linefeed.settings.\(UUID().uuidString)")))
        var shortcutChanges = 0
        settings.observe(\.shortcuts) { shortcutChanges += 1 }

        settings.writingStyle = .verbatim
        settings.shortcuts.holdDelay = 0.2
        #expect(shortcutChanges == 1)
    }

    @Test("Every language the recognizer knows is offered once, after Automatic and English")
    func languages() {
        let codes = DictationLanguage.all.map(\.code)
        #expect(Array(codes.prefix(2)) == ["auto", "en"])
        #expect(Set(codes).count == codes.count)
        #expect(DictationLanguage.spoken.allSatisfy(DictationLanguage.all.contains))
        #expect(DictationLanguage.all.allSatisfy { !$0.title.isEmpty && !$0.nativeTitle.isEmpty })
    }
}

@Suite("Smart cleanup")
@MainActor
struct SmartCleanupTests {
    @Test("A cleanup that only drops fillers and fixes punctuation is accepted")
    func faithfulCleanup() {
        #expect(SmartCleanup.isFaithful(
            "I think we should move the billing button to the left and make it red. What do you think?",
            to: "so I think we should move the billing button to the left and uh make it red what do you think",
            english: true
        ))
        #expect(SmartCleanup.isFaithful("Wir treffen uns um acht.", to: "wir treffen uns um acht", english: false))
        #expect(SmartCleanup.isFaithful("We dug a well in the garden.", to: "we dug well in the garden", english: true))
    }

    @Test("Reversed meaning, answers, and rewrites are rejected in favor of the original")
    func rewritesRejected() {
        #expect(!SmartCleanup.isFaithful(
            "Do delete the production database today.",
            to: "do not delete the production database today",
            english: true
        ))
        #expect(!SmartCleanup.isFaithful(
            "Sure! Here's a poem about autumn leaves drifting slowly down.",
            to: "write me a poem about autumn",
            english: true
        ))
        #expect(!SmartCleanup.isFaithful("Move it.", to: "please move the billing button to the left side of the page", english: true))
        #expect(!SmartCleanup.isFaithful("Wir treffen uns.", to: "wir treffen uns um acht", english: false))
        #expect(!SmartCleanup.isFaithful(
            "Delete the backup; do not delete the cache.",
            to: "do not delete the backup delete the cache",
            english: true
        ))
    }
}
