import AppKit
import Testing
@testable import Linefeed

@Suite("Clipboard")
@MainActor
struct ClipboardIntegrationTests {
    @Test("One paste carries text and every screenshot for browsers and rich editors")
    func textAndScreenshots() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = try makePNG(color: .systemRed)
        let second = try makePNG(color: .white)
        let urls = [folder.appendingPathComponent("first.png"), folder.appendingPathComponent("second.png")]
        try first.write(to: urls[0])
        try second.write(to: urls[1])

        let pasteboard = privatePasteboard()
        let text = "The clipboard keeps this exact transcript."
        #expect(Clipboard.copy(text: text, screenshots: urls, to: pasteboard))

        let items = try #require(pasteboard.pasteboardItems)
        #expect(items.count == 2)
        #expect(items[0].string(forType: .string) == text)
        #expect(items[0].data(forType: .png) == first)
        #expect(items[1].data(forType: .png) == second)
        #expect(items.allSatisfy { $0.string(forType: .fileURL) == nil })

        let rtfd = try #require(items[0].data(forType: .rtfd))
        let rich = try NSAttributedString(data: rtfd, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
        #expect(rich.string.contains(text))
        var attachments = 0
        rich.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rich.length)) { value, _, _ in
            if value is NSTextAttachment { attachments += 1 }
        }
        #expect(attachments == 2)

        let html = try #require(items[0].data(forType: .html).flatMap { String(data: $0, encoding: .utf8) })
        #expect(html.components(separatedBy: "data:image/png;base64,").count - 1 == 2)
    }

    @Test("Image-only pastes carry no file path, so terminals never paste one")
    func imagesOnly() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("shot.png")
        try makePNG(color: .systemBlue).write(to: url)
        let pasteboard = privatePasteboard()

        #expect(Clipboard.copyImages([url], to: pasteboard))
        #expect(pasteboard.pasteboardItems?.first?.string(forType: .fileURL) == nil)
        #expect(pasteboard.pasteboardItems?.first?.data(forType: .png) != nil)
    }

    @Test("Nothing to copy leaves the clipboard untouched")
    func emptyCopyLeavesClipboard() {
        let pasteboard = privatePasteboard()
        pasteboard.clearContents()
        pasteboard.setString("keep me", forType: .string)

        #expect(!Clipboard.copy(text: "", screenshots: [], to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "keep me")
    }

    @Test("A snapshot puts the person's clipboard back exactly")
    func snapshotRestores() throws {
        let pasteboard = privatePasteboard()
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString("original", forType: .string)
        item.setData(Data([1, 2, 3]), forType: NSPasteboard.PasteboardType("com.example.custom"))
        pasteboard.writeObjects([item])

        let snapshot = try #require(ClipboardSnapshot(of: pasteboard))
        #expect(Clipboard.copyText("dictated", to: pasteboard))
        snapshot.restore(to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "original")
        #expect(pasteboard.data(forType: NSPasteboard.PasteboardType("com.example.custom")) == Data([1, 2, 3]))
    }

    @Test("A clipboard too large to hold in memory is not snapshotted")
    func snapshotLimit() {
        let pasteboard = privatePasteboard()
        pasteboard.clearContents()
        pasteboard.setData(Data(count: 9 * 1_024 * 1_024), forType: .tiff)
        #expect(ClipboardSnapshot(of: pasteboard) == nil)
    }

    private func privatePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("linefeed.test.\(UUID().uuidString)"))
    }

    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("linefeed-clipboard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makePNG(color: NSColor) throws -> Data {
        let image = NSImage(size: NSSize(width: 24, height: 18))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 24, height: 18).fill()
        image.unlockFocus()
        let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}
