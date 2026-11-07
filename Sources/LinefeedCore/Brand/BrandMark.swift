import CoreGraphics
import Foundation

/// The Linefeed mark: a pen-drawn circle around a return arrow — circle the
/// moment and it comes back as a line of text. Both shapes are filled
/// outlines in a 100×100 design space with y pointing down, the same space the
/// SVG files use, so every renderer only has to fill them.
public enum BrandMark {
    public static let designSize: CGFloat = 100
    public static let strokeWidth: CGFloat = 8.5

    public static var ring: CGPath {
        let samples = 72
        let start = -62.0 * Double.pi / 180
        let sweep = -388.0 * Double.pi / 180
        let center = CGPoint(x: 50, y: 50)

        func point(_ t: Double) -> CGPoint {
            let angle = start + sweep * t
            let radius = 32.5 + 4.5 * t
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        func width(_ t: Double) -> Double {
            let lift = max(0, (t - 0.72) / 0.28)
            let eased = lift * lift * (3 - 2 * lift)
            return Double(strokeWidth) * (1 - 0.68 * eased)
        }

        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for index in 0...samples {
            let t = Double(index) / Double(samples)
            let before = point(max(0, t - 0.001))
            let after = point(min(1, t + 0.001))
            let length = hypot(after.x - before.x, after.y - before.y)
            let normal = CGPoint(x: -(after.y - before.y) / length, y: (after.x - before.x) / length)
            let center = point(t)
            let half = width(t) / 2
            left.append(CGPoint(x: center.x + normal.x * half, y: center.y + normal.y * half))
            right.append(CGPoint(x: center.x - normal.x * half, y: center.y - normal.y * half))
        }

        let path = CGMutablePath()
        path.move(to: left[0])
        addSmoothCurve(to: path, through: left)
        addCap(to: path, from: left[samples], to: right[samples], around: point(1))
        addSmoothCurve(to: path, through: right.reversed())
        addCap(to: path, from: right[0], to: left[0], around: point(0))
        path.closeSubpath()
        return path
    }

    public static var arrow: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 61.5, y: 32.5))
        path.addLine(to: CGPoint(x: 61.5, y: 51.5))
        path.addArc(
            tangent1End: CGPoint(x: 61.5, y: 59.5),
            tangent2End: CGPoint(x: 53.5, y: 59.5),
            radius: 8
        )
        path.addLine(to: CGPoint(x: 37.5, y: 59.5))
        path.move(to: CGPoint(x: 46.5, y: 50.5))
        path.addLine(to: CGPoint(x: 37.5, y: 59.5))
        path.addLine(to: CGPoint(x: 46.5, y: 68.5))
        return path.copy(strokingWithWidth: strokeWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
    }

    /// Maps the design space onto `rect`. Pass `flipsVertically` for contexts
    /// whose origin is at the bottom left, such as AppKit and Core Graphics.
    public static func transform(into rect: CGRect, flipsVertically: Bool) -> CGAffineTransform {
        let scale = min(rect.width, rect.height) / designSize
        let origin = CGPoint(x: rect.midX - designSize * scale / 2, y: rect.midY - designSize * scale / 2)
        guard flipsVertically else {
            return CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
        }
        return CGAffineTransform(translationX: origin.x, y: origin.y + designSize * scale).scaledBy(x: scale, y: -scale)
    }

    private static func addSmoothCurve(to path: CGMutablePath, through points: [CGPoint]) {
        for index in 0..<(points.count - 1) {
            let previous = points[max(index - 1, 0)]
            let current = points[index]
            let next = points[index + 1]
            let following = points[min(index + 2, points.count - 1)]
            path.addCurve(
                to: next,
                control1: CGPoint(x: current.x + (next.x - previous.x) / 6, y: current.y + (next.y - previous.y) / 6),
                control2: CGPoint(x: next.x - (following.x - current.x) / 6, y: next.y - (following.y - current.y) / 6)
            )
        }
    }

    private static func addCap(to path: CGMutablePath, from start: CGPoint, to end: CGPoint, around center: CGPoint) {
        let radius = hypot(start.x - center.x, start.y - center.y)
        let from = atan2(start.y - center.y, start.x - center.x)
        let to = atan2(end.y - center.y, end.x - center.x)
        path.addArc(center: center, radius: radius, startAngle: from, endAngle: to, clockwise: false)
    }
}
