import AppKit

@MainActor
enum Clipboard {
    private struct Screenshot {
        let data: Data
        let image: NSImage
        let url: URL
    }

    /// Text and screenshots together, so one paste carries both wherever the
    /// destination supports it. Plain-text fields receive the text.
    @discardableResult
    static func copy(text: String, screenshots: [URL], to pasteboard: NSPasteboard = .general) -> Bool {
        let screenshots = load(screenshots)
        guard !text.isEmpty || !screenshots.isEmpty else { return false }
        pasteboard.clearContents()
        guard !text.isEmpty else {
            return write(screenshots.map { imageItem($0, includingFileURL: true) }, to: pasteboard)
        }

        let item = NSPasteboardItem()
        guard item.setString(text, forType: .string) else { return false }
        // Browser editors read plain text and PNG/TIFF independently, so the
        // first screenshot rides on the text item: a single paste exposes both.
        if let first = screenshots.first {
            item.setData(first.data, forType: .png)
            if let tiff = first.image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        }
        let rich = NSMutableAttributedString(string: text)
        for screenshot in screenshots {
            rich.append(NSAttributedString(string: "\n\n"))
            let attachment = NSTextAttachment()
            attachment.image = screenshot.image
            rich.append(NSAttributedString(attachment: attachment))
        }
        let range = NSRange(location: 0, length: rich.length)
        if let rtfd = try? rich.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
            item.setData(rtfd, forType: .rtfd)
        }
        // AppKit editors prefer RTF over RTFD, and RTF cannot carry images, so
        // RTF is offered only when there are none.
        if screenshots.isEmpty,
           let rtf = try? rich.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            item.setData(rtf, forType: .rtf)
        }
        item.setData(html(text: text, images: screenshots.map(\.data)), forType: .html)

        let remaining = screenshots.dropFirst().map { imageItem($0, includingFileURL: false) }
        if write([item] + remaining, to: pasteboard) { return true }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    /// A saved session as one paste: its text, a timeline of what each
    /// screenshot shows, and the screenshots in order.
    @discardableResult
    static func copy(_ session: SavedSession, to pasteboard: NSPasteboard = .general) -> Bool {
        copy(text: session.manifest.contextualClipboardText, screenshots: session.screenshotURLs, to: pasteboard)
    }

    static func copyText(_ text: String, to pasteboard: NSPasteboard = .general) -> Bool {
        guard !text.isEmpty else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    /// Image data only: without a file URL, a terminal can't paste a path.
    static func copyImages(_ urls: [URL], to pasteboard: NSPasteboard = .general) -> Bool {
        let screenshots = load(urls)
        guard !screenshots.isEmpty else { return false }
        pasteboard.clearContents()
        return write(screenshots.map { imageItem($0, includingFileURL: false) }, to: pasteboard)
    }

    /// Chat composers attach separate image items last-first, so the items go
    /// in reverse to arrive in the order they were captured.
    private static func write(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) -> Bool {
        guard let first = items.first else { return false }
        let ordered = first.types.contains(.string) ? [first] + items.dropFirst().reversed() : items.reversed()
        return pasteboard.writeObjects(ordered)
    }

    private static func load(_ urls: [URL]) -> [Screenshot] {
        urls.compactMap { url in
            guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return nil }
            return Screenshot(data: data, image: image, url: url)
        }
    }

    private static func imageItem(_ screenshot: Screenshot, includingFileURL: Bool) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setData(screenshot.data, forType: .png)
        if let tiff = screenshot.image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        // Chromium hides its PNG flavor whenever a file URL is present, so a
        // file URL only travels with screenshots that have no text alongside.
        if includingFileURL { item.setString(screenshot.url.absoluteString, forType: .fileURL) }
        return item
    }

    private static func html(text: String, images: [Data]) -> Data {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "\n", with: "<br>")
        let figures = images.map { #"<div><img src="data:image/png;base64,\#($0.base64EncodedString())" alt="Screenshot"></div>"# }
        return Data("""
        <!doctype html><html><head><meta charset="utf-8"></head><body>
        <div>\(escaped)</div>\(figures.joined())
        </body></html>
        """.utf8)
    }
}

@MainActor
struct ClipboardSnapshot {
    /// Restoring a huge clipboard on every dictation would cost real memory;
    /// beyond this the session simply stays on the clipboard instead.
    private static let byteLimit = 8 * 1_024 * 1_024

    /// Password managers mark what they copy so it is never kept, and clear
    /// it on a timer; restoring it would undo that.
    private static let unrestorable: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
    ]

    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    init?(of pasteboard: NSPasteboard) {
        guard Self.unrestorable.isDisjoint(with: pasteboard.types ?? []) else { return nil }
        var total = 0
        var items: [[(NSPasteboard.PasteboardType, Data)]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var representations: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { continue }
                total += data.count
                guard total <= Self.byteLimit else { return nil }
                representations.append((type, data))
            }
            if !representations.isEmpty { items.append(representations) }
        }
        self.items = items
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}
