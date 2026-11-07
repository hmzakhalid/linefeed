public struct AudioActivityEvidence: Equatable {
    public let threshold: Float
    public let requiredConsecutiveSamples: Int

    public private(set) var detected = false
    private var consecutiveSamples = 0

    public init(
        threshold: Float = 0.12,
        requiredConsecutiveSamples: Int = 5
    ) {
        precondition(threshold >= 0)
        precondition(requiredConsecutiveSamples > 0)
        self.threshold = threshold
        self.requiredConsecutiveSamples = requiredConsecutiveSamples
    }

    public mutating func observe(level: Float) {
        guard !detected else { return }
        guard level >= threshold else {
            consecutiveSamples = 0
            return
        }
        consecutiveSamples += 1
        detected = consecutiveSamples >= requiredConsecutiveSamples
    }

    public mutating func reset() {
        detected = false
        consecutiveSamples = 0
    }
}

/// The loudness of one buffer, on the 0...1 scale `AudioActivityEvidence`
/// judges: root mean square, amplified so ordinary speech lands mid-scale.
public enum AudioLevel {
    public static func of(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(Float.zero) { $0 + $1 * $1 } / Float(samples.count)
        return min(1, meanSquare.squareRoot() * 12)
    }
}
