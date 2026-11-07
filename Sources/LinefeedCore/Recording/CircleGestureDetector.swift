import CoreGraphics
import Foundation

public struct CircleGesture: Equatable, Sendable {
    public let center: CGPoint
    public let radius: CGFloat

    public init(center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
    }
}

/// Recognizes a deliberate loop in a stream of pointer locations. After a
/// match it stays latched until the pointer leaves the captured area, so one
/// long loop produces one capture.
public struct CircleGestureDetector {
    private struct TimedPoint {
        let location: CGPoint
        let timestamp: TimeInterval
    }

    private enum Threshold {
        static let minimumSamples = 18
        static let historyDuration: TimeInterval = 6
        static let strokePause: TimeInterval = 0.45
        static let captureCooldown: TimeInterval = 0.65
        static let minimumDiameter: CGFloat = 28
        static let minimumRadius: CGFloat = 18
    }

    private var history: [TimedPoint] = []
    private var ignoreUntil: TimeInterval = -.infinity
    private var latchedCapture: CircleGesture?

    public init() {}

    public mutating func reset() {
        history.removeAll(keepingCapacity: true)
        ignoreUntil = -.infinity
        latchedCapture = nil
    }

    public mutating func add(point: CGPoint, at time: TimeInterval) -> CircleGesture? {
        guard point.x.isFinite, point.y.isFinite, time.isFinite else { return nil }

        if let capture = latchedCapture {
            let releaseRadius = capture.radius * 1.5
            guard squaredDistance(from: point, to: capture.center) > releaseRadius * releaseRadius else {
                return nil
            }
            latchedCapture = nil
            history.removeAll(keepingCapacity: true)
        }

        guard time >= ignoreUntil else { return nil }

        if let last = history.last,
           time < last.timestamp || time - last.timestamp > Threshold.strokePause {
            history.removeAll(keepingCapacity: true)
        }

        history.append(TimedPoint(location: point, timestamp: time))
        discardHistory(olderThan: time - Threshold.historyDuration)

        guard history.count >= Threshold.minimumSamples,
              let capture = bestClosedLoop()
        else {
            return nil
        }

        history.removeAll(keepingCapacity: true)
        ignoreUntil = time + Threshold.captureCooldown
        latchedCapture = capture
        return capture
    }

    private mutating func discardHistory(olderThan cutoff: TimeInterval) {
        guard let firstCurrent = history.firstIndex(where: { $0.timestamp >= cutoff }) else {
            history.removeAll(keepingCapacity: true)
            return
        }
        if firstCurrent > history.startIndex {
            history.removeFirst(firstCurrent)
        }
    }

    private func bestClosedLoop() -> CircleGesture? {
        guard let endpoint = history.last?.location else { return nil }
        let latestPossibleStart = history.count - Threshold.minimumSamples

        for startIndex in stride(from: latestPossibleStart, through: 0, by: -1) {
            let candidateStart = history[startIndex].location
            guard squaredDistance(from: candidateStart, to: endpoint) < 160 * 160 else {
                continue
            }
            if let capture = score(Array(history[startIndex...])) {
                return capture
            }
        }
        return nil
    }

    private func score(_ candidate: [TimedPoint]) -> CircleGesture? {
        let points = candidate.map(\.location)
        guard let start = points.first, let end = points.last else { return nil }

        let bounds = points.reduce(
            into: (minX: CGFloat.infinity, maxX: -CGFloat.infinity,
                   minY: CGFloat.infinity, maxY: -CGFloat.infinity)
        ) { partial, point in
            partial.minX = min(partial.minX, point.x)
            partial.maxX = max(partial.maxX, point.x)
            partial.minY = min(partial.minY, point.y)
            partial.maxY = max(partial.maxY, point.y)
        }
        let width = bounds.maxX - bounds.minX
        let height = bounds.maxY - bounds.minY
        guard width >= Threshold.minimumDiameter, height >= Threshold.minimumDiameter else {
            return nil
        }

        let aspect = width / height
        guard (0.44...2.25).contains(aspect) else { return nil }

        let pointCount = CGFloat(points.count)
        let center = CGPoint(
            x: (bounds.minX + bounds.maxX) / 2,
            y: (bounds.minY + bounds.maxY) / 2
        )
        let radii = points.map { sqrt(squaredDistance(from: $0, to: center)) }
        let radius = radii.reduce(0, +) / pointCount
        guard radius >= Threshold.minimumRadius else { return nil }

        let radialError = radii.reduce(CGFloat.zero) { error, value in
            let delta = value - radius
            return error + delta * delta
        }
        let normalizedDeviation = sqrt(radialError / pointCount) / radius
        guard normalizedDeviation < 0.43 else { return nil }

        let closureLimit = max(22, radius * 0.7)
        guard squaredDistance(from: start, to: end) < closureLimit * closureLimit else {
            return nil
        }

        var signedRotation: CGFloat = 0
        var absoluteRotation: CGFloat = 0
        var traveled: CGFloat = 0

        for index in points.indices.dropFirst() {
            let previous = points[index - 1]
            let current = points[index]
            let previousAngle = atan2(previous.y - center.y, previous.x - center.x)
            let currentAngle = atan2(current.y - center.y, current.x - center.x)
            let turn = wrappedAngle(currentAngle - previousAngle)
            signedRotation += turn
            absoluteRotation += abs(turn)
            traveled += sqrt(squaredDistance(from: previous, to: current))
        }

        guard abs(signedRotation) > 4.45,
              absoluteRotation < 10.5
        else {
            return nil
        }

        let idealCircumference = 2 * CGFloat.pi * radius
        guard (0.68...1.95).contains(traveled / idealCircumference) else { return nil }

        return CircleGesture(center: center, radius: radius)
    }

    private func wrappedAngle(_ angle: CGFloat) -> CGFloat {
        var result = angle
        if result > .pi { result -= 2 * .pi }
        if result < -.pi { result += 2 * .pi }
        return result
    }

    private func squaredDistance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return dx * dx + dy * dy
    }
}
