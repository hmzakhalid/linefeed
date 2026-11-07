import AppKit
import ApplicationServices
import AVFoundation
import LinefeedCore
import Observation

enum Permission: CaseIterable {
    case microphone
    case screenRecording
    case accessibility

    fileprivate var settingsPane: String {
        switch self {
        case .microphone: return "Privacy_Microphone"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .accessibility: return "Privacy_Accessibility"
        }
    }
}

@MainActor
@Observable
final class Permissions {
    private(set) var granted: Set<Permission> = []
    /// Requests macOS answers in System Settings rather than with a prompt.
    private(set) var handedToSystemSettings: Set<Permission> = []
    @ObservationIgnored var onGranted: (Permission) -> Void = { _ in }
    @ObservationIgnored private var timer: Timer?

    init() {
        granted = Self.currentlyGranted()
    }

    var allGranted: Bool {
        granted.count == Permission.allCases.count
    }

    var firstMissing: Permission? {
        Permission.allCases.first { !granted.contains($0) }
    }

    func refresh() {
        let current = Self.currentlyGranted()
        let newlyGranted = current.subtracting(granted)
        granted = current
        handedToSystemSettings.subtract(current)
        for permission in Permission.allCases where newlyGranted.contains(permission) {
            onGranted(permission)
        }
    }

    func startWatching() {
        refresh()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    func request(_ permission: Permission) {
        guard !granted.contains(permission) else { return }
        switch permission {
        case .microphone:
            if Self.microphoneEvidence() == .denied {
                openSystemSettings(for: .microphone)
            } else {
                AVAudioApplication.requestRecordPermission { [weak self] _ in
                    Task { @MainActor [weak self] in self?.refresh() }
                }
            }
        case .screenRecording:
            handedToSystemSettings.insert(.screenRecording)
            _ = CGRequestScreenCaptureAccess()
        case .accessibility:
            handedToSystemSettings.insert(.accessibility)
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
        refresh()
    }

    func openSystemSettings(for permission: Permission) {
        handedToSystemSettings.insert(permission)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(permission.settingsPane)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func currentlyGranted() -> Set<Permission> {
        var result: Set<Permission> = []
        if microphoneEvidence() == .granted { result.insert(.microphone) }
        if CGPreflightScreenCaptureAccess() { result.insert(.screenRecording) }
        if AXIsProcessTrusted() { result.insert(.accessibility) }
        return result
    }

    /// AVFoundation and AVFAudio can disagree after a change in System
    /// Settings; a grant from either is current.
    private static func microphoneEvidence() -> PermissionEvidence {
        let capture: PermissionEvidence = switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .unknown
        @unknown default: .unknown
        }
        let audio: PermissionEvidence = switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        case .undetermined: .unknown
        @unknown default: .unknown
        }
        return PermissionEvidenceResolver.resolve([capture, audio])
    }
}
