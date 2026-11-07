import AppKit
import Foundation
import ImageIO
import LinefeedCore
import QuartzCore

@MainActor
final class RecordingIslandView: NSView {
    var language = ""
    var recordingMode = ""
    var level: Float = 0
    var contextCount = 0
    var isFinishing = false
    var message: String?
    var messageIsError = false
    var feedbackStyle = IslandStyle.listening
    var thumbnails: [NSImage] = []
    var reduceMotion = false
    var hasNotch = false
    var contentTopPadding: CGFloat = 0
    var showDetails = false
    var showTimer = true
    var showCapturePreviews = true
    var startedAt = Date()

    override var isFlipped: Bool { true }

    /// The parts of the island the person chose to see.
    func apply(_ appearance: IslandAppearance, hasNotch: Bool) {
        self.hasNotch = hasNotch
        contentTopPadding = hasNotch ? appearance.clearance.points : 0
        showDetails = appearance.showsDetails
        showTimer = appearance.showsTimer
        showCapturePreviews = appearance.showsScreenshots
        needsDisplay = true
    }

    static func size(for appearance: IslandAppearance, hasNotch: Bool) -> NSSize {
        NSSize(
            width: appearance.width.points,
            height: RecordingIslandController.baseHeight + (hasNotch ? appearance.clearance.points : 0)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        let bodyInset = hasNotch ? RecordingIslandSilhouette.attachedBodyInset : 0

        let outerBody = hasNotch
            ? NSRect(x: 0, y: -1, width: bounds.width, height: bounds.height)
            : bounds.insetBy(dx: 1, dy: 1)
        let outerPath = RecordingIslandSilhouette.path(
            in: outerBody,
            attachedToNotch: hasNotch
        )
        (hasNotch ? NSColor.black : NSColor.brandInk.withAlphaComponent(0.985)).setFill()
        outerPath.fill()
        NSColor.white.withAlphaComponent(hasNotch ? 0.065 : 0.12).setStroke()
        outerPath.lineWidth = 1.15
        outerPath.stroke()

        NSColor.black.setFill()
        let notchWidth: CGFloat = hasNotch ? 142 : 104
        let notchHeight: CGFloat = hasNotch ? 26 : 18
        NSBezierPath(
            roundedRect: NSRect(
                x: bounds.midX - notchWidth / 2,
                y: hasNotch ? 0 : 7,
                width: notchWidth,
                height: notchHeight
            ),
            xRadius: notchHeight / 2,
            yRadius: notchHeight / 2
        ).fill()

        drawContentTray()

        drawSignalGlyph(bodyInset: bodyInset)

        let title = message ?? (isFinishing ? "Finishing…" : "Listening")
        let detail: String
        switch feedbackStyle {
        case .empty:
            detail = "Nothing heard or added"
        case .discarded:
            detail = "Nothing was saved"
        case .error:
            detail = "Open Linefeed for help"
        default:
            detail = "\(language) · \(recordingMode)"
        }
        let isListening = feedbackStyle == .listening
        let titleY = (showDetails ? 28 : 40) + contentTopPadding
        let visibleThumbnails = showCapturePreviews ? Array(thumbnails.suffix(3)) : []
        let thumbnailStartX = bounds.width - bodyInset - 70 - CGFloat(visibleThumbnails.count) * 34
        let titleX = bodyInset + (isListening ? 116 : 80)
        let titleRightEdge: CGFloat
        if !visibleThumbnails.isEmpty {
            titleRightEdge = thumbnailStartX - 10
        } else if showTimer {
            titleRightEdge = bounds.width - bodyInset - 72
        } else {
            titleRightEdge = bounds.width - bodyInset - 20
        }
        if isListening {
            NSColor.brandRed.setFill()
            NSBezierPath(
                ovalIn: NSRect(x: bodyInset + 68, y: titleY + 7, width: 6, height: 6)
            ).fill()
            drawDotMatrix("REC", at: NSPoint(x: bodyInset + 81, y: titleY + 5), pitch: 1.0, color: .white)
        }
        draw(
            title,
            in: NSRect(
                x: titleX,
                y: titleY,
                width: max(90, titleRightEdge - titleX),
                height: 20
            ),
            size: 12.5,
            weight: .semibold,
            color: .white,
            monospaced: true
        )
        if showDetails {
            let detailX = bodyInset + 76
            draw(
                detail,
                in: NSRect(
                    x: detailX,
                    y: 51 + contentTopPadding,
                    width: max(110, titleRightEdge - detailX),
                    height: 16
                ),
                size: 9.5,
                weight: .medium,
                color: NSColor(calibratedWhite: 0.64, alpha: 1),
                monospaced: true
            )
        }

        drawThumbnails(visibleThumbnails, startX: thumbnailStartX)

        if showTimer {
            let elapsed = max(0, Date().timeIntervalSince(startedAt))
            let timer = String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
            let timerLabel: String
            switch feedbackStyle {
            case .finishing: timerLabel = "•••"
            case .success: timerLabel = "DONE"
            case .empty: timerLabel = "EMPTY"
            case .discarded: timerLabel = "CLEAR"
            case .error: timerLabel = "CHECK"
            case .listening, .capture: timerLabel = timer
            }
            draw(
                timerLabel,
                in: NSRect(
                    x: bounds.width - bodyInset - 61,
                    y: 40 + contentTopPadding,
                    width: 42,
                    height: 16
                ),
                size: 11,
                weight: .medium,
                color: NSColor(calibratedWhite: 0.78, alpha: 1),
                monospaced: true,
                alignment: .right
            )
        }

        NSColor.brandRed.withAlphaComponent(0.88).setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: bodyInset + 80,
                y: bounds.height - 6,
                width: 92,
                height: 1.5
            ),
            xRadius: 0.75,
            yRadius: 0.75
        ).fill()

        draw(
            feedbackStyle.footer,
            in: NSRect(
                x: bounds.width - bodyInset - 112,
                y: bounds.height - 18,
                width: 92,
                height: 11
            ),
            size: 7.5,
            weight: .medium,
            color: NSColor(calibratedWhite: 0.48, alpha: 1),
            monospaced: true,
            alignment: .right
        )
    }

    private func drawSignalGlyph(bodyInset: CGFloat) {
        let center = NSPoint(x: bodyInset + 42, y: 50 + contentTopPadding)
        switch feedbackStyle {
        case .empty:
            drawEmptyGlyph(center: center)
        case .discarded:
            drawCrossGlyph(center: center, color: NSColor.brandPaper.withAlphaComponent(0.72))
        case .success:
            drawCheckGlyph(center: center)
        case .error:
            drawAlertGlyph(center: center)
        case .listening, .capture, .finishing:
            drawWaveform(bodyInset: bodyInset)
        }
    }

    private func drawWaveform(bodyInset: CGFloat) {
        let signalColor = messageIsError ? NSColor.brandRed : NSColor.brandPaper
        let phase = reduceMotion ? 0 : Int(ProcessInfo.processInfo.systemUptime * 16)
        let shape: [CGFloat] = [0.38, 0.68, 1, 0.74, 0.48, 0.84, 0.54]
        for index in shape.indices {
            let pulse = reduceMotion || isFinishing ? 0 : CGFloat((phase + index * 2) % 7) * 0.32
            let finishingHeight = isFinishing ? CGFloat((index % 3) + 1) * 3 : 0
            let height = 7 + shape[index] * CGFloat(level) * 28 + pulse + finishingHeight
            let rect = NSRect(
                x: bodyInset + 21 + CGFloat(index) * 6,
                y: 50 + contentTopPadding - height / 2,
                width: 3.3,
                height: height
            )
            signalColor.withAlphaComponent(index == 2 ? 1 : 0.78).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
        }
    }

    private func drawEmptyGlyph(center: NSPoint) {
        for index in -2...2 {
            let alpha = index == 0 ? 0.75 : 0.32
            NSColor.brandPaper.withAlphaComponent(alpha).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: center.x + CGFloat(index) * 7 - 1.7,
                    y: center.y - 1.7,
                    width: 3.4,
                    height: 3.4
                )
            ).fill()
        }
    }

    private func drawCheckGlyph(center: NSPoint) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - 10, y: center.y))
        path.line(to: NSPoint(x: center.x - 3, y: center.y + 7))
        path.line(to: NSPoint(x: center.x + 11, y: center.y - 8))
        NSColor.brandPaper.setStroke()
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
        NSColor.brandRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x + 13, y: center.y - 10, width: 4, height: 4)).fill()
    }

    private func drawCrossGlyph(center: NSPoint, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - 8, y: center.y - 8))
        path.line(to: NSPoint(x: center.x + 8, y: center.y + 8))
        path.move(to: NSPoint(x: center.x + 8, y: center.y - 8))
        path.line(to: NSPoint(x: center.x - 8, y: center.y + 8))
        color.setStroke()
        path.lineWidth = 2.4
        path.lineCapStyle = .round
        path.stroke()
    }

    private func drawAlertGlyph(center: NSPoint) {
        NSColor.brandRed.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: center.x - 1.8, y: center.y - 10, width: 3.6, height: 14),
            xRadius: 1.8,
            yRadius: 1.8
        ).fill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y + 8, width: 4, height: 4)).fill()
    }

    private func drawContentTray() {
        let bodyInset = hasNotch ? RecordingIslandSilhouette.attachedBodyInset : 0
        let trayY = (showDetails ? 24 : 30) + contentTopPadding
        let trayHeight: CGFloat = showDetails ? 58 : 52
        let tray = NSRect(
            x: bodyInset + 12,
            y: trayY,
            width: bounds.width - (bodyInset + 12) * 2,
            height: trayHeight
        )
        NSColor.white.withAlphaComponent(0.026).setFill()
        let path = NSBezierPath(roundedRect: tray, xRadius: 22, yRadius: 22)
        path.fill()
        NSColor.white.withAlphaComponent(0.055).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        let signalWell = NSRect(x: tray.minX, y: trayY, width: 54, height: trayHeight)
        NSColor.brandInk.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: signalWell, xRadius: 22, yRadius: 22).fill()

        guard showTimer else { return }
        let timerWell = NSRect(x: tray.maxX - 62, y: trayY, width: 62, height: trayHeight)
        NSColor.brandInk.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: timerWell, xRadius: 22, yRadius: 22).fill()
    }

    private func drawThumbnails(_ visible: [NSImage], startX: CGFloat) {
        guard !visible.isEmpty else { return }
        for (index, image) in visible.enumerated() {
            let rect = NSRect(
                x: startX + CGFloat(index) * 34,
                y: (showDetails ? 31 : 34) + contentTopPadding,
                width: 29,
                height: 29
            )
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).addClip()
            image.draw(
                in: rect,
                from: NSRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 0.92,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.withAlphaComponent(0.2).setStroke()
            let outline = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
            outline.lineWidth = 1
            outline.stroke()
        }
        if contextCount > 3 {
            let badge = "+\(contextCount - 3)"
            let badgeRect = NSRect(
                x: startX - 8,
                y: 25 + contentTopPadding,
                width: 23,
                height: 15
            )
            NSColor.brandRed.setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: 7.5, yRadius: 7.5).fill()
            draw(
                badge,
                in: badgeRect.offsetBy(dx: 0, dy: 1),
                size: 8.5,
                weight: .bold,
                color: .white,
                alignment: .center
            )
        }
    }

    private func draw(
        _ text: String,
        in rect: NSRect,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor,
        monospaced: Bool = false,
        alignment: NSTextAlignment = .left
    ) {
        let font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
    }

    private func drawDotMatrix(_ text: String, at origin: NSPoint, pitch: CGFloat, color: NSColor) {
        color.setFill()
        for dot in DotMatrix.dots(for: text, pitch: pitch) {
            NSBezierPath(ovalIn: dot.offsetBy(dx: origin.x, dy: origin.y)).fill()
        }
    }
}

@MainActor
final class RecordingIslandController {
    static let baseHeight: CGFloat = 94

    private let view = RecordingIslandView(frame: NSRect(x: 0, y: 0, width: 468, height: baseHeight))
    private var appearance: IslandAppearance
    private weak var activeScreen: NSScreen?
    private var panel: NSPanel?
    private var redrawTimer: Timer?
    private var captureTimer: Timer?
    private var hideTimer: Timer?

    init(appearance: IslandAppearance) {
        self.appearance = appearance
    }

    func apply(_ appearance: IslandAppearance) {
        self.appearance = appearance
        layout()
    }

    func show(language: String, mode: RecordingMode) {
        hide(animated: false)
        view.language = language
        view.recordingMode = mode.title
        view.level = 0
        view.contextCount = 0
        view.isFinishing = false
        view.message = nil
        view.messageIsError = false
        view.feedbackStyle = .listening
        view.thumbnails.removeAll(keepingCapacity: true)
        view.startedAt = Date()
        view.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel("Linefeed listening in \(language), \(mode.title)")

        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main else {
            return
        }
        activeScreen = screen
        layout()
        let panelFrame = frame(for: screen)
        let panel = NSPanel(contentRect: panelFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = !view.hasNotch
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = view
        self.panel = panel
        panel.alphaValue = view.reduceMotion ? 1 : 0
        if !view.reduceMotion {
            panel.setFrameOrigin(NSPoint(x: panelFrame.origin.x, y: panelFrame.origin.y + 12))
        }
        panel.orderFrontRegardless()
        if !view.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(panelFrame.origin)
            }
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        let timer = Timer(timeInterval: view.reduceMotion ? 0.25 : 1.0 / 24, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.view.needsDisplay = true }
        }
        redrawTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func update(level: Float) {
        view.level = max(level, view.level * 0.78)
        view.needsDisplay = true
    }

    func update(mode: RecordingMode) {
        view.recordingMode = mode.title
        view.needsDisplay = true
    }

    func confirmCapture(url: URL, count: Int, timecode: String) {
        view.contextCount = count
        if let thumbnail = Self.thumbnail(of: url) {
            view.thumbnails = Array((view.thumbnails + [thumbnail]).suffix(3))
        }
        flash(String(format: "Screenshot %02d · %@", count, timecode), isError: false)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    /// A short message while recording carries on; the island keeps listening.
    func flash(_ message: String, isError: Bool) {
        captureTimer?.invalidate()
        view.message = message
        view.messageIsError = isError
        view.feedbackStyle = isError ? .listening : .capture
        view.setAccessibilityLabel(message)
        view.needsDisplay = true
        let timer = Timer(timeInterval: 1.1, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.view.message = nil
                self.view.messageIsError = false
                self.view.feedbackStyle = .listening
                self.view.needsDisplay = true
            }
        }
        captureTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func showFinishing() {
        present(nil, style: .finishing)
        view.isFinishing = true
        view.level = 0.2
        view.setAccessibilityLabel("Linefeed transcribing")
    }

    func finish(with feedback: IslandFeedback) {
        present(feedback.message, style: feedback.style)
        view.level = feedback.style == .success ? 0.25 : 0
        if feedback.style != .error {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: feedback.style.lingers, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        hideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func hide(animated: Bool = true) {
        [redrawTimer, captureTimer, hideTimer].forEach { $0?.invalidate() }
        redrawTimer = nil
        captureTimer = nil
        hideTimer = nil
        activeScreen = nil
        guard let panel else { return }
        self.panel = nil
        guard animated, !view.reduceMotion else {
            panel.orderOut(nil)
            return
        }
        let destination = NSPoint(x: panel.frame.origin.x, y: panel.frame.origin.y + 8)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrameOrigin(destination)
        }, completionHandler: {
            Task { @MainActor in panel.orderOut(nil) }
        })
    }

    private func present(_ message: String?, style: IslandStyle) {
        captureTimer?.invalidate()
        captureTimer = nil
        view.message = message
        view.messageIsError = style == .error
        view.feedbackStyle = style
        view.isFinishing = false
        if let message { view.setAccessibilityLabel(message) }
        view.needsDisplay = true
    }

    private func layout() {
        let hasNotch = (activeScreen?.safeAreaInsets.top ?? 0) > 0
        view.apply(appearance, hasNotch: hasNotch)
        view.setFrameSize(RecordingIslandView.size(for: appearance, hasNotch: hasNotch))
        if let screen = activeScreen {
            panel?.setFrame(frame(for: screen), display: true)
        }
    }

    /// Small enough to redraw every frame without rescaling a full screenshot.
    private static func thumbnail(of url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 96,
              ] as CFDictionary)
        else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private func frame(for screen: NSScreen) -> NSRect {
        NSRect(
            x: screen.frame.midX - view.frame.width / 2,
            y: screen.frame.maxY - view.frame.height - (view.hasNotch ? 0 : 10),
            width: view.frame.width,
            height: view.frame.height
        )
    }
}
