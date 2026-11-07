import AppKit
import CoreGraphics
import Foundation
import LinefeedCore
import ScreenCaptureKit

/// Runs off the main actor: capturing, marking, and encoding a full display is heavy.
enum ScreenshotCapture {
    static func capture(gesture: CircleGesture, to url: URL) async throws {
        guard CGPreflightScreenCaptureAccess() else {
            throw LinefeedError.screenRecordingOff
        }
        guard let displayRegion = displayBounds(containing: gesture.center) else {
            throw LinefeedError.screenshotFailed
        }

        let image: CGImage
        let region: CGRect
        if #available(macOS 15.2, *) {
            region = displayRegion
            do {
                image = try await SCScreenshotManager.captureImage(in: region)
            } catch {
                throw captureError(error)
            }
        } else {
            let content: SCShareableContent
            do {
                content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
            } catch {
                throw captureError(error)
            }
            guard let display = content.displays.first(where: { $0.frame.contains(gesture.center) }) else {
                throw LinefeedError.screenshotFailed
            }
            region = display.frame

            let ownApplication = content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            let filter = SCContentFilter(
                display: display,
                excludingApplications: ownApplication,
                exceptingWindows: []
            )
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = region.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
            configuration.width = Int(region.width * CGFloat(display.width) / display.frame.width)
            configuration.height = Int(region.height * CGFloat(display.height) / display.frame.height)
            configuration.showsCursor = false
            do {
                image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
                )
            } catch {
                throw captureError(error)
            }
        }

        let marked = try highlight(image, target: gesture.center, region: region, radius: gesture.radius)
        let representation = NSBitmapImageRep(cgImage: marked)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw LinefeedError.screenshotFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private static func displayBounds(containing point: CGPoint) -> CGRect? {
        var display = CGDirectDisplayID()
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(point, 1, &display, &count) == .success, count == 1 else { return nil }
        return CGDisplayBounds(display)
    }

    private static func captureError(_ error: Error) -> LinefeedError {
        let error = error as NSError
        if error.domain == SCStreamErrorDomain,
           error.code == SCStreamError.Code.userDeclined.rawValue {
            return .screenRecordingOff
        }
        return .screenshotFailed
    }

    private static func highlight(_ image: CGImage, target: CGPoint, region: CGRect, radius: CGFloat) throws -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw LinefeedError.screenshotFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let scaleX = CGFloat(width) / region.width
        let scaleY = CGFloat(height) / region.height
        let x = (target.x - region.minX) * scaleX
        let y = CGFloat(height) - (target.y - region.minY) * scaleY
        let markedRadius = max(24, radius * min(scaleX, scaleY))
        let colors = [
            NSColor.brandRed.withAlphaComponent(0.12).cgColor,
            NSColor.brandRed.withAlphaComponent(0.06).cgColor,
            NSColor.brandRed.withAlphaComponent(0).cgColor
        ] as CFArray
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: [0, 0.68, 1]
        ) {
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: x, y: y),
                startRadius: 0,
                endCenter: CGPoint(x: x, y: y),
                endRadius: markedRadius * 1.35,
                options: [.drawsAfterEndLocation]
            )
        }

        let marker = CGRect(x: x - markedRadius, y: y - markedRadius, width: markedRadius * 2, height: markedRadius * 2)
        context.setShadow(
            offset: .zero,
            blur: max(8, markedRadius * 0.09),
            color: NSColor.brandRed.withAlphaComponent(0.54).cgColor
        )
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        context.setLineWidth(max(3, markedRadius * 0.038))
        context.strokeEllipse(in: marker)
        context.setShadow(offset: .zero, blur: 0)
        context.setStrokeColor(NSColor.brandRed.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(max(1.5, markedRadius * 0.016))
        context.strokeEllipse(in: marker.insetBy(dx: 8, dy: 8))
        return context.makeImage() ?? image
    }
}
