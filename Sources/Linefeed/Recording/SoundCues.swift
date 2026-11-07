import AppKit

@MainActor
final class SoundCues {
    enum Cue {
        case start
        case stop

        fileprivate var soundName: NSSound.Name {
            switch self {
            case .start: return "Purr"
            case .stop: return "Pop"
            }
        }
    }

    private var sound: NSSound?

    /// Returns how long the cue lasts.
    @discardableResult
    func play(_ cue: Cue) -> TimeInterval {
        sound?.stop()
        sound = NSSound(named: cue.soundName)
        sound?.volume = 0.35
        sound?.play()
        return sound?.duration ?? 0
    }
}
