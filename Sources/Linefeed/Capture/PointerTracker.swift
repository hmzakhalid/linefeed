import AppKit

/// Samples the pointer while recording, in Quartz global coordinates.
@MainActor
final class PointerTracker {
    private var timer: Timer?
    private var lastLocation: CGPoint?
    var onMove: (CGPoint) -> Void = { _ in }

    func start() {
        guard timer == nil else { return }
        lastLocation = nil
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastLocation = nil
    }

    private func sample() {
        guard let location = CGEvent(source: nil)?.location, location != lastLocation else { return }
        lastLocation = location
        onMove(location)
    }
}

extension CGPoint {
    /// Quartz puts the origin at the top left of the main display; AppKit at
    /// its bottom left.
    var appKitPoint: CGPoint {
        CGPoint(x: x, y: CGDisplayBounds(CGMainDisplayID()).height - y)
    }
}
