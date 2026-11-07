import LinefeedCore
import ServiceManagement
import SwiftUI

struct SettingsActions {
    var openSetup: () -> Void
    var openHistory: () -> Void
    var clearHistory: () -> Void
    var editVocabulary: () -> Void
    /// Pauses global shortcuts while a new one is being recorded.
    var recordingShortcut: (Bool) -> Void
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case speech
    case writing
    case island
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .speech: return "Speech"
        case .writing: return "Writing"
        case .island: return "Island"
        case .history: return "History"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .speech: return "waveform"
        case .writing: return "text.alignleft"
        case .island: return "capsule.tophalf.filled"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

struct SettingsView: View {
    @Bindable var settings: Settings
    let speech: SpeechEngine
    let permissions: Permissions
    let microphones: Microphones
    let vocabulary: VocabularyStore
    let store: SessionStore
    let actions: SettingsActions
    @State private var section = SettingsSection.general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.stroke).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(text: section.title)
                    content
                }
                .padding(.horizontal, 26)
                .padding(.top, 40)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 880, height: 600)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                BrandMarkView().frame(width: 26, height: 26)
                DotMatrixText(text: "LINEFEED").frame(width: 64, height: 8)
            }
            .padding(.horizontal, 10)
            .padding(.top, 44)
            .padding(.bottom, 18)
            ForEach(SettingsSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    Label(item.title, systemImage: item.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(section == item ? Theme.text.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(section == item ? Theme.text : Theme.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(width: 200)
        .background(Color.black.opacity(0.22))
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general: general
        case .shortcuts: ShortcutSettingsSection(settings: settings, recordingShortcut: actions.recordingShortcut)
        case .speech: speechSection
        case .writing: writing
        case .island: IslandSettingsSection(settings: settings)
        case .history: history
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup {
                SettingsRow(title: "Microphone", detail: "Automatic prefers a connected external microphone") {
                    Picker("Microphone", selection: $settings.microphoneID) {
                        Text(microphones.label(for: nil)).tag(String?.none)
                        ForEach(microphones.devices, id: \.uid) { Text($0.name).tag(String?.some($0.uid)) }
                    }
                    .labelsHidden()
                    .frame(width: 260)
                }
                SettingsToggle(
                    title: "Place text where you're typing",
                    detail: "Otherwise each session waits on your clipboard",
                    isOn: $settings.insertsAutomatically
                )
                SettingsToggle(title: "Sounds", detail: "A soft cue when listening starts and stops", isOn: $settings.playsSounds)
                LaunchAtLoginToggle()
            }
            SettingsGroup {
                ForEach(Permission.allCases, id: \.self) { permission in
                    SettingsRow(title: permission.title, detail: permission.purpose) {
                        if permissions.granted.contains(permission) {
                            Label("Allowed", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.secondary)
                        } else {
                            Button("Open Setup", action: actions.openSetup).buttonStyle(QuietButtonStyle())
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Open Setup", action: actions.openSetup).buttonStyle(QuietButtonStyle())
            }
        }
        .onAppear {
            microphones.refresh()
            permissions.refresh()
        }
    }

    private var speechSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SpeechModelPicker(settings: settings, speech: speech)
            HStack(spacing: 12) {
                SpeechStatusRow(settings: settings, speech: speech)
                if speech.state == .missing || speech.state == .failed {
                    Button(speech.state == .failed ? "Try Again" : "Download") {
                        Task { await speech.prepare(settings.speechModel, downloading: true) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            SettingsGroup {
                SettingsRow(
                    title: "Language",
                    detail: settings.speechModel.understandsEveryLanguage
                        ? "Steers recognition toward one language"
                        : "\(settings.speechModel.title) understands English only"
                ) {
                    Picker("Language", selection: $settings.language) {
                        ForEach(DictationLanguage.all) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                    .disabled(!settings.speechModel.understandsEveryLanguage)
                }
            }
        }
    }

    private var writing: some View {
        let smart = SmartCleanup.availability
        return VStack(alignment: .leading, spacing: 16) {
            SettingsGroup {
                SettingsRow(title: "Style", detail: settings.writingStyle.detail) {
                    Picker("Style", selection: $settings.writingStyle) {
                        ForEach(WritingStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                if smart != .requiresNewerMacOS {
                    SettingsToggle(
                        title: "Smart cleanup",
                        detail: smart == .available
                            ? "Apple Intelligence smooths grammar on this Mac, after the Polished rules"
                            : smart.explanation,
                        isOn: $settings.usesSmartCleanup
                    )
                    .disabled(smart != .available || !settings.writingStyle.allowsSmartCleanup)
                }
            }
            SettingsGroup {
                SettingsToggle(
                    title: "Fix technical terms",
                    detail: "GitHub, JSON, macOS, npm and other words speech models miscase",
                    isOn: $settings.fixesTechnicalTerms
                )
                SettingsRow(
                    title: "Your vocabulary",
                    detail: vocabulary.terms.isEmpty
                        ? "Teach Linefeed names and terms it mishears"
                        : "\(vocabulary.terms.count) of your own corrections"
                ) {
                    Button("Edit Vocabulary…", action: actions.editVocabulary).buttonStyle(QuietButtonStyle())
                }
            }
        }
    }

    private var history: some View {
        let used = ByteCountFormatter.string(fromByteCount: store.usedBytes, countStyle: .file)
        let limit = ByteCountFormatter.string(fromByteCount: SessionStore.budget.maxBytes, countStyle: .file)
        return VStack(alignment: .leading, spacing: 16) {
            SettingsGroup {
                SettingsRow(title: "Stored on this Mac", detail: "\(used) of \(limit). The oldest sessions make room first.") {
                    Button("Show in Finder") {
                        try? FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(store.root)
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                SettingsRow(title: "Sessions", detail: "Search, copy, and revisit what you said") {
                    HStack(spacing: 8) {
                        Button("Clear…", action: actions.clearHistory).buttonStyle(QuietButtonStyle())
                        Button("Open History", action: actions.openHistory).buttonStyle(QuietButtonStyle())
                    }
                }
            }
        }
    }
}

private struct ShortcutSettingsSection: View {
    @Bindable var settings: Settings
    let recordingShortcut: (Bool) -> Void
    @State private var capturing: RecordingMode?

    var body: some View {
        content
            .onChange(of: capturing) { _, mode in recordingShortcut(mode != nil) }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                capturing = nil
            }
            .onDisappear {
                capturing = nil
                recordingShortcut(false)
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(RecordingMode.allCases, id: \.self) { mode in
                SettingsGroup {
                    SettingsRow(title: mode.title, detail: purpose(of: mode)) {
                        ShortcutRecorder(
                            shortcut: settings.shortcuts.binding(for: mode).shortcut,
                            isCapturing: Binding(
                                get: { capturing == mode },
                                set: { wanted in
                                    if wanted {
                                        capturing = mode
                                    } else if capturing == mode {
                                        capturing = nil
                                    }
                                }
                            ),
                            validate: { settings.shortcuts.conflict(assigning: $0, to: mode) },
                            onChange: { shortcut in
                                var shortcuts = settings.shortcuts
                                shortcuts.set(ShortcutBinding(shortcut: shortcut, trigger: shortcuts.binding(for: mode).trigger), for: mode)
                                settings.shortcuts = shortcuts.normalized
                            }
                        )
                    }
                    SettingsRow(title: "Trigger", detail: triggerDetail(for: mode)) {
                        Picker("Trigger", selection: trigger(for: mode)) {
                            ForEach(ShortcutSettings.triggers(for: mode, shortcut: settings.shortcuts.binding(for: mode).shortcut), id: \.self) {
                                Text(title(for: $0, mode: mode)).tag($0)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                    if mode == .quick, settings.shortcuts.quick.trigger == .hold {
                        SettingsRow(title: "Hold delay", detail: "\(Int(settings.shortcuts.holdDelay * 1_000)) ms before listening starts") {
                            Slider(value: $settings.shortcuts.holdDelay, in: ShortcutSettings.holdDelayRange, step: 0.01)
                                .frame(width: 240)
                        }
                    }
                }
            }
            Text(help)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            HStack {
                Spacer()
                Button("Restore Defaults") { settings.shortcuts = .standard }.buttonStyle(QuietButtonStyle())
            }
        }
    }

    private var help: String {
        let shortcuts = settings.shortcuts
        guard shortcuts.quick.trigger == .hold, shortcuts.handsFree.trigger == .toggle else {
            return "Esc discards a recording."
        }
        return "Esc discards a recording. While holding \(shortcuts.quick.shortcut.label), "
            + "press \(shortcuts.handsFree.shortcut.label) to keep talking hands-free."
    }

    private func purpose(of mode: RecordingMode) -> String {
        switch mode {
        case .quick: return "A quick thought, placed where you're typing"
        case .handsFree: return "Longer explanations with your hands free"
        }
    }

    private func trigger(for mode: RecordingMode) -> Binding<TriggerMode> {
        Binding(
            get: { settings.shortcuts.binding(for: mode).trigger },
            set: { trigger in
                var shortcuts = settings.shortcuts
                shortcuts.set(ShortcutBinding(shortcut: shortcuts.binding(for: mode).shortcut, trigger: trigger), for: mode)
                settings.shortcuts = shortcuts
            }
        )
    }

    private func title(for trigger: TriggerMode, mode: RecordingMode) -> String {
        switch trigger {
        case .hold: return "Hold"
        case .toggle: return mode == .quick ? "Tap" : "Press"
        case .doubleTap: return "Double-tap"
        }
    }

    private func triggerDetail(for mode: RecordingMode) -> String {
        switch settings.shortcuts.binding(for: mode).trigger {
        case .hold: return "Talk while you hold it"
        case .toggle: return "Once to start, again to finish"
        case .doubleTap: return "Two quick taps to start or finish"
        }
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var isOn = SMAppService.mainApp.status == .enabled
    @State private var problem: String?

    var body: some View {
        SettingsToggle(
            title: "Open at login",
            detail: problem ?? "Keep Linefeed ready in the menu bar",
            isOn: Binding(
                get: { isOn },
                set: { wanted in
                    do {
                        try wanted ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        problem = nil
                    } catch {
                        problem = "macOS didn't allow that. Move Linefeed to Applications and try again."
                    }
                    isOn = SMAppService.mainApp.status == .enabled
                }
            )
        )
    }
}

extension Permission {
    var title: String {
        switch self {
        case .microphone: return "Microphone"
        case .screenRecording: return "Screen Recording"
        case .accessibility: return "Accessibility"
        }
    }

    var purpose: String {
        switch self {
        case .microphone: return "Hears you while you record"
        case .screenRecording: return "Takes a screenshot when you circle something"
        case .accessibility: return "Runs your shortcuts and places text"
        }
    }
}

/// Rows on one card. Each row draws a divider beneath itself; the card hides
/// the last one under its edge.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.bottom, -1)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke) }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 58)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 16) }
    }
}

struct SettingsToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title, detail: detail) {
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}
