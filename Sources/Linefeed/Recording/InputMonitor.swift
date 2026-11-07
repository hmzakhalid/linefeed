import AppKit
import Carbon.HIToolbox
import LinefeedCore

/// Shortcuts with a key are registered as system hot keys so the key never
/// reaches other apps; modifier-only shortcuts can't be, so they are watched.
@MainActor
final class InputMonitor {
    private var engine: ShortcutEngine
    private var monitors: [Any] = []
    private var holdTimer: Timer?
    private let hotKeys = HotKeys()
    var onGesture: (ShortcutGesture) -> Void = { _ in }
    /// Another app or macOS already owns this key combination.
    var onUnavailableShortcut: (Shortcut) -> Void = { _ in }

    init(shortcuts: ShortcutSettings) {
        engine = ShortcutEngine(settings: shortcuts)
        hotKeys.onPress = { [weak self] shortcut in
            guard let key = shortcut.key else { return }
            self?.handle(.keyDown(key.code, modifiers: shortcut.modifiers, at: ProcessInfo.processInfo.systemUptime))
        }
        hotKeys.onRelease = { [weak self] shortcut in
            guard let key = shortcut.key else { return }
            self?.handle(.keyUp(key.code, at: ProcessInfo.processInfo.systemUptime))
        }
    }

    private func registerHotKeys() {
        let failed = hotKeys.register([engine.settings.quick.shortcut, engine.settings.handsFree.shortcut])
        failed.forEach(onUnavailableShortcut)
    }

    var isRunning: Bool { !monitors.isEmpty }

    func update(_ shortcuts: ShortcutSettings) {
        cancelHold()
        engine.update(settings: shortcuts)
        if isRunning { registerHotKeys() }
    }

    /// Global monitors only receive events once Accessibility is granted, so
    /// this is safe to call again after that happens.
    func start() {
        stop()
        let flags: (NSEvent) -> Void = { [weak self] event in
            self?.handle(.modifiers(ModifierSet(event.modifierFlags), at: event.timestamp))
        }
        let keyDown: (NSEvent) -> Void = { [weak self] event in
            guard !event.isARepeat else { return }
            self?.handle(.keyDown(event.keyCode, modifiers: ModifierSet(event.modifierFlags), at: event.timestamp))
        }
        let keyUp: (NSEvent) -> Void = { [weak self] event in
            self?.handle(.keyUp(event.keyCode, at: event.timestamp))
        }
        let pointer: (NSEvent) -> Void = { [weak self] _ in
            self?.handle(.pointerPressed)
        }
        let handlers: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.flagsChanged, flags), (.keyDown, keyDown), (.keyUp, keyUp),
            ([.leftMouseDown, .rightMouseDown, .otherMouseDown], pointer),
        ]
        for (mask, handler) in handlers {
            if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
                MainActor.assumeIsolated { handler(event) }
            }) {
                monitors.append(global)
            }
            if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
                MainActor.assumeIsolated { handler(event) }
                return event
            }) {
                monitors.append(local)
            }
        }
        registerHotKeys()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        hotKeys.unregisterAll()
        cancelHold()
        engine.reset()
    }

    private func handle(_ event: KeyboardEvent) {
        for output in engine.handle(event) {
            switch output {
            case .scheduleHold(let delay):
                cancelHold()
                let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.holdTimer = nil
                        self?.handle(.holdElapsed)
                    }
                }
                holdTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            case .cancelHold:
                cancelHold()
            case .gesture(let gesture):
                onGesture(gesture)
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
    }
}

extension ModifierSet {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }
}

@MainActor
private final class HotKeys {
    var onPress: (Shortcut) -> Void = { _ in }
    var onRelease: (Shortcut) -> Void = { _ in }
    private var registered: [UInt32: (reference: EventHotKeyRef, shortcut: Shortcut)] = [:]
    private var handler: EventHandlerRef?

    /// Returns the shortcuts macOS refused to register.
    @discardableResult
    func register(_ shortcuts: [Shortcut]) -> [Shortcut] {
        unregisterAll()
        installHandlerIfNeeded()
        var refused: [Shortcut] = []
        for (index, shortcut) in shortcuts.enumerated() {
            guard let key = shortcut.key else { continue }
            var reference: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: OSType(0x4C4E_4644), id: UInt32(index))
            let status = RegisterEventHotKey(
                UInt32(key.code),
                carbonModifiers(shortcut.modifiers),
                identifier,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                registered[identifier.id] = (reference, shortcut)
            } else {
                refused.append(shortcut)
            }
        }
        return refused
    }

    func unregisterAll() {
        registered.values.forEach { UnregisterEventHotKey($0.reference) }
        registered.removeAll()
    }

    fileprivate func receive(identifier: UInt32, pressed: Bool) {
        guard let shortcut = registered[identifier]?.shortcut else { return }
        pressed ? onPress(shortcut) : onRelease(shortcut)
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        let types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            types.count,
            types,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }

    private func carbonModifiers(_ modifiers: ModifierSet) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

private func hotKeyEventHandler(
    _ call: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
    )
    guard status == noErr else { return status }
    let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
    let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        hotKeys.receive(identifier: identifier.id, pressed: pressed)
    }
    return noErr
}
