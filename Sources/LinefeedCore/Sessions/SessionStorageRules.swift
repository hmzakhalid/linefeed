import Foundation

/// Session folders are named `<UTC timestamp>-<UUID>`, so they sort by time
/// and Linefeed only ever touches folders it created.
public enum SessionFolderName {
    public static func make(startedAt: Date, id: UUID = UUID()) -> String {
        "\(stamp(for: startedAt))-\(id.uuidString)"
    }

    public static func isValid(_ name: String) -> Bool {
        let stampLength = 20
        guard name.count == stampLength + 1 + 36 else { return false }
        let separator = name.index(name.startIndex, offsetBy: stampLength)
        guard name[separator] == "-", UUID(uuidString: String(name[name.index(after: separator)...])) != nil else { return false }
        let stamp = String(name[..<separator])
        let iso = stamp.prefix(11) + stamp.dropFirst(11).replacingOccurrences(of: "-", with: ":")
        guard let date = try? Date(String(iso), strategy: .iso8601) else { return false }
        return self.stamp(for: date) == stamp
    }

    /// ISO 8601 in UTC with dashes for colons, which file names can't hold.
    private static func stamp(for date: Date) -> String {
        date.formatted(.iso8601).replacingOccurrences(of: ":", with: "-")
    }
}

public struct StoredSession: Equatable, Sendable {
    /// A `SessionFolderName`, so names sort by when recording started.
    public let name: String
    public let bytes: Int64

    public init(name: String, bytes: Int64) {
        self.name = name
        self.bytes = bytes
    }
}

/// History keeps everything until it outgrows its budget, then lets go of
/// the oldest sessions first.
public struct SessionBudget: Equatable, Sendable {
    public let maxBytes: Int64

    public init(maxBytes: Int64) {
        self.maxBytes = max(0, maxBytes)
    }

    public func canStore(additionalBytes: Int64, usedBytes: Int64) -> Bool {
        guard additionalBytes >= 0, usedBytes >= 0 else { return false }
        let (remaining, overflow) = maxBytes.subtractingReportingOverflow(usedBytes)
        return !overflow && remaining >= 0 && additionalBytes <= remaining
    }

    /// Oldest first until the rest fit. `protected` sessions count toward the
    /// total but are never removed.
    public func sessionsToRemove(from sessions: [StoredSession], protecting protected: Set<String> = []) -> Set<String> {
        var used = sessions.reduce(Int64.zero) { total, session in
            let (sum, overflow) = total.addingReportingOverflow(max(0, session.bytes))
            return overflow ? .max : sum
        }
        var removals = Set<String>()
        let oldestFirst = sessions.filter { !protected.contains($0.name) }.sorted { $0.name < $1.name }
        for session in oldestFirst where used > maxBytes {
            removals.insert(session.name)
            used = max(0, used - max(0, session.bytes))
        }
        return removals
    }
}
