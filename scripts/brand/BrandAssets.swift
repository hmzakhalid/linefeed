import AppKit
import CoreGraphics
import Foundation

/// Renders every brand asset from `BrandMark` and `BrandPalette`, so the app
/// icon, website, and README never drift from the app. Run it through
/// `scripts/render-brand-assets.sh`.
@main
struct BrandAssets {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: BrandAssets <repository root>\n".utf8))
            exit(2)
        }
        let root = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("linefeed-brand-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        try writeIconSet(to: root.appendingPathComponent("Resources/AppIcon.icns"), workspace: workspace)
        try writePNG(icon(size: 512), to: root.appendingPathComponent("docs/assets/linefeed-icon.png"))
        try write(iconSVG(), to: root.appendingPathComponent("site/public/favicon.svg"))
        try write(markSVG(), to: root.appendingPathComponent("site/src/assets/mark.svg"))
        try write(tokensCSS(), to: root.appendingPathComponent("site/src/brand-tokens.css"))
        print("Brand assets written under \(root.path)")
    }

    // MARK: App icon

    private static func icon(size: Int) -> CGImage {
        let side = CGFloat(size)
        let context = bitmap(size: size)
        let scale = side / 1024
        let body = CGRect(x: 100, y: 100, width: 824, height: 824).applying(CGAffineTransform(scaleX: scale, y: scale))
        let bodyPath = CGPath(roundedRect: body, cornerWidth: 185 * scale, cornerHeight: 185 * scale, transform: nil)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 28 * scale, color: cgColor(.black, alpha: 0.32))
        context.addPath(bodyPath)
        context.setFillColor(cgColor(BrandPalette.ink))
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(bodyPath)
        context.clip()
        let background = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [cgColor(BrandPalette.inkSoft), cgColor(BrandPalette.ink)] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(background, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
        context.restoreGState()

        context.saveGState()
        context.addPath(CGPath(
            roundedRect: body.insetBy(dx: 1.5 * scale, dy: 1.5 * scale),
            cornerWidth: 183 * scale,
            cornerHeight: 183 * scale,
            transform: nil
        ))
        context.setStrokeColor(cgColor(BrandPalette.paper, alpha: 0.09))
        context.setLineWidth(3 * scale)
        context.strokePath()
        context.restoreGState()

        let markRect = CGRect(x: side * 0.21, y: side * 0.21, width: side * 0.58, height: side * 0.58)
        drawMark(in: context, rect: markRect, ring: cgColor(BrandPalette.red), arrow: cgColor(BrandPalette.paper))
        return context.makeImage()!
    }

    private static func drawMark(in context: CGContext, rect: CGRect, ring: CGColor, arrow: CGColor) {
        var transform = BrandMark.transform(into: rect, flipsVertically: true)
        for (path, color) in [(BrandMark.ring, ring), (BrandMark.arrow, arrow)] {
            guard let placed = path.copy(using: &transform) else { continue }
            context.addPath(placed)
            context.setFillColor(color)
            context.fillPath()
        }
    }

    private static func writeIconSet(to destination: URL, workspace: URL) throws {
        let iconset = workspace.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            try writePNG(icon(size: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
            try writePNG(icon(size: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = ["--convert", "icns", "--output", destination.path, iconset.path]
        try iconutil.run()
        iconutil.waitUntilExit()
        guard iconutil.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
    }

    // MARK: SVG

    private static func iconSVG() -> String {
        let scale = 64.0 / 1024
        let body = 824 * scale
        let inset = 100 * scale
        let radius = 185 * scale
        let markOrigin = 64 * 0.21
        let markScale = 64 * 0.58 / BrandMark.designSize
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="Linefeed">
          <rect x="\(format(inset))" y="\(format(inset))" width="\(format(body))" height="\(format(body))" rx="\(format(radius))" fill="\(BrandPalette.ink.hex)"/>
          <g transform="translate(\(format(markOrigin)) \(format(markOrigin))) scale(\(format(markScale)))">
            <path d="\(pathData(BrandMark.ring))" fill="\(BrandPalette.red.hex)"/>
            <path d="\(pathData(BrandMark.arrow))" fill="\(BrandPalette.paper.hex)"/>
          </g>
        </svg>

        """
    }

    private static func markSVG() -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="Linefeed">
          <path d="\(pathData(BrandMark.ring))" fill="\(BrandPalette.red.hex)"/>
          <path d="\(pathData(BrandMark.arrow))" fill="currentColor"/>
        </svg>

        """
    }

    private static func pathData(_ path: CGPath) -> String {
        var commands: [String] = []
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                commands.append("M\(format(points[0]))")
            case .addLineToPoint:
                commands.append("L\(format(points[0]))")
            case .addQuadCurveToPoint:
                commands.append("Q\(format(points[0])) \(format(points[1]))")
            case .addCurveToPoint:
                commands.append("C\(format(points[0])) \(format(points[1])) \(format(points[2]))")
            case .closeSubpath:
                commands.append("Z")
            @unknown default:
                break
            }
        }
        return commands.joined()
    }

    // MARK: CSS

    private static func tokensCSS() -> String {
        let lines = BrandPalette.tokens.map { "  --\($0.name): \($0.color.hex);" }
        return """
        /* Generated by scripts/render-brand-assets.sh from Sources/LinefeedCore/Brand/BrandPalette.swift. */
        :root {
        \(lines.joined(separator: "\n"))
        }

        """
    }

    // MARK: Helpers

    private static func bitmap(size: Int) -> CGContext {
        CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    private static func cgColor(_ color: BrandPalette.Color, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: alpha)
    }

    private static func cgColor(_ color: NSColor, alpha: CGFloat) -> CGColor {
        color.withAlphaComponent(alpha).cgColor
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    private static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func format(_ value: CGFloat) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.2f", rounded)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
    }

    private static func format(_ point: CGPoint) -> String {
        "\(format(point.x)) \(format(point.y))"
    }
}
