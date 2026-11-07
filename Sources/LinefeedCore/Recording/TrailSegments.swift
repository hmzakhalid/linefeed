import CoreGraphics
import Foundation

public struct TrailSegment: Equatable {
    public let from: Int
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

public func trailSegments(
    points: [CGPoint],
    times: [TimeInterval],
    maximumGap: TimeInterval = 0.18,
    maximumDistance: CGFloat = 160
) -> [TrailSegment] {
    guard points.count == times.count,
          points.count >= 2,
          maximumGap >= 0,
          maximumDistance >= 0
    else {
        return []
    }

    let distanceLimitSquared = maximumDistance * maximumDistance
    var result: [TrailSegment] = []
    result.reserveCapacity(points.count - 1)

    for destination in points.indices.dropFirst() {
        let source = destination - 1
        let elapsed = times[destination] - times[source]
        guard (0...maximumGap).contains(elapsed) else { continue }

        let dx = points[destination].x - points[source].x
        let dy = points[destination].y - points[source].y
        guard dx * dx + dy * dy <= distanceLimitSquared else { continue }

        result.append(TrailSegment(from: source, to: destination))
    }

    return result
}
