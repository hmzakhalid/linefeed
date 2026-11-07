import SwiftUI

struct SetupView: View {
    let flow: SetupFlow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var permissions: Permissions { flow.permissions }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            AmbientField()
                .opacity(flow.stage == .welcome ? 1 : 0.45)
                .animation(.easeInOut(duration: 0.55), value: flow.stage)

            VStack(spacing: 0) {
                topBar
                stageContent
                    .id(flow.stage)
                    .transition(stageTransition)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
        }
        .frame(width: 900, height: 640)
        .foregroundStyle(Theme.text)
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.88), value: flow.stage)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch flow.stage {
        case .welcome:
            WelcomeStage(shortcuts: flow.settings.shortcuts)
        case .microphone:
            PermissionStage(
                icon: "mic.fill",
                eyebrow: "1 of 3 · Microphone",
                title: "Let Linefeed hear you.",
                detail: "Your microphone is used only while you are recording.",
                privacyTitle: "Only when you start",
                privacyDetail: "Linefeed does not listen in the background, and your speech stays on this Mac.",
                readyDetail: "Microphone access is on",
                ready: permissions.granted.contains(.microphone)
            )
        case .screen:
            let handedOff = permissions.handedToSystemSettings.contains(.screenRecording)
            PermissionStage(
                icon: "rectangle.dashed.badge.record",
                eyebrow: "2 of 3 · Screen",
                title: "Add what you're pointing at.",
                detail: "Circle something while you speak to include a screenshot with your words.",
                privacyTitle: handedOff ? "Finish in System Settings" : "Only when you circle",
                privacyDetail: handedOff
                    ? "Turn on Linefeed under Screen Recording, then reopen it. Setup will continue here."
                    : "Linefeed takes a screenshot only after you draw a circle while recording.",
                readyDetail: "Screenshots are ready",
                ready: permissions.granted.contains(.screenRecording)
            )
        case .accessibility:
            let handedOff = permissions.handedToSystemSettings.contains(.accessibility)
            PermissionStage(
                icon: "cursorarrow.motionlines",
                eyebrow: "3 of 3 · Accessibility",
                title: "Use Linefeed anywhere.",
                detail: "This enables your shortcuts and lets Linefeed place text back in the app you're using.",
                privacyTitle: handedOff ? "Finish in System Settings" : "You stay in control",
                privacyDetail: handedOff
                    ? "Turn on Linefeed under Accessibility. Setup continues on its own."
                    : "You can turn off automatic text placement at any time.",
                readyDetail: "Shortcuts and text placement are ready",
                ready: permissions.granted.contains(.accessibility)
            )
        case .language:
            LanguageStage(settings: flow.settings)
        case .model:
            ModelStage(flow: flow)
        case .ready:
            ReadyStage(flow: flow)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            BrandMarkView().frame(width: 30, height: 30)
            DotMatrixText(text: "LINEFEED").frame(width: 70, height: 9)
            Spacer()
            if flow.stage != .welcome {
                Text(flow.stage.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text.opacity(0.76))
                StageProgress(current: flow.stage)
            }
        }
        .padding(.leading, 84)
        .padding(.trailing, 24)
        .frame(height: 58)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if flow.stage != .welcome {
                Button(action: flow.back) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(QuietButtonStyle())
            }
            Spacer()
            Label("Speech stays on this Mac", systemImage: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondary)
            Spacer()
            primaryAction
        }
        .padding(.horizontal, 24)
        .frame(height: 72)
        .background(Theme.background.opacity(0.9))
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch flow.stage {
        case .welcome:
            primary("Set Up Linefeed") { flow.go(to: .microphone) }
        case .microphone, .screen, .accessibility:
            permissionAction(for: flow.stage)
        case .language:
            primary("Continue") { flow.go(to: .model) }
        case .model:
            if flow.speechReady {
                primary("Continue") { flow.go(to: .ready) }
            } else {
                Button(modelButtonTitle, action: flow.downloadSpeech)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(flow.speech.isBusy)
            }
        case .ready:
            if flow.canFinish {
                primary(flow.isReturning ? "Close Setup" : "Start Linefeed", action: flow.finish)
            } else {
                primary("Review Setup") { flow.go(to: flow.firstIncompleteStage) }
            }
        }
    }

    @ViewBuilder
    private func permissionAction(for stage: SetupStage) -> some View {
        if let permission = stage.permission {
            if permissions.granted.contains(permission), let next = SetupStage(rawValue: stage.rawValue + 1) {
                primary("Continue") { flow.go(to: next) }
            } else if permissions.handedToSystemSettings.contains(permission) {
                HStack(spacing: 10) {
                    Button("Open System Settings") { permissions.openSystemSettings(for: permission) }
                        .buttonStyle(QuietButtonStyle())
                    if permission == .screenRecording {
                        primary("Restart Linefeed", action: flow.onRelaunch)
                    } else {
                        primary("Check Again", action: permissions.refresh)
                    }
                }
            } else {
                primary(allowTitle(for: permission)) { permissions.request(permission) }
            }
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
    }

    private func allowTitle(for permission: Permission) -> String {
        switch permission {
        case .microphone: return "Allow Microphone"
        case .screenRecording: return "Allow Screen Recording"
        case .accessibility: return "Allow Accessibility"
        }
    }

    private var modelButtonTitle: String {
        switch flow.speech.state {
        case .downloading(let percent): return "Downloading \(percent)%"
        case .checking, .loading: return "Getting ready…"
        case .missing, .ready: return "Download Speech"
        case .failed: return "Try Again"
        }
    }

    private var stageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}
