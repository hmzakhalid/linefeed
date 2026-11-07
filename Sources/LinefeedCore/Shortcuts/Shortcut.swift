import Foundation

/// The two ways to record. A recording keeps the mode of the shortcut that
/// started it until a quick recording is promoted to hands-free.
public enum RecordingMode: String, CaseIterable, Codable, Sendable {
    case quick
    case handsFree

    public var title: String {
        switch self {
        case .quick: return "Quick note"
        case .handsFree: return "Hands-free"
        }
    }
}

public struct ModifierSet: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let control = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let shift = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)

    /// Symbols in the order macOS menus use: ⌃⌥⇧⌘.
    public var symbols: String {
        [(ModifierSet.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { contains($0.0) }
            .map(\.1)
            .joined()
    }
}

public struct Shortcut: Hashable, Codable, Sendable {
    public struct Key: Hashable, Codable, Sendable {
        public let code: UInt16
        public let name: String

        public init(code: UInt16, name: String) {
            self.code = code
            self.name = name
        }

        /// A key named the way macOS menus show it; `characters` is what the
        /// key types, used for keys without a symbol of their own.
        public static func named(code: UInt16, characters: String?) -> Key {
            Key(code: code, name: functionKeys[code] ?? otherKeys[code] ?? (characters ?? "?").uppercased())
        }

        /// F1–F20 can stand alone without hijacking ordinary typing.
        public var isFunctionKey: Bool {
            Self.functionKeys[code] != nil
        }

        private static let functionKeys: [UInt16: String] = [
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
            106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
        ]

        private static let otherKeys: [UInt16: String] = [
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋", 76: "⌤",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        ]
    }

    public let modifiers: ModifierSet
    /// `nil` makes a modifier-only shortcut such as ⌥ or ⌥⌘.
    public let key: Key?

    public init(modifiers: ModifierSet, key: Key? = nil) {
        self.modifiers = modifiers
        self.key = key
    }

    public static let option = Shortcut(modifiers: .option)
    public static let optionCommand = Shortcut(modifiers: [.option, .command])

    public var label: String {
        modifiers.symbols + (key?.name ?? "")
    }

    public var isModifierOnly: Bool {
        key == nil
    }

    /// Why this shortcut would get in the way of typing or app shortcuts, or
    /// `nil` when it is fine. ⇧ and ⌥ change the characters a key types, and
    /// ⌘ plus one key belongs to the apps.
    public var interference: String? {
        let chord = [ModifierSet.control, .option, .shift, .command].filter(modifiers.contains)
        guard let key else {
            return modifiers.subtracting(.shift).isEmpty ? "Shift alone is part of typing. Add ⌃, ⌥ or ⌘." : nil
        }
        if key.isFunctionKey || modifiers.contains(.control) || (modifiers.contains(.command) && chord.count > 1) {
            return nil
        }
        return "Add ⌃, or ⌘ with another modifier, so typing and app shortcuts keep working. Function keys work alone."
    }
}

public enum TriggerMode: String, CaseIterable, Codable, Sendable {
    case hold
    case toggle
    case doubleTap
}

public struct ShortcutBinding: Equatable, Codable, Sendable {
    public var shortcut: Shortcut
    public var trigger: TriggerMode

    public init(shortcut: Shortcut, trigger: TriggerMode) {
        self.shortcut = shortcut
        self.trigger = trigger
    }
}

public struct ShortcutSettings: Equatable, Codable, Sendable {
    public static let holdDelayRange: ClosedRange<TimeInterval> = 0.05...0.5

    public var quick: ShortcutBinding
    public var handsFree: ShortcutBinding
    public var holdDelay: TimeInterval

    public init(quick: ShortcutBinding, handsFree: ShortcutBinding, holdDelay: TimeInterval) {
        self.quick = quick
        self.handsFree = handsFree
        self.holdDelay = holdDelay
    }

    public static let standard = ShortcutSettings(
        quick: ShortcutBinding(shortcut: .option, trigger: .hold),
        handsFree: ShortcutBinding(shortcut: .optionCommand, trigger: .toggle),
        holdDelay: 0.14
    )

    public func binding(for mode: RecordingMode) -> ShortcutBinding {
        switch mode {
        case .quick: return quick
        case .handsFree: return handsFree
        }
    }

    /// Hands-free recordings never stop on release, and a double tap needs a
    /// modifier-only shortcut because key presses repeat while held.
    public static func triggers(for mode: RecordingMode, shortcut: Shortcut) -> [TriggerMode] {
        let base: [TriggerMode] = mode == .quick ? [.hold, .toggle] : [.toggle]
        return shortcut.isModifierOnly ? base + [.doubleTap] : base
    }

    /// Settings as the engine will use them: impossible combinations fall back
    /// to the role's first trigger and the delay stays in range.
    public var normalized: ShortcutSettings {
        var result = self
        for mode in RecordingMode.allCases {
            let binding = binding(for: mode)
            let allowed = Self.triggers(for: mode, shortcut: binding.shortcut)
            if !allowed.contains(binding.trigger) {
                result.set(ShortcutBinding(shortcut: binding.shortcut, trigger: allowed[0]), for: mode)
            }
        }
        result.holdDelay = min(max(holdDelay, Self.holdDelayRange.lowerBound), Self.holdDelayRange.upperBound)
        return result
    }

    public mutating func set(_ binding: ShortcutBinding, for mode: RecordingMode) {
        switch mode {
        case .quick: quick = binding
        case .handsFree: handsFree = binding
        }
    }

    /// Why a proposed shortcut cannot be used for `mode`, or `nil` when it can.
    public func conflict(assigning shortcut: Shortcut, to mode: RecordingMode) -> String? {
        if let interference = shortcut.interference { return interference }
        let other: RecordingMode = mode == .quick ? .handsFree : .quick
        let otherShortcut = binding(for: other).shortcut
        if otherShortcut == shortcut {
            return "\(shortcut.label) already starts a \(other.title.lowercased()) recording."
        }
        let (quick, handsFree) = mode == .quick ? (shortcut, otherShortcut) : (otherShortcut, shortcut)
        if quick.isModifierOnly, handsFree.isModifierOnly, quick.modifiers.isStrictSuperset(of: handsFree.modifiers) {
            return "The hands-free shortcut can't be part of the quick-note one, or quick notes could never start."
        }
        return nil
    }

    public func startHint(for mode: RecordingMode) -> String {
        let binding = binding(for: mode)
        let label = binding.shortcut.label
        switch binding.trigger {
        case .hold: return "Hold \(label)"
        case .toggle: return mode == .quick && binding.shortcut.isModifierOnly ? "Tap \(label)" : "Press \(label)"
        case .doubleTap: return "Double-tap \(label)"
        }
    }

    public func finishHint(for mode: RecordingMode) -> String {
        let binding = binding(for: mode)
        let label = binding.shortcut.label
        switch binding.trigger {
        case .hold: return "Release \(label) to finish"
        case .toggle: return "\(startHint(for: mode)) to finish"
        case .doubleTap: return "Double-tap \(label) to finish"
        }
    }
}
