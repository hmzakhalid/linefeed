import AppKit

enum RecordingIslandSilhouette {
    static let attachedBodyInset: CGFloat = 20

    static func path(in rect: NSRect, attachedToNotch: Bool) -> NSBezierPath {
        guard attachedToNotch else {
            return NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
        }

        let path = NSBezierPath()
        let bodyInset = attachedBodyInset
        let curveDepth: CGFloat = 28
        let bodyLeft = rect.minX + bodyInset
        let bodyRight = rect.maxX - bodyInset
        let bottomRadius: CGFloat = 32

        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.curve(
            to: NSPoint(x: bodyRight, y: rect.minY + curveDepth),
            controlPoint1: NSPoint(x: rect.maxX - 4, y: rect.minY),
            controlPoint2: NSPoint(x: bodyRight, y: rect.minY + 15)
        )
        path.line(to: NSPoint(x: bodyRight, y: rect.maxY - bottomRadius))
        path.curve(
            to: NSPoint(x: bodyRight - bottomRadius, y: rect.maxY),
            controlPoint1: NSPoint(x: bodyRight, y: rect.maxY - 10),
            controlPoint2: NSPoint(x: bodyRight - 10, y: rect.maxY)
        )
        path.line(to: NSPoint(x: bodyLeft + bottomRadius, y: rect.maxY))
        path.curve(
            to: NSPoint(x: bodyLeft, y: rect.maxY - bottomRadius),
            controlPoint1: NSPoint(x: bodyLeft + 10, y: rect.maxY),
            controlPoint2: NSPoint(x: bodyLeft, y: rect.maxY - 10)
        )
        path.line(to: NSPoint(x: bodyLeft, y: rect.minY + curveDepth))
        path.curve(
            to: NSPoint(x: rect.minX, y: rect.minY),
            controlPoint1: NSPoint(x: bodyLeft, y: rect.minY + 15),
            controlPoint2: NSPoint(x: rect.minX + 4, y: rect.minY)
        )
        path.close()
        return path
    }
}
