import Foundation

struct IslandAppearance: Equatable, Codable {
    enum Width: String, CaseIterable, Codable, Identifiable {
        case compact
        case standard
        case roomy

        var id: String { rawValue }

        var title: String {
            switch self {
            case .compact: return "Compact"
            case .standard: return "Standard"
            case .roomy: return "Roomy"
            }
        }

        var points: CGFloat {
            switch self {
            case .compact: return 500
            case .standard: return 620
            case .roomy: return 740
            }
        }
    }

    /// Space between the camera housing and the island's content.
    enum Clearance: String, CaseIterable, Codable, Identifiable {
        case close
        case comfortable
        case extra

        var id: String { rawValue }

        var title: String {
            switch self {
            case .close: return "Close"
            case .comfortable: return "Comfortable"
            case .extra: return "Extra"
            }
        }

        var points: CGFloat {
            switch self {
            case .close: return 20
            case .comfortable: return 28
            case .extra: return 36
            }
        }
    }

    var width = Width.standard
    var clearance = Clearance.comfortable
    var showsDetails = false
    var showsTimer = true
    var showsScreenshots = true
}
