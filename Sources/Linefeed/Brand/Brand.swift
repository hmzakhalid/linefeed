import AppKit
import LinefeedCore
import SwiftUI

enum Theme {
    static let background = Color(BrandPalette.ink)
    static let surface = Color(BrandPalette.graphite)
    static let text = Color(BrandPalette.paper)
    static let secondary = Color(BrandPalette.ashLight)
    static let accent = Color(BrandPalette.red)
    static let stroke = Color(BrandPalette.paper).opacity(0.11)
    static let accentGradient = LinearGradient(
        colors: [accent.opacity(0.76), accent],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    init(_ color: BrandPalette.Color) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue)
    }
}

extension NSColor {
    convenience init(_ color: BrandPalette.Color) {
        self.init(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }

    static let brandInk = NSColor(BrandPalette.ink)
    static let brandPaper = NSColor(BrandPalette.paper)
    static let brandRed = NSColor(BrandPalette.red)
}

struct BrandMarkView: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            var transform = BrandMark.transform(into: rect, flipsVertically: false)
            if let ring = BrandMark.ring.copy(using: &transform) {
                context.fill(Path(ring), with: .color(Theme.accent))
            }
            if let arrow = BrandMark.arrow.copy(using: &transform) {
                context.fill(Path(arrow), with: .color(Theme.text))
            }
        }
        .accessibilityHidden(true)
    }
}

extension NSImage {
    static func menuBarMark(recording: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            var transform = BrandMark.transform(into: rect.insetBy(dx: 0.5, dy: 0.5), flipsVertically: true)
            context.setFillColor(NSColor.black.cgColor)
            if recording {
                let scale = rect.width / BrandMark.designSize
                context.fillEllipse(in: rect.insetBy(dx: 12 * scale, dy: 12 * scale))
                context.setBlendMode(.clear)
            } else if let ring = BrandMark.ring.copy(using: &transform) {
                context.addPath(ring)
                context.fillPath()
            }
            if let arrow = BrandMark.arrow.copy(using: &transform) {
                context.addPath(arrow)
                context.fillPath()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Linefeed"
        return image
    }
}

enum DotMatrix {
    private static let glyphs: [Character: [String]] = [
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    ]

    /// Dots for `text` with `pitch` between dot centers, top-left origin.
    static func dots(for text: String, pitch: CGFloat) -> [CGRect] {
        var column = 0
        var rects: [CGRect] = []
        let diameter = max(1, pitch * 0.58)
        for character in text.uppercased() {
            guard let rows = glyphs[character] else {
                column += 3
                continue
            }
            for (row, pattern) in rows.enumerated() {
                for (offset, value) in pattern.enumerated() where value == "1" {
                    rects.append(CGRect(
                        x: CGFloat(column + offset) * pitch,
                        y: CGFloat(row) * pitch,
                        width: diameter,
                        height: diameter
                    ))
                }
            }
            column += 6
        }
        return rects
    }

    static func width(of text: String, pitch: CGFloat) -> CGFloat {
        let columns = text.uppercased().reduce(0) { $0 + (glyphs[$1] == nil ? 3 : 6) }
        return CGFloat(max(0, columns - 1)) * pitch
    }
}

struct DotMatrixText: View {
    let text: String

    var body: some View {
        Canvas { context, size in
            let pitch = min(size.height / 7, size.width / max(1, DotMatrix.width(of: text, pitch: 1)))
            for dot in DotMatrix.dots(for: text, pitch: pitch) {
                context.fill(Path(ellipseIn: dot), with: .color(Theme.text))
            }
        }
        .accessibilityLabel(text.capitalized)
    }
}

@MainActor
final class BrandWindow: NSObject, NSWindowDelegate {
    private let title: String
    private let resizable: Bool
    private let makeContent: () -> AnyView
    private var window: NSWindow?
    var onClose: () -> Void = {}

    init<Content: View>(title: String, resizable: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.resizable = resizable
        makeContent = { AnyView(content().preferredColorScheme(.dark)) }
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show() {
        let window = window ?? makeWindow()
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Releasing the content lets SwiftUI views run their onDisappear.
        window?.contentViewController = nil
        window = nil
        onClose()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: makeContent()))
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { style.insert(.resizable) }
        window.styleMask = style
        window.isMovableByWindowBackground = !resizable
        window.isReleasedWhenClosed = false
        window.backgroundColor = .brandInk
        window.delegate = self
        window.center()
        self.window = window
        return window
    }
}
