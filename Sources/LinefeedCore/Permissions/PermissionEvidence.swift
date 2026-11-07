public enum PermissionEvidence: Equatable, Sendable {
    case unknown
    case denied
    case granted
}

public enum PermissionEvidenceResolver {
    /// A positive result from either supported macOS API wins over a stale
    /// negative result from the other API. If neither reports a grant, an
    /// explicit denial wins over an undetermined state.
    public static func resolve(_ evidence: [PermissionEvidence]) -> PermissionEvidence {
        if evidence.contains(.granted) { return .granted }
        if evidence.contains(.denied) { return .denied }
        return .unknown
    }
}
