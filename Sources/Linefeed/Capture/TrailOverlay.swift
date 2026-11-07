import AppKit
import CoreGraphics
import Foundation
import LinefeedCore

struct TrailPoint {
    let point: CGPoint
    let time: TimeInterval
}
struct TrailConfirmation {
    let center: CGPoint
    let radius: CGFloat
    let startedAt: TimeInterval
}

@MainActor
final class TrailOverlayView: NSView {
    private let trailLifetime: TimeInterval = 0.9
    private let confirmationLifetime: TimeInterval = 1.1
    private var trail: [TrailPoint] = []
    private var confirmations: [TrailConfirmation] = []
    private var globalOrigin = CGPoint.zero
    var reduceMotion = false
    override var isOpaque: Bool { false }

    func setGlobalOrigin(_ origin: CGPoint) {
        globalOrigin = origin
    }

    func add(point: CGPoint, at time: TimeInterval) {
        trail.append(TrailPoint(point: point, time: time))
        prune(now: time)
        needsDisplay = true
    }

    func confirm(center: CGPoint, radius: CGFloat, at time: TimeInterval) {
        confirmations.append(TrailConfirmation(center: center, radius: radius, startedAt: time))
        needsDisplay = true
    }

    /// Returns `false` once nothing is left to fade, so idle frames cost nothing.
    func tick(now: TimeInterval) -> Bool {
        let hadContent = !trail.isEmpty || !confirmations.isEmpty
        prune(now: now)
        return hadContent
    }

    func reset() {
        trail.removeAll(keepingCapacity: true)
        confirmations.removeAll(keepingCapacity: true)
        needsDisplay = false
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(dirtyRect)
        let now = ProcessInfo.processInfo.systemUptime

        context.setLineCap(.round)
        let segments = trailSegments(
            points: trail.map(\.point),
            times: trail.map(\.time)
        )
        for segment in segments {
            let previous = trail[segment.from]
            let current = trail[segment.to]
            let age = max(0, now - current.time)
            let fade = max(0, 1 - age / trailLifetime)
            guard fade > 0 else { continue }
            let start = localPoint(previous.point)
            let end = localPoint(current.point)
            context.saveGState()
            context.setBlendMode(.screen)
            context.setShadow(
                offset: .zero,
                blur: 7,
                color: NSColor.brandPaper.withAlphaComponent(0.42 * fade).cgColor
            )
            context.move(to: start)
            context.addLine(to: end)
            context.setStrokeColor(NSColor.brandPaper.withAlphaComponent(0.18 * fade).cgColor)
            context.setLineWidth(8)
            context.strokePath()

            context.setShadow(
                offset: .zero,
                blur: 2.5,
                color: NSColor.brandPaper.withAlphaComponent(0.5 * fade).cgColor
            )
            context.move(to: start)
            context.addLine(to: end)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.86 * fade).cgColor)
            context.setLineWidth(2.4)
            context.strokePath()
            context.restoreGState()
        }

        if let head = trail.last {
            let age = max(0, now - head.time)
            let fade = max(0, 1 - age / trailLifetime)
            if fade > 0 {
                let center = localPoint(head.point)
                context.saveGState()
                context.setBlendMode(.screen)
                context.setShadow(
                    offset: .zero,
                    blur: 9,
                    color: NSColor.brandPaper.withAlphaComponent(0.58 * fade).cgColor
                )
                context.setFillColor(NSColor.brandPaper.withAlphaComponent(0.18 * fade).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20))
                context.setFillColor(NSColor.brandPaper.withAlphaComponent(0.92 * fade).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9))
                context.setFillColor(NSColor.white.withAlphaComponent(0.98 * fade).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - 1.8, y: center.y - 1.8, width: 3.6, height: 3.6))
                context.restoreGState()
            }
        }

        for confirmation in confirmations {
            let age = max(0, now - confirmation.startedAt)
            let progress = min(1, age / confirmationLifetime)
            let alpha = max(0, 0.82 * (1 - progress))
            guard alpha > 0 else { continue }
            let scale = reduceMotion ? 1 : 0.82 + 0.18 * progress
            let radius = confirmation.radius * scale
            let center = localPoint(confirmation.center)
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.saveGState()
            context.setBlendMode(.screen)
            context.setShadow(
                offset: .zero,
                blur: 11,
                color: NSColor.brandRed.withAlphaComponent(alpha * 0.62).cgColor
            )
            context.setFillColor(NSColor.brandRed.withAlphaComponent(alpha * 0.07).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(NSColor.white.withAlphaComponent(alpha * 0.92).cgColor)
            context.setLineWidth(3)
            context.strokeEllipse(in: rect)

            let inner = rect.insetBy(dx: 9, dy: 9)
            context.setStrokeColor(NSColor.brandRed.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: inner)
            context.restoreGState()
        }
    }

    private func localPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - globalOrigin.x, y: point.y - globalOrigin.y)
    }

    private func prune(now: TimeInterval) {
        trail.removeAll { now - $0.time > trailLifetime }
        confirmations.removeAll { now - $0.startedAt > confirmationLifetime }
    }
}

@MainActor
final class TrailOverlayController {
    private var overlays: [(window: NSPanel, view: TrailOverlayView)] = []
    private var timer: Timer?

    func start() {
        stop()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        for screen in NSScreen.screens {
            let view = TrailOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.reduceMotion = reduceMotion
            view.setGlobalOrigin(screen.frame.origin)
            view.wantsLayer = true
            view.layerContentsRedrawPolicy = .onSetNeedsDisplay
            view.layer?.backgroundColor = NSColor.clear.cgColor

            let window = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.sharingType = .none
            window.animationBehavior = .none
            window.isFloatingPanel = true
            window.hidesOnDeactivate = false
            window.contentView = view
            overlays.append((window, view))
            window.orderFrontRegardless()
            window.display()
        }

        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for overlay in overlays {
            overlay.view.reset()
            overlay.window.orderOut(nil)
        }
        overlays.removeAll(keepingCapacity: true)
    }

    func add(point: CGPoint, at time: TimeInterval) {
        for overlay in overlays {
            overlay.view.add(point: point, at: time)
        }
    }

    func confirm(center: CGPoint, radius: CGFloat, at time: TimeInterval) {
        for overlay in overlays {
            overlay.view.confirm(center: center, radius: radius, at: time)
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        for overlay in overlays where overlay.view.tick(now: now) {
            overlay.view.display()
        }
    }
}
