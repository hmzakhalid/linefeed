public enum RecordingPhase: Equatable, Sendable {
    case idle
    case recording(RecordingMode)
    /// The last session is being transcribed and delivered; `queued` starts
    /// as soon as it is done.
    case finishing(queued: RecordingMode?)
}

public enum RecordingCommand: Equatable, Sendable {
    case start(RecordingMode)
    case stop
    case promoteToHandsFree
    case discard
    /// Discard only if nothing was said or captured yet: the person was
    /// pressing a key combination, not dictating.
    case discardIfUntouched
    /// Start this as soon as the session that is finishing is done.
    case queue(RecordingMode)
    /// Forget a queued start.
    case dropQueued
    case ignore

    /// The single place a shortcut gesture meets the recording state. Every
    /// pairing is spelled out so a new gesture or phase cannot fall through.
    public static func resolve(_ gesture: ShortcutGesture, in phase: RecordingPhase) -> RecordingCommand {
        switch phase {
        case .finishing(let queued):
            switch gesture {
            case .holdBegan: return .queue(.quick)
            case .toggled(let mode): return queued == mode ? .dropQueued : .queue(mode)
            case .holdEnded, .holdInterrupted: return queued == .quick ? .dropQueued : .ignore
            case .discard: return .dropQueued
            }
        case .idle:
            switch gesture {
            case .holdBegan: return .start(.quick)
            case .toggled(let mode): return .start(mode)
            case .holdEnded, .holdInterrupted, .discard: return .ignore
            }
        case .recording(let mode):
            switch (gesture, mode) {
            case (.holdBegan, _): return .ignore
            case (.holdEnded, .quick): return .stop
            case (.holdEnded, .handsFree): return .ignore
            case (.holdInterrupted, .quick): return .discardIfUntouched
            case (.holdInterrupted, .handsFree): return .ignore
            case (.toggled(.quick), .quick): return .stop
            case (.toggled(.quick), .handsFree): return .ignore
            case (.toggled(.handsFree), .quick): return .promoteToHandsFree
            case (.toggled(.handsFree), .handsFree): return .stop
            case (.discard, _): return .discard
            }
        }
    }
}
