import Foundation

public enum KeyboardEvent: Equatable, Sendable {
    case modifiers(ModifierSet, at: TimeInterval)
    case keyDown(UInt16, modifiers: ModifierSet, at: TimeInterval)
    case keyUp(UInt16, at: TimeInterval)
    case pointerPressed
    case holdElapsed
}

/// What the person did with their shortcuts, before it is matched against
/// whatever Linefeed is doing at the time.
public enum ShortcutGesture: Equatable, Sendable {
    case holdBegan
    case holdEnded
    /// Another key was pressed while the quick shortcut was held: maybe a key
    /// combination after all, maybe a slip while talking.
    case holdInterrupted
    case toggled(RecordingMode)
    case discard
}

public enum ShortcutOutput: Equatable, Sendable {
    case scheduleHold(after: TimeInterval)
    case cancelHold
    case gesture(ShortcutGesture)
}

/// Turns raw keyboard events into gestures. It never owns a timer: it asks for
/// one with `.scheduleHold` and is told when it fires with `.holdElapsed`.
///
/// Modifier-only shortcuts act when they are let go untouched, and double
/// taps on the second release, so app shortcuts that share their modifiers
/// (⌥⌘I, ⌥⌘→) never toggle a recording. A quick note held when the
/// hands-free chord goes down belongs to the chord from then on: letting go
/// of the chord promotes it, or ends it as usual if the chord turned out to
/// be a key combination.
public struct ShortcutEngine: Sendable {
    public static let tapLimit: TimeInterval = 0.25
    public static let doubleTapWindow: TimeInterval = 0.4
    public static let escapeKeyCode: UInt16 = 53

    private enum HoldPhase: Sendable {
        case idle
        case pending
        case active
        case spent
    }

    public private(set) var settings: ShortcutSettings
    private var quickPress = PressTracker()
    private var handsFreePress = PressTracker()
    private var hold = HoldPhase.idle
    /// Set when the hands-free shortcut acts while the quick shortcut is down,
    /// so the rest of that press can't act again.
    private var chordLatched = false
    /// A held quick note now waiting on the hands-free chord's release.
    private var holdAbsorbed = false
    /// Keys left down after a chord are not a new quick-note press.
    private var quickArmBlocked = false

    public init(settings: ShortcutSettings) {
        self.settings = settings.normalized
    }

    public mutating func update(settings: ShortcutSettings) {
        self.settings = settings.normalized
        reset()
    }

    public mutating func reset() {
        quickPress = PressTracker()
        handsFreePress = PressTracker()
        hold = .idle
        chordLatched = false
        holdAbsorbed = false
        quickArmBlocked = false
    }

    public mutating func handle(_ event: KeyboardEvent) -> [ShortcutOutput] {
        switch event {
        case .modifiers(let modifiers, let now):
            return modifiersChanged(to: modifiers, at: now)
        case .keyDown(let code, let modifiers, let now):
            return keyDown(code, modifiers: modifiers, at: now)
        case .keyUp(let code, let now):
            return keyUp(code, at: now)
        case .pointerPressed:
            quickPress.interrupt()
            handsFreePress.interrupt()
            return cancelPendingHold() + (hold == .active ? [.gesture(.holdInterrupted)] : [])
        case .holdElapsed:
            guard hold == .pending else { return [] }
            hold = .active
            return [.gesture(.holdBegan)]
        }
    }

    private var quick: ShortcutBinding { settings.quick }
    private var handsFree: ShortcutBinding { settings.handsFree }

    /// Modifiers the hands-free chord may be pressed on top of: the quick
    /// shortcut's, so a held quick note can be promoted.
    private var chordAllowance: ModifierSet {
        quick.shortcut.isModifierOnly || quickPress.isDown || holdAbsorbed
            ? handsFree.shortcut.modifiers.union(quick.shortcut.modifiers)
            : handsFree.shortcut.modifiers
    }

    private mutating func modifiersChanged(to modifiers: ModifierSet, at now: TimeInterval) -> [ShortcutOutput] {
        if modifiers.isEmpty { quickArmBlocked = false }
        var output: [ShortcutOutput] = []
        if handsFree.shortcut.isModifierOnly {
            output += handsFreeModifiersChanged(to: modifiers, at: now)
        }
        if quick.shortcut.isModifierOnly {
            output += quickModifiersChanged(to: modifiers, at: now)
        }
        return output
    }

    private mutating func handsFreeModifiersChanged(to modifiers: ModifierSet, at now: TimeInterval) -> [ShortcutOutput] {
        let chord = handsFree.shortcut.modifiers
        let withinAllowance = chordAllowance.isSuperset(of: modifiers)
        let engaged = modifiers.isSuperset(of: chord) && withinAllowance
        var output: [ShortcutOutput] = []

        if engaged, !handsFreePress.isDown {
            handsFreePress.press(at: now)
            if quickPress.isDown {
                quickPress.interrupt()
                output += cancelPendingHold()
                holdAbsorbed = hold == .active && handsFree.trigger == .toggle
            }
        } else if handsFreePress.isDown, !engaged {
            if !withinAllowance {
                handsFreePress.interrupt()
            }
            let release = handsFreePress.release(at: now)
            let acts = handsFree.trigger == .doubleTap ? release.doubleTap : release.clean
            if acts, !chordLatched {
                output.append(.gesture(.toggled(.handsFree)))
                if holdAbsorbed { hold = .idle }
            }
            if holdAbsorbed {
                holdAbsorbed = false
                output += endHold()
            }
            if quickPress.isDown {
                chordLatched = true
            }
            quickArmBlocked = !modifiers.isEmpty
        }
        return output
    }

    private mutating func quickModifiersChanged(to modifiers: ModifierSet, at now: TimeInterval) -> [ShortcutOutput] {
        let shortcut = quick.shortcut.modifiers
        var output: [ShortcutOutput] = []

        if !quickPress.isDown {
            guard modifiers == shortcut, !quickArmBlocked else { return [] }
            quickPress.press(at: now)
            if quick.trigger == .hold {
                hold = .pending
                output.append(.scheduleHold(after: settings.holdDelay))
            }
        } else if !modifiers.isSuperset(of: shortcut) {
            let release = quickPress.release(at: now)
            if !holdAbsorbed {
                output += endHold()
            }
            let acts = switch quick.trigger {
            case .hold: false
            case .toggle: release.tap
            case .doubleTap: release.doubleTap
            }
            if acts {
                output.append(.gesture(.toggled(.quick)))
            }
            chordLatched = false
        } else if modifiers != shortcut {
            quickPress.interrupt()
            output += cancelPendingHold()
        }
        return output
    }

    private mutating func keyDown(_ code: UInt16, modifiers: ModifierSet, at now: TimeInterval) -> [ShortcutOutput] {
        if let key = handsFree.shortcut.key, key.code == code,
           modifiers.isSuperset(of: handsFree.shortcut.modifiers), chordAllowance.isSuperset(of: modifiers) {
            var output = cancelPendingHold()
            if !chordLatched {
                output.append(.gesture(.toggled(.handsFree)))
            }
            if quickPress.isDown {
                quickPress.interrupt()
                chordLatched = true
            }
            return output
        }

        if let key = quick.shortcut.key, key.code == code, modifiers == quick.shortcut.modifiers {
            guard !quickPress.isDown else { return [] }
            quickPress.press(at: now)
            switch quick.trigger {
            case .hold:
                hold = .pending
                return [.scheduleHold(after: settings.holdDelay)]
            case .toggle, .doubleTap:
                return [.gesture(.toggled(.quick))]
            }
        }

        // Any other key means the person is typing, not dictating.
        quickPress.interrupt()
        handsFreePress.interrupt()
        var output = cancelPendingHold()
        if code == Self.escapeKeyCode {
            output.append(.gesture(.discard))
        } else if hold == .active {
            output.append(.gesture(.holdInterrupted))
        }
        return output
    }

    private mutating func keyUp(_ code: UInt16, at now: TimeInterval) -> [ShortcutOutput] {
        guard let key = quick.shortcut.key, key.code == code, quickPress.isDown else { return [] }
        quickPress.release(at: now)
        chordLatched = false
        return holdAbsorbed ? [] : endHold()
    }

    private mutating func cancelPendingHold() -> [ShortcutOutput] {
        guard hold == .pending else { return [] }
        hold = .spent
        return [.cancelHold]
    }

    private mutating func endHold() -> [ShortcutOutput] {
        defer { hold = .idle }
        switch hold {
        case .pending: return [.cancelHold]
        case .active: return [.gesture(.holdEnded)]
        case .idle, .spent: return []
        }
    }
}

private struct PressTracker: Sendable {
    struct Release {
        /// Nothing else was pressed meanwhile.
        let clean: Bool
        /// Clean and short.
        let tap: Bool
        /// A tap that closely followed another.
        let doubleTap: Bool
    }

    private(set) var isDown = false
    private var downAt: TimeInterval = 0
    private var interrupted = false
    private var followsTap = false
    private var lastTapAt: TimeInterval?

    mutating func press(at now: TimeInterval) {
        followsTap = lastTapAt.map { now - $0 <= ShortcutEngine.doubleTapWindow } ?? false
        isDown = true
        downAt = now
        interrupted = false
        lastTapAt = nil
    }

    @discardableResult
    mutating func release(at now: TimeInterval) -> Release {
        guard isDown else { return Release(clean: false, tap: false, doubleTap: false) }
        isDown = false
        let clean = !interrupted
        let tap = clean && now - downAt <= ShortcutEngine.tapLimit
        let doubleTap = tap && followsTap
        lastTapAt = tap && !doubleTap ? now : nil
        return Release(clean: clean, tap: tap, doubleTap: doubleTap)
    }

    mutating func interrupt() {
        if isDown { interrupted = true }
        lastTapAt = nil
    }
}
