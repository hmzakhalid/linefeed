import Foundation

/// Everything Linefeed tells the person about a recording, in one place: what
/// the island says, the menu's status line, and whether a notice is needed.
struct RecordingReport {
    struct Notice {
        enum Action {
            case openSetup
            case openSettings
            case openHistory
            case openScreenRecordingSettings

            var title: String {
                switch self {
                case .openSetup: return "Open Setup"
                case .openSettings: return "Open Settings"
                case .openHistory: return "Open History"
                case .openScreenRecordingSettings: return "Open System Settings"
                }
            }
        }

        let title: String
        let detail: String
        let action: Action?
    }

    let island: IslandFeedback?
    let status: String
    let notice: Notice?

    static func delivered(_ result: DeliveryResult, hasText: Bool, screenshotCount: Int) -> RecordingReport {
        let hasScreenshots = screenshotCount > 0
        let pasted = result.pastedText || result.pastedScreenshots
        let subject = switch (hasText, hasScreenshots) {
        case (true, true): "Text + screenshots"
        case (true, false): "Text"
        case (false, _): "Screenshots"
        }
        if pasted {
            let status = result.clipboard == .holdsSession ? "\(subject) placed • also on your clipboard" : "\(subject) placed"
            return RecordingReport(island: IslandFeedback(message: "\(subject) placed", style: .success), status: status, notice: nil)
        }
        guard result.clipboard != .failed else {
            return RecordingReport(
                island: IslandFeedback(message: "Saved to History", style: .error),
                status: "Couldn't copy • saved to History",
                notice: Notice(
                    title: "Couldn't copy this session",
                    detail: "It's safe in History. Open it there and choose Copy.",
                    action: .openHistory
                )
            )
        }
        let status = hasText ? "\(subject) copied" : "No speech heard • screenshots copied"
        return RecordingReport(island: IslandFeedback(message: "\(subject) copied", style: .success), status: status, notice: nil)
    }

    static let nothingCaptured = RecordingReport(
        island: IslandFeedback(message: "Nothing found", style: .empty),
        status: "Nothing heard",
        notice: nil
    )

    static let discarded = RecordingReport(
        island: IslandFeedback(message: "Recording discarded", style: .discarded),
        status: "Recording discarded",
        notice: nil
    )

    static func transcriptionFailed(screenshotCount: Int, keptAudio: Bool) -> RecordingReport {
        let kept = [keptAudio ? "your audio" : nil, screenshotCount > 0 ? "screenshots" : nil].compactMap { $0 }
        return RecordingReport(
            island: IslandFeedback(message: "Couldn't make text", style: .error),
            status: "Couldn't make text",
            notice: Notice(
                title: "Couldn't turn that recording into text",
                detail: kept.isEmpty
                    ? "Try again, or choose another microphone in Settings."
                    : "History kept \(kept.joined(separator: " and ")), so nothing is lost.",
                action: kept.isEmpty ? .openSettings : .openHistory
            )
        )
    }

    /// Delivered, but History couldn't keep a copy.
    static func notSaved(_ result: DeliveryResult) -> RecordingReport {
        RecordingReport(
            island: IslandFeedback(message: result.pastedText ? "Text placed" : "Copied", style: .success),
            status: "Couldn't save to History",
            notice: Notice(
                title: "Couldn't save this recording to History",
                detail: "Your text was still \(result.pastedText ? "placed" : "copied"). Check available storage.",
                action: .openHistory
            )
        )
    }

    static let limitReached = RecordingReport(
        island: nil,
        status: "Finishing at the time limit",
        notice: Notice(
            title: "\(Int(RecordingController.lengthLimit / 60))-minute recording limit reached",
            detail: "The recording stopped safely and is being transcribed now.",
            action: nil
        )
    )

    static let microphoneChanged = RecordingReport(
        island: nil,
        status: "Microphone changed • finishing",
        notice: Notice(
            title: "Your microphone changed",
            detail: "Linefeed finished the recording with what it heard before the change.",
            action: nil
        )
    )

    /// A recording could not start, or could not be saved.
    static func problem(_ error: Error) -> RecordingReport {
        let notice: Notice = switch error as? LinefeedError {
        case .speechNotReady:
            Notice(title: "Speech isn't ready yet", detail: "Open Setup to finish getting speech ready.", action: .openSetup)
        case .microphoneUnavailable:
            Notice(title: "No microphone is available", detail: "Connect a microphone or choose one in Settings.", action: .openSettings)
        case .microphoneFailed(let name):
            Notice(title: "Linefeed couldn't use \(name)", detail: "Choose another microphone in Settings and try again.", action: .openSettings)
        case .historyFull, .screenRecordingOff, .screenshotFailed, nil:
            Notice(title: "Couldn't save this recording", detail: "Check available storage, then try again.", action: .openHistory)
        }
        return RecordingReport(island: IslandFeedback(message: notice.title, style: .error), status: notice.title, notice: notice)
    }

    /// A screenshot failed while recording carries on.
    static func screenshotProblem(_ error: Error) -> RecordingReport {
        switch error as? LinefeedError {
        case .screenRecordingOff:
            return RecordingReport(
                island: IslandFeedback(message: "Screen access is off", style: .error),
                status: "Screen Recording is off",
                notice: Notice(
                    title: "Screen Recording is off",
                    detail: "Turn on Linefeed in Privacy & Security → Screen Recording, then reopen it.",
                    action: .openScreenRecordingSettings
                )
            )
        case .historyFull:
            return RecordingReport(
                island: IslandFeedback(message: "No room for more", style: .error),
                status: "This recording is full",
                notice: Notice(
                    title: "This recording is as large as History allows",
                    detail: "Finish it to keep what you have; new screenshots won't fit.",
                    action: nil
                )
            )
        default:
            return RecordingReport(
                island: IslandFeedback(message: "Couldn't add screenshot", style: .error),
                status: "Couldn't add the screenshot",
                notice: nil
            )
        }
    }
}
