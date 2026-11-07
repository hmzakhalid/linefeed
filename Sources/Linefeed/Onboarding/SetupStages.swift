import LinefeedCore
import SwiftUI

struct WelcomeStage: View {
    let shortcuts: ShortcutSettings

    var body: some View {
        HStack(spacing: 44) {
            VStack(alignment: .leading, spacing: 18) {
                Eyebrow(text: "Voice, with context")
                Text("Say it.\nPoint at it. Done.")
                    .font(.system(size: 46, weight: .semibold))
                    .tracking(-2.15)
                Text("Speak naturally in any app. Circle something when your words need the screen. Linefeed brings both back together.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 365, alignment: .leading)
                WelcomeFlow(quickShortcut: shortcuts.quick.shortcut.label)
                HStack(spacing: 16) {
                    WelcomeFact(icon: "lock.fill", title: "Private")
                    WelcomeFact(icon: "scope", title: "Screen-aware")
                    WelcomeFact(icon: "text.cursor", title: "Works anywhere")
                }
            }
            WelcomeIslandPreview().frame(width: 348, height: 294)
        }
        .padding(.horizontal, 42)
    }
}

struct PermissionStage: View {
    let icon: String
    let eyebrow: String
    let title: String
    let detail: String
    let privacyTitle: String
    let privacyDetail: String
    let readyDetail: String
    let ready: Bool

    var body: some View {
        HStack(spacing: 62) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(ready ? "READY" : "PERMISSION")
                    Spacer()
                    Text(ready ? "ALLOWED" : "NOT YET").foregroundStyle(ready ? Theme.text : Theme.secondary)
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 16)
                .frame(height: 39)

                Rectangle().fill(Theme.stroke).frame(height: 1)
                Spacer()
                Image(systemName: ready ? "checkmark" : icon)
                    .font(.system(size: 44, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(ready ? Theme.text : Theme.secondary.opacity(0.45)).frame(width: 6, height: 6)
                    Text(ready ? "Ready to continue" : "Waiting for you")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ready ? Theme.text : Theme.secondary)
                .padding(16)
            }
            .frame(width: 238, height: 248)
            .background(Theme.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke) }

            VStack(alignment: .leading, spacing: 17) {
                Eyebrow(text: eyebrow)
                Text(title)
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(-1.35)
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Image(systemName: ready ? "checkmark.circle.fill" : "hand.raised.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(ready ? Theme.text : Theme.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ready ? "Ready" : privacyTitle).font(.system(size: 13, weight: .semibold))
                        Text(ready ? readyDetail : privacyDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(15)
                .glassCard(cornerRadius: 14)
            }
            .frame(width: 430, alignment: .leading)
        }
        .padding(.horizontal, 64)
    }
}

struct LanguageStage: View {
    @Bindable var settings: Settings
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Language")
                Text("What language do you speak most?")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-1.15)
                Text(settings.speechModel.understandsEveryLanguage
                     ? "Pick one to steer recognition, or Automatic if you switch languages."
                     : "\(settings.speechModel.title) understands English. Choose Accurate on the next step for other languages.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(DictationLanguage.all) { language in
                        LanguageButton(language: language, selected: language == settings.language) {
                            settings.language = language
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 58)
        .padding(.top, 24)
    }
}

private struct LanguageButton: View {
    let language: DictationLanguage
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(language.title).font(.system(size: 12, weight: .semibold))
                    Text(language.nativeTitle).font(.system(size: 10)).foregroundStyle(Theme.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .contentShape(Rectangle())
            .background(selected ? Theme.accent.opacity(0.10) : Theme.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11).stroke(selected ? Theme.accent.opacity(0.62) : Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ModelStage: View {
    let flow: SetupFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Speech")
                Text("Choose how Linefeed listens.")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-1.15)
                Text("Everything runs on this Mac. Each model downloads once.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
            }
            SpeechModelPicker(settings: flow.settings, speech: flow.speech)
            SpeechStatusRow(settings: flow.settings, speech: flow.speech)
        }
        .padding(.horizontal, 58)
        .padding(.vertical, 20)
    }
}

struct SpeechModelPicker: View {
    @Bindable var settings: Settings
    let speech: SpeechEngine

    var body: some View {
        HStack(spacing: 12) {
            ForEach(SpeechModel.allCases) { model in
                ModelCard(model: model, installed: speech.isInstalled(model), selected: model == settings.speechModel) {
                    settings.speechModel = model
                }
                .disabled(speech.isBusy && model != settings.speechModel)
                .opacity(speech.isBusy && model != settings.speechModel ? 0.58 : 1)
            }
        }
    }
}

struct SpeechStatusRow: View {
    let settings: Settings
    let speech: SpeechEngine

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 42, height: 42)
                if speech.isBusy {
                    ProgressView().controlSize(.small).tint(Theme.accent)
                } else {
                    Image(systemName: speech.state == .ready ? "checkmark" : "arrow.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(headline).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(2)
            }
            Spacer()
            if case .downloading(let percent) = speech.state {
                Text("\(percent)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
        }
        .padding(15)
        .glassCard(cornerRadius: 16)
    }

    private var headline: String {
        let title = settings.speechModel.title
        switch speech.state {
        case .checking: return "Checking what is ready…"
        case .missing: return "\(title) needs a download"
        case .downloading: return "Downloading \(title)…"
        case .loading: return "Getting \(title) ready…"
        case .ready: return "\(title) is ready"
        case .failed: return "\(title) couldn't be prepared"
        }
    }

    private var detail: String {
        switch speech.state {
        case .checking, .loading: return "This usually takes a moment."
        case .missing: return "Download it once, then use Linefeed whenever you like."
        case .downloading: return "You can start as soon as this finishes."
        case .ready: return "You're ready to use Linefeed."
        case .failed: return "Check your connection and available storage, then try again."
        }
    }
}

private struct ModelCard: View {
    let model: SpeechModel
    let installed: Bool
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: model.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selected ? Theme.accent : Theme.text)
                    Spacer()
                    if installed {
                        Label("ON THIS MAC", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title).font(.system(size: 19, weight: .semibold))
                    Text(model.detail).font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                Text(model.badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.secondary)
                HStack {
                    Text(selected ? "Selected" : "Choose").font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                }
                .foregroundStyle(selected ? Theme.accent : Theme.secondary)
            }
            .padding(17)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.08) : Theme.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15).stroke(selected ? Theme.accent.opacity(0.62) : Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ReadyStage: View {
    let flow: SetupFlow

    var body: some View {
        let shortcuts = flow.settings.shortcuts
        VStack(spacing: 22) {
            LiveIslandPreview().frame(width: 430, height: 110)
            VStack(spacing: 7) {
                Text(flow.canFinish ? "You're ready." : "One thing needs your attention.")
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(-1.35)
                Text(flow.canFinish
                     ? "Linefeed will stay quietly in your menu bar until you need it."
                     : "Finish the item that is not ready, then come back here.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
            }
            HStack(spacing: 10) {
                ReadinessPill(icon: "mic.fill", title: "Microphone", ready: flow.permissions.granted.contains(.microphone))
                ReadinessPill(icon: "scope", title: "Screenshots", ready: flow.permissions.granted.contains(.screenRecording))
                ReadinessPill(icon: "cursorarrow.rays", title: "Shortcuts", ready: flow.permissions.granted.contains(.accessibility))
                ReadinessPill(icon: "waveform", title: "Speech", ready: flow.speechReady)
            }
            HStack(spacing: 12) {
                ShortcutCard(keys: shortcuts.quick.shortcut.label, title: shortcuts.startHint(for: .quick), detail: shortcuts.finishHint(for: .quick))
                ShortcutCard(keys: shortcuts.handsFree.shortcut.label, title: "Hands-free", detail: shortcuts.startHint(for: .handsFree) + " to start or finish")
                ShortcutCard(keys: "◯", title: "Add context", detail: "Circle while speaking")
            }
            .frame(width: 720)
        }
        .padding(.top, 10)
    }
}
