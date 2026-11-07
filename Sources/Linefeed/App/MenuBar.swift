import AppKit
import LinefeedCore

struct MenuBarActions {
    var copyLastSession: () -> Void
    var openHistory: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void
}

@MainActor
final class MenuBar: NSObject, NSMenuDelegate {
    /// A report's message replaces the ready status for this long.
    private static let messageLifetime: TimeInterval = 8

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: Settings
    private let recording: RecordingController
    private let speech: SpeechEngine
    private let microphones: Microphones
    private let store: SessionStore
    private let actions: MenuBarActions
    private var message: (text: String, at: Date)?
    private var pulseTimer: Timer?
    private var pulse = false

    init(
        settings: Settings,
        recording: RecordingController,
        speech: SpeechEngine,
        microphones: Microphones,
        store: SessionStore,
        actions: MenuBarActions
    ) {
        self.settings = settings
        self.recording = recording
        self.speech = speech
        self.microphones = microphones
        self.store = store
        self.actions = actions
        super.init()
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        item.button?.imageScaling = .scaleProportionallyDown
    }

    func show(message text: String) {
        message = (text, Date())
        refresh()
    }

    func refresh() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        if case .recording = recording.phase, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pulse.toggle()
                    self.item.button?.image = .menuBarMark(recording: self.pulse)
                }
            }
            pulseTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        let isRecording = if case .recording = recording.phase { true } else { false }
        item.button?.image = .menuBarMark(recording: isRecording)
        item.button?.toolTip = "Linefeed — \(status)"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        microphones.refresh()
        menu.removeAllItems()
        menu.addItem(disabled(status))
        menu.addItem(.separator())

        switch recording.phase {
        case .idle:
            menu.addItem(action(
                "Start Hands-Free Recording (\(settings.shortcuts.handsFree.shortcut.label))",
                enabled: settings.completedOnboarding && speech.state == .ready
            ) { [recording] in recording.perform(.start(.handsFree)) })
        case .recording:
            menu.addItem(action("Stop Recording") { [recording] in recording.perform(.stop) })
            menu.addItem(action("Discard Recording (Esc)") { [recording] in recording.perform(.discard) })
        case .finishing:
            menu.addItem(disabled("Finishing…"))
        }
        menu.addItem(.separator())
        menu.addItem(action("Copy Last Session", enabled: store.latest() != nil, perform: actions.copyLastSession))
        menu.addItem(action("History…", perform: actions.openHistory))
        menu.addItem(.separator())
        menu.addItem(submenu("Microphone", microphoneItems()))
        menu.addItem(submenu("Language", languageItems()))
        menu.addItem(.separator())
        menu.addItem(action("Settings…", key: ",", perform: actions.openSettings))
        menu.addItem(action("Quit Linefeed", key: "q", perform: actions.quit))
    }

    private var status: String {
        switch recording.phase {
        case .recording(let mode): return "Listening • \(settings.shortcuts.finishHint(for: mode))"
        case .finishing: return "Finishing…"
        case .idle: break
        }
        if let message, Date().timeIntervalSince(message.at) < Self.messageLifetime { return message.text }
        switch speech.state {
        case .checking: return "Checking speech…"
        case .loading: return "Getting speech ready…"
        case .downloading(let percent): return "Downloading speech… \(percent)%"
        case .missing: return "Speech needs a download • open Settings"
        case .failed: return "Speech couldn't load • open Settings"
        case .ready:
            return settings.completedOnboarding
                ? "Ready • \(settings.shortcuts.startHint(for: .quick)) to talk"
                : "Finish setup to start"
        }
    }

    private func microphoneItems() -> [NSMenuItem] {
        let enabled = recording.phase == .idle
        let automatic = action(microphones.label(for: nil), enabled: enabled) { [weak self] in
            self?.settings.microphoneID = nil
        }
        automatic.state = microphones.devices.contains { $0.uid == settings.microphoneID } ? .off : .on
        var items = [automatic]
        if !microphones.devices.isEmpty { items.append(.separator()) }
        for device in microphones.devices {
            let choice = action(device.name, enabled: enabled) { [weak self] in
                self?.settings.microphoneID = device.uid
            }
            choice.state = settings.microphoneID == device.uid ? .on : .off
            items.append(choice)
        }
        return items
    }

    private func languageItems() -> [NSMenuItem] {
        guard settings.speechModel.understandsEveryLanguage else {
            return [disabled("\(settings.speechModel.title) understands English only")]
        }
        return DictationLanguage.all.map { language in
            let choice = action(language.title, enabled: recording.phase == .idle) { [weak self] in
                self?.settings.language = language
            }
            choice.state = settings.language == language ? .on : .off
            return choice
        }
    }

    private func action(_ title: String, enabled: Bool = true, key: String = "", perform: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, keyEquivalent: key, perform: perform)
        item.isEnabled = enabled
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.autoenablesItems = false
        items.forEach(menu.addItem)
        parent.submenu = menu
        return parent
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let perform: () -> Void

    init(title: String, keyEquivalent: String, perform: @escaping () -> Void) {
        self.perform = perform
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        perform()
    }
}
