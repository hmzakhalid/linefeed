import Foundation

enum IslandStyle {
    case listening
    case capture
    case finishing
    case success
    case empty
    case discarded
    case error

    var footer: String {
        switch self {
        case .listening: return "Esc to discard"
        case .capture: return "Screenshot added"
        case .finishing: return "Finishing"
        case .success: return "Ready"
        case .empty, .discarded: return "Nothing saved"
        case .error: return "Open Linefeed"
        }
    }

    /// How long a final state stays before the island leaves.
    var lingers: TimeInterval {
        switch self {
        case .success, .discarded: return 0.9
        case .error: return 1.25
        case .empty: return 1.35
        case .listening, .capture, .finishing: return 0
        }
    }
}

struct IslandFeedback: Equatable {
    let message: String
    let style: IslandStyle
}
