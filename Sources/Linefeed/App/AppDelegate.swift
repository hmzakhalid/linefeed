import AppKit
import LinefeedCore

/// Builds Linefeed's parts and connects them. Behavior lives in the parts;
/// this file only decides who hears about what.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let permissions = Permissions()
    private let microphones = Microphones()
    private let store = SessionStore()
    private let vocabulary = VocabularyStore()
    private let notice = RecoveryNotice()
    private lazy var speech = SpeechEngine(model: settings.speechModel)
    private lazy var recording = RecordingController(
        settings: settings,
        speech: speech,
        microphones: microphones,
        store: store,
        vocabulary: vocabulary
    )
    private lazy var input = InputMonitor(shortcuts: settings.shortcuts)
    private lazy var setup = SetupFlow(settings: settings, permissions: permissions, speech: speech)
    private lazy var setupWindow = BrandWindow(title: "Linefeed Setup") { [setup] in SetupView(flow: setup) }
    private lazy var history = HistoryWindow(store: store)
    private lazy var settingsWindow = BrandWindow(title: "Linefeed Settings") { [unowned self] in
        SettingsView(
            settings: settings,
            speech: speech,
            permissions: permissions,
            microphones: microphones,
            vocabulary: vocabulary,
            store: store,
            actions: SettingsActions(
                openSetup: { [unowned self] in showSetup() },
                openHistory: { [unowned self] in history.show() },
                clearHistory: { [unowned self] in clearHistory() },
                editVocabulary: { [unowned self] in try? vocabulary.openForEditing() },
                recordingShortcut: { [unowned self] recordingShortcut in
                    recordingShortcut ? input.stop() : startListeningForShortcuts()
                }
            )
        )
    }
    private lazy var menuBar = MenuBar(
        settings: settings,
        recording: recording,
        speech: speech,
        microphones: microphones,
        store: store,
        actions: MenuBarActions(
            copyLastSession: { [unowned self] in copyLastSession() },
            openHistory: { [unowned self] in history.show() },
            openSettings: { [unowned self] in settingsWindow.show() },
            quit: { NSApplication.shared.terminate(nil) }
        )
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second copy would sweep the first one's unfinished recording.
        guard AppDirectory.claimSingleInstance() else {
            NSApplication.shared.terminate(nil)
            return
        }
        AudioRecorder.removeAbandonedRecordings()
        store.removeAbandonedDrafts()
        try? store.prune()
        connect()
        menuBar.refresh()

        if !speech.isInstalled(settings.speechModel),
           let installed = SpeechModel.allCases.first(where: speech.isInstalled) {
            settings.speechModel = installed
        }
        Task { await speech.prepare(settings.speechModel) }

        startListeningForShortcuts()
        if !settings.completedOnboarding || !permissions.allGranted {
            showSetup()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissions.refresh()
    }

    /// A recording that is still finishing gets to save before Linefeed quits.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        recording.perform(.discard)
        guard case .finishing = recording.phase else { return .terminateNow }
        recording.perform(.dropQueued)
        recording.whenIdle = { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        input.stop()
    }

    private func connect() {
        input.onGesture = { [unowned self] gesture in recording.handle(gesture) }
        recording.onPhaseChange = { [unowned self] in menuBar.refresh() }
        recording.onSessionSaved = { [unowned self] in history.refresh() }
        recording.onReport = { [unowned self] report in
            menuBar.show(message: report.status)
            if let notice = report.notice {
                self.notice.show(notice, perform: perform)
            }
        }
        settings.observe(\.shortcuts) { [unowned self] in input.update(settings.shortcuts) }
        input.onUnavailableShortcut = { [unowned self] shortcut in
            notice.show(
                RecordingReport.Notice(
                    title: "\(shortcut.label) is taken",
                    detail: "Another app or macOS already uses it. Choose a different shortcut.",
                    action: .openSettings
                ),
                perform: perform
            )
        }
        settings.observe(\.speechModel) { [unowned self] in
            Task { await speech.prepare(settings.speechModel) }
        }
        permissions.onGranted = { [unowned self] permission in
            if permission == .accessibility { startListeningForShortcuts() }
            if setupWindow.isVisible {
                setup.permissionGranted(permission)
                setupWindow.show()
            }
        }
        setupWindow.onClose = { [unowned self] in permissions.stopWatching() }
        setup.onFinish = { [unowned self] in
            setupWindow.close()
            startListeningForShortcuts()
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            menuBar.refresh()
        }
        setup.onRelaunch = { [unowned self] in relaunch() }
    }

    /// Shortcuts wait for setup, and global key monitoring needs Accessibility.
    private func startListeningForShortcuts() {
        guard settings.completedOnboarding, permissions.granted.contains(.accessibility) else { return }
        input.start()
    }

    private func showSetup() {
        setup.resume()
        setupWindow.show()
        permissions.startWatching()
    }

    private func perform(_ action: RecordingReport.Notice.Action) {
        switch action {
        case .openSetup: showSetup()
        case .openSettings: settingsWindow.show()
        case .openHistory: history.show()
        case .openScreenRecordingSettings: permissions.openSystemSettings(for: .screenRecording)
        }
    }

    private func copyLastSession() {
        guard let session = store.latest() else { return }
        menuBar.show(message: Clipboard.copy(session) ? "Last session copied" : "Nothing to copy")
    }

    private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all Linefeed history?"
        alert.informativeText = "This permanently removes every saved transcript and screenshot."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try store.clear()
            history.refresh()
            menuBar.show(message: "History cleared")
        } catch {
            notice.show(
                RecordingReport.Notice(title: "Couldn't clear History", detail: "Close any open Linefeed files and try again.", action: .openHistory),
                perform: perform
            )
        }
    }

    /// macOS applies a new Screen Recording grant only to a fresh launch. The
    /// new copy opens once this one has exited, so only one ever runs.
    private func relaunch() {
        let bundle = Bundle.main.bundleURL
        guard bundle.pathExtension == "app" else { return }
        let opener = Process()
        opener.executableURL = URL(fileURLWithPath: "/bin/sh")
        opener.arguments = [
            "-c",
            "while /bin/kill -0 \"$0\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$1\"",
            String(ProcessInfo.processInfo.processIdentifier),
            bundle.path,
        ]
        guard (try? opener.run()) != nil else { return }
        NSApplication.shared.terminate(nil)
    }
}
