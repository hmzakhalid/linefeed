import Foundation
import Testing
@testable import LinefeedCore

/// Drives the engine and the command resolver the way the app does, so each
/// test reads as what a person presses and what Linefeed does in response.
private struct Keyboard {
    var engine: ShortcutEngine
    var phase = RecordingPhase.idle
    /// Keeps a stopped session in `.finishing` instead of going straight to idle.
    var finishesSlowly = false
    var commands: [RecordingCommand] = []
    var holdScheduled = false
    var now: TimeInterval = 0

    init(_ settings: ShortcutSettings = .standard) {
        engine = ShortcutEngine(settings: settings)
    }

    mutating func modifiers(_ modifiers: ModifierSet, after delay: TimeInterval = 0.02) {
        now += delay
        apply(engine.handle(.modifiers(modifiers, at: now)))
    }

    mutating func keyDown(_ code: UInt16, _ modifiers: ModifierSet = [], after delay: TimeInterval = 0.02) {
        now += delay
        apply(engine.handle(.keyDown(code, modifiers: modifiers, at: now)))
    }

    mutating func keyUp(_ code: UInt16, after delay: TimeInterval = 0.02) {
        now += delay
        apply(engine.handle(.keyUp(code, at: now)))
    }

    mutating func click() {
        apply(engine.handle(.pointerPressed))
    }

    /// Lets the hold timer fire, as the run loop would after the delay.
    mutating func waitForHold() {
        guard holdScheduled else { return }
        holdScheduled = false
        now += engine.settings.holdDelay
        apply(engine.handle(.holdElapsed))
    }

    private mutating func apply(_ outputs: [ShortcutOutput]) {
        for output in outputs {
            switch output {
            case .scheduleHold:
                holdScheduled = true
            case .cancelHold:
                holdScheduled = false
            case .gesture(let gesture):
                let command = RecordingCommand.resolve(gesture, in: phase)
                guard command != .ignore else { continue }
                commands.append(command)
                switch command {
                case .start(let mode): phase = .recording(mode)
                case .promoteToHandsFree: phase = .recording(.handsFree)
                case .stop: phase = finishesSlowly ? .finishing(queued: nil) : .idle
                case .discard, .discardIfUntouched: phase = .idle
                case .queue(let mode): phase = .finishing(queued: mode)
                case .dropQueued: phase = .finishing(queued: nil)
                case .ignore: break
                }
            }
        }
    }
}

private let f5: UInt16 = 96
private let space: UInt16 = 49
private let letterE: UInt16 = 14

@Suite("Shortcut engine")
struct ShortcutEngineTests {
    @Test("Holding ⌥ past the delay records until release")
    func holdToTalk() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.waitForHold()
        #expect(keyboard.phase == .recording(.quick))
        keyboard.modifiers([], after: 2)
        #expect(keyboard.commands == [.start(.quick), .stop])
    }

    @Test("A ⌥ tap shorter than the delay never starts recording")
    func shortTapCancels() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.modifiers([], after: 0.05)
        keyboard.waitForHold()
        #expect(keyboard.commands.isEmpty)
        #expect(!keyboard.holdScheduled)
    }

    @Test("Stopping hands-free works when ⌥ lands well before ⌘")
    func handsFreeStopsWithOptionFirst() {
        var keyboard = Keyboard()
        keyboard.modifiers(.command)
        keyboard.modifiers([.command, .option])
        keyboard.modifiers(.option)
        keyboard.modifiers([])
        #expect(keyboard.phase == .recording(.handsFree))

        keyboard.modifiers(.option, after: 3)
        keyboard.waitForHold()
        keyboard.modifiers([.option, .command])
        keyboard.modifiers(.option)
        keyboard.modifiers([])

        #expect(keyboard.commands == [.start(.handsFree), .stop])
        #expect(keyboard.phase == .idle)
    }

    @Test("A slow ⌥ then ⌘ → during hands-free is an app shortcut and leaves the recording alone")
    func slowAppShortcutDuringHandsFree() {
        var keyboard = Keyboard()
        keyboard.modifiers([.option, .command])
        keyboard.modifiers([])
        keyboard.modifiers(.option, after: 2)
        keyboard.waitForHold()
        keyboard.modifiers([.option, .command])
        keyboard.keyDown(124, [.option, .command])
        keyboard.modifiers(.option)
        keyboard.modifiers([])

        #expect(keyboard.commands == [.start(.handsFree)])
        #expect(keyboard.phase == .recording(.handsFree))
    }

    @Test("Promoting works whichever key of the chord is let go first")
    func promotionReleaseOrder() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.waitForHold()
        keyboard.modifiers([.option, .command])
        keyboard.modifiers(.command)
        keyboard.modifiers([])

        #expect(keyboard.commands == [.start(.quick), .promoteToHandsFree])
        #expect(keyboard.phase == .recording(.handsFree))
    }

    @Test("A held quick note is promoted once, and stays hands-free after ⌥ is released")
    func promotionLatchesUntilRelease() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.waitForHold()
        keyboard.modifiers([.option, .command])
        keyboard.modifiers(.option)
        keyboard.modifiers([.option, .command])
        keyboard.modifiers(.option)
        keyboard.modifiers([])

        #expect(keyboard.commands == [.start(.quick), .promoteToHandsFree])
        #expect(keyboard.phase == .recording(.handsFree))
    }

    @Test("Pressing the chord before the delay starts hands-free without a quick note")
    func chordBeforeDelay() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.modifiers([.option, .command], after: 0.04)
        keyboard.modifiers(.option)
        keyboard.waitForHold()
        keyboard.modifiers([], after: 1)

        #expect(keyboard.commands == [.start(.handsFree)])
    }

    @Test("Shift during a quick note neither promotes nor stops it")
    func foreignModifierMidHold() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.waitForHold()
        keyboard.modifiers([.option, .shift])
        keyboard.modifiers(.option)
        #expect(keyboard.commands == [.start(.quick)])

        keyboard.modifiers([])
        #expect(keyboard.commands == [.start(.quick), .stop])
    }

    @Test("Typing an ⌥ or ⌥⇧ character never starts a recording")
    func typingWithOption() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.keyDown(letterE, .option, after: 0.06)
        keyboard.waitForHold()
        keyboard.modifiers([], after: 0.3)

        keyboard.modifiers(.option, after: 1)
        keyboard.modifiers([.option, .shift], after: 0.05)
        keyboard.waitForHold()
        keyboard.modifiers([], after: 0.3)

        #expect(keyboard.commands.isEmpty)
    }

    @Test("App shortcuts that share the hands-free modifiers never toggle recording")
    func appShortcutsPassThrough() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.modifiers([.option, .command])
        keyboard.keyDown(34, [.option, .command])
        keyboard.modifiers(.option)
        keyboard.modifiers([])

        keyboard.modifiers([.option, .command], after: 1)
        keyboard.click()
        keyboard.modifiers([])
        #expect(keyboard.commands.isEmpty)
    }

    @Test("An ⌥-click never keeps a quick note")
    func optionClick() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.click()
        keyboard.waitForHold()
        keyboard.modifiers([], after: 0.5)
        #expect(keyboard.commands.isEmpty)

        keyboard.modifiers(.option, after: 1)
        keyboard.waitForHold()
        keyboard.click()
        #expect(keyboard.commands == [.start(.quick), .discardIfUntouched])
    }

    @Test("A shortcut pressed while the last note is finishing is queued, and dropped if let go")
    func queuedWhileFinishing() {
        var keyboard = Keyboard()
        keyboard.finishesSlowly = true
        keyboard.modifiers(.option)
        keyboard.waitForHold()
        keyboard.modifiers([], after: 1)
        #expect(keyboard.phase == .finishing(queued: nil))

        keyboard.modifiers(.option, after: 0.2)
        keyboard.waitForHold()
        #expect(keyboard.phase == .finishing(queued: .quick))
        keyboard.modifiers([], after: 0.3)
        #expect(keyboard.phase == .finishing(queued: nil))

        keyboard.modifiers(.option, after: 0.2)
        keyboard.waitForHold()
        keyboard.modifiers([.option, .command])
        keyboard.modifiers([], after: 0.3)
        #expect(keyboard.phase == .finishing(queued: .handsFree))
    }

    @Test("A key pressed during a held quick note asks to discard it if nothing was said")
    func keyDuringHold() {
        var keyboard = Keyboard()
        keyboard.modifiers(.option)
        keyboard.waitForHold()
        keyboard.keyDown(123, .option)
        #expect(keyboard.commands == [.start(.quick), .discardIfUntouched])

        var chord = Keyboard()
        chord.modifiers(.option)
        chord.waitForHold()
        chord.modifiers([.option, .command])
        chord.keyDown(124, [.option, .command])
        chord.modifiers([])
        #expect(chord.commands == [.start(.quick), .discardIfUntouched])
    }

    @Test("Escape discards a recording and is ignored otherwise")
    func escapeDiscards() {
        var keyboard = Keyboard()
        keyboard.keyDown(ShortcutEngine.escapeKeyCode)
        #expect(keyboard.commands.isEmpty)

        keyboard.modifiers([.option, .command])
        keyboard.modifiers([])
        keyboard.keyDown(ShortcutEngine.escapeKeyCode, after: 1)
        #expect(keyboard.commands == [.start(.handsFree), .discard])
    }

    @Test("Tap mode toggles on short taps only")
    func quickTapToggles() {
        var settings = ShortcutSettings.standard
        settings.quick.trigger = .toggle
        var keyboard = Keyboard(settings)

        keyboard.modifiers(.option)
        keyboard.modifiers([], after: 0.1)
        #expect(keyboard.phase == .recording(.quick))

        keyboard.modifiers(.option, after: 2)
        keyboard.modifiers([], after: 0.6)
        #expect(keyboard.phase == .recording(.quick))

        keyboard.modifiers(.option, after: 1)
        keyboard.modifiers([], after: 0.1)
        #expect(keyboard.commands == [.start(.quick), .stop])

        keyboard.modifiers(.option, after: 0.1)
        keyboard.modifiers([], after: 0.1)
        #expect(keyboard.commands == [.start(.quick), .stop, .start(.quick)])
    }

    @Test("Double tap needs two clean taps inside the window and acts as the second ends")
    func doubleTap() {
        var settings = ShortcutSettings.standard
        settings.quick.trigger = .doubleTap
        var keyboard = Keyboard(settings)

        keyboard.modifiers(.option)
        keyboard.modifiers([], after: 0.1)
        keyboard.modifiers(.option, after: 0.6)
        keyboard.modifiers([], after: 0.1)
        #expect(keyboard.commands.isEmpty)

        keyboard.keyDown(letterE, after: 0.1)
        keyboard.modifiers(.option, after: 0.1)
        keyboard.modifiers([], after: 0.1)
        #expect(keyboard.commands.isEmpty)

        keyboard.modifiers(.option, after: 0.1)
        keyboard.keyDown(letterE, .option)
        keyboard.modifiers([], after: 0.05)
        #expect(keyboard.commands.isEmpty)

        keyboard.modifiers(.option, after: 1)
        keyboard.modifiers([], after: 0.1)
        keyboard.modifiers(.option, after: 0.1)
        #expect(keyboard.commands.isEmpty)
        keyboard.modifiers([], after: 0.1)
        #expect(keyboard.commands == [.start(.quick)])

        keyboard.modifiers(.option, after: 2)
        keyboard.modifiers([], after: 0.1)
        keyboard.modifiers(.option, after: 0.1)
        keyboard.modifiers([], after: 0.1)
        #expect(keyboard.commands == [.start(.quick), .stop])
    }

    @Test("A hands-free double tap followed by a key is an app shortcut")
    func doubleTapThenKey() {
        var settings = ShortcutSettings.standard
        settings.handsFree.trigger = .doubleTap
        var keyboard = Keyboard(settings)

        keyboard.modifiers([.option, .command], after: 1)
        keyboard.modifiers([], after: 0.05)
        keyboard.modifiers([.option, .command], after: 0.1)
        keyboard.keyDown(124, [.option, .command])
        keyboard.modifiers([], after: 0.05)
        #expect(keyboard.commands.isEmpty)
    }

    @Test("A hands-free double tap on a chord starts and stops")
    func handsFreeDoubleTap() {
        var settings = ShortcutSettings.standard
        settings.handsFree.trigger = .doubleTap
        var keyboard = Keyboard(settings)

        for _ in 0..<2 {
            keyboard.modifiers(.command, after: 0.1)
            keyboard.modifiers([.command, .option])
            keyboard.modifiers([], after: 0.05)
        }
        #expect(keyboard.commands == [.start(.handsFree)])

        for _ in 0..<2 {
            keyboard.modifiers([.command, .option], after: 0.1)
            keyboard.modifiers([], after: 0.05)
        }
        #expect(keyboard.commands == [.start(.handsFree), .stop])
    }

    @Test("A key-based quick note held into the hands-free chord is promoted when the chord ends")
    func keyQuickNoteIntoChord() {
        var settings = ShortcutSettings.standard
        settings.quick = ShortcutBinding(shortcut: Shortcut(modifiers: [], key: .init(code: f5, name: "F5")), trigger: .hold)
        var keyboard = Keyboard(settings)

        keyboard.keyDown(f5)
        keyboard.waitForHold()
        keyboard.modifiers([.option, .command])
        keyboard.keyUp(f5)
        keyboard.modifiers([])

        #expect(keyboard.commands == [.start(.quick), .promoteToHandsFree])
    }

    @Test("A one-modifier hands-free shortcut used in an app shortcut doesn't block the next quick note")
    func singleModifierChordThenQuickNote() {
        var settings = ShortcutSettings.standard
        settings.handsFree = ShortcutBinding(shortcut: Shortcut(modifiers: .command), trigger: .toggle)
        var keyboard = Keyboard(settings)

        keyboard.modifiers(.command)
        keyboard.keyDown(8, .command)
        keyboard.modifiers([])
        keyboard.modifiers(.option, after: 0.5)
        keyboard.waitForHold()
        #expect(keyboard.commands == [.start(.quick)])
    }

    @Test("A key-based quick note with a modifier still promotes when its key is let go first")
    func modifiedKeyQuickNoteIntoChord() {
        var settings = ShortcutSettings.standard
        settings.quick = ShortcutBinding(shortcut: Shortcut(modifiers: .control, key: .init(code: f5, name: "F5")), trigger: .hold)
        var keyboard = Keyboard(settings)

        keyboard.modifiers(.control)
        keyboard.keyDown(f5, .control)
        keyboard.waitForHold()
        keyboard.modifiers([.control, .option, .command])
        keyboard.keyUp(f5)
        keyboard.modifiers([.control, .option])
        keyboard.modifiers([])

        #expect(keyboard.commands == [.start(.quick), .promoteToHandsFree])
    }

    @Test("Key shortcuts hold and toggle")
    func keyShortcuts() {
        var settings = ShortcutSettings.standard
        settings.quick = ShortcutBinding(shortcut: Shortcut(modifiers: [], key: .init(code: f5, name: "F5")), trigger: .hold)
        settings.handsFree = ShortcutBinding(
            shortcut: Shortcut(modifiers: .control, key: .init(code: space, name: "Space")),
            trigger: .toggle
        )
        var keyboard = Keyboard(settings)

        keyboard.keyDown(f5)
        keyboard.keyDown(f5)
        keyboard.waitForHold()
        keyboard.keyUp(f5, after: 1)
        #expect(keyboard.commands == [.start(.quick), .stop])

        keyboard.keyDown(space, .control, after: 1)
        keyboard.keyUp(space)
        keyboard.keyDown(space, .control, after: 1)
        #expect(keyboard.commands == [.start(.quick), .stop, .start(.handsFree), .stop])
    }

    @Test("While a session finishes, a new start waits; letting go, toggling again, or Escape cancels it")
    func finishingQueues() {
        #expect(RecordingCommand.resolve(.holdBegan, in: .finishing(queued: nil)) == .queue(.quick))
        #expect(RecordingCommand.resolve(.toggled(.handsFree), in: .finishing(queued: .quick)) == .queue(.handsFree))
        #expect(RecordingCommand.resolve(.toggled(.handsFree), in: .finishing(queued: .handsFree)) == .dropQueued)
        #expect(RecordingCommand.resolve(.holdEnded, in: .finishing(queued: .quick)) == .dropQueued)
        #expect(RecordingCommand.resolve(.holdEnded, in: .finishing(queued: .handsFree)) == .ignore)
        #expect(RecordingCommand.resolve(.discard, in: .finishing(queued: .handsFree)) == .dropQueued)
    }
}

@Suite("Shortcut settings")
struct ShortcutSettingsTests {
    @Test("Impossible triggers fall back and the delay is clamped")
    func normalization() {
        var settings = ShortcutSettings.standard
        settings.handsFree.trigger = .hold
        settings.quick = ShortcutBinding(
            shortcut: Shortcut(modifiers: .control, key: .init(code: space, name: "Space")),
            trigger: .doubleTap
        )
        settings.holdDelay = 3

        let normalized = settings.normalized
        #expect(normalized.handsFree.trigger == .toggle)
        #expect(normalized.quick.trigger == .hold)
        #expect(normalized.holdDelay == ShortcutSettings.holdDelayRange.upperBound)
    }

    @Test("Shortcuts must leave typing and app shortcuts alone and differ from each other")
    func conflicts() {
        let settings = ShortcutSettings.standard
        let key = { (modifiers: ModifierSet, code: UInt16) in Shortcut(modifiers: modifiers, key: .named(code: code, characters: "e")) }
        #expect(settings.conflict(assigning: .optionCommand, to: .quick) != nil)
        #expect(settings.conflict(assigning: key([], letterE), to: .quick) != nil)
        #expect(settings.conflict(assigning: key(.shift, letterE), to: .quick) != nil)
        #expect(settings.conflict(assigning: key(.option, letterE), to: .quick) != nil)
        #expect(settings.conflict(assigning: key(.command, letterE), to: .quick) != nil)
        #expect(settings.conflict(assigning: Shortcut(modifiers: .shift), to: .quick) != nil)
        #expect(settings.conflict(assigning: Shortcut(modifiers: .command), to: .handsFree) == nil)
        #expect(settings.conflict(assigning: key([], f5), to: .quick) == nil)
        #expect(settings.conflict(assigning: key(.control, space), to: .handsFree) == nil)
        #expect(settings.conflict(assigning: key([.command, .shift], letterE), to: .handsFree) == nil)
        #expect(settings.conflict(assigning: Shortcut(modifiers: [.control, .option]), to: .handsFree) == nil)

        var quickChord = ShortcutSettings.standard
        quickChord.quick.shortcut = Shortcut(modifiers: [.option, .control])
        #expect(quickChord.conflict(assigning: .option, to: .handsFree) != nil)
    }

    @Test("Keys are named the way macOS menus show them")
    func keyNames() {
        #expect(Shortcut(modifiers: .control, key: .named(code: space, characters: " ")).label == "⌃Space")
        #expect(Shortcut(modifiers: [], key: .named(code: f5, characters: nil)).label == "F5")
        #expect(Shortcut(modifiers: [.command, .shift], key: .named(code: letterE, characters: "e")).label == "⇧⌘E")
    }

    @Test("Hints follow the configured shortcuts in macOS symbol order")
    func hints() {
        var settings = ShortcutSettings.standard
        #expect(settings.startHint(for: .quick) == "Hold ⌥")
        #expect(settings.finishHint(for: .quick) == "Release ⌥ to finish")
        #expect(settings.startHint(for: .handsFree) == "Press ⌥⌘")
        #expect(settings.finishHint(for: .handsFree) == "Press ⌥⌘ to finish")

        settings.quick.trigger = .doubleTap
        settings.handsFree = ShortcutBinding(shortcut: Shortcut(modifiers: [.command, .shift, .control]), trigger: .toggle)
        #expect(settings.finishHint(for: .quick) == "Double-tap ⌥ to finish")
        #expect(settings.startHint(for: .handsFree) == "Press ⌃⇧⌘")
    }
}
