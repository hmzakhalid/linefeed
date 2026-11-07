import Foundation
import Observation

enum SetupStage: Int, CaseIterable, Comparable, Identifiable {
    case welcome
    case microphone
    case screen
    case accessibility
    case language
    case model
    case ready

    var id: Int { rawValue }

    static func < (lhs: SetupStage, rhs: SetupStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .microphone: return "Microphone"
        case .screen: return "Screen"
        case .accessibility: return "Accessibility"
        case .language: return "Language"
        case .model: return "Speech"
        case .ready: return "Ready"
        }
    }

    var permission: Permission? {
        switch self {
        case .microphone: return .microphone
        case .screen: return .screenRecording
        case .accessibility: return .accessibility
        case .welcome, .language, .model, .ready: return nil
        }
    }

    init(permission: Permission) {
        switch permission {
        case .microphone: self = .microphone
        case .screenRecording: self = .screen
        case .accessibility: self = .accessibility
        }
    }
}

/// Guided setup. It owns only where you are; everything it shows and changes
/// lives in `Settings`, `Permissions`, and `SpeechEngine`.
@MainActor
@Observable
final class SetupFlow {
    var stage = SetupStage.welcome {
        didSet {
            if !settings.completedOnboarding { settings.onboardingCheckpoint = stage }
        }
    }
    let settings: Settings
    let permissions: Permissions
    let speech: SpeechEngine
    @ObservationIgnored var onFinish: () -> Void = {}
    @ObservationIgnored var onRelaunch: () -> Void = {}

    init(settings: Settings, permissions: Permissions, speech: SpeechEngine) {
        self.settings = settings
        self.permissions = permissions
        self.speech = speech
    }

    var isReturning: Bool { settings.completedOnboarding }

    var speechReady: Bool {
        speech.state == .ready && speech.model == settings.speechModel
    }

    var canFinish: Bool {
        permissions.allGranted && speechReady
    }

    var firstIncompleteStage: SetupStage {
        if let missing = permissions.firstMissing { return SetupStage(permission: missing) }
        return speechReady ? .ready : .model
    }

    /// First run resumes where it left off; later visits open on whatever
    /// still needs attention.
    func resume() {
        permissions.refresh()
        if !settings.completedOnboarding {
            let checkpoint = settings.onboardingCheckpoint ?? .welcome
            stage = Swift.min(checkpoint, firstIncompleteStage)
        } else {
            stage = firstIncompleteStage
        }
    }

    func go(to stage: SetupStage) {
        self.stage = stage
    }

    func back() {
        if let previous = SetupStage(rawValue: stage.rawValue - 1) { stage = previous }
    }

    func permissionGranted(_ permission: Permission) {
        guard stage.permission == permission else { return }
        if isReturning {
            stage = firstIncompleteStage
        } else if let next = SetupStage(rawValue: stage.rawValue + 1) {
            stage = next
        }
    }

    func downloadSpeech() {
        Task { await speech.prepare(settings.speechModel, downloading: true) }
    }

    func finish() {
        guard canFinish else { return }
        settings.completedOnboarding = true
        settings.onboardingCheckpoint = nil
        onFinish()
    }
}
