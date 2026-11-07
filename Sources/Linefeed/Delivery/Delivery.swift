import AppKit
import ApplicationServices
import LinefeedCore

/// The app and field that were in front when a recording stopped.
struct DeliveryTarget {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let applicationName: String?
    let focusedElement: AXUIElement?

    var destination: TextDestination {
        .infer(bundleIdentifier: bundleIdentifier, applicationName: applicationName)
    }

    /// Whether the focused element takes typed text, which makes it safe to
    /// give the clipboard back afterwards.
    var hasTextFocus: Bool {
        guard let focusedElement else { return false }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &role)
        if let role = role as? String, ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role) {
            return true
        }
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(focusedElement, kAXSelectedTextAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    @MainActor
    static func current() -> DeliveryTarget? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return nil }
        var focused: CFTypeRef?
        var element: AXUIElement?
        if AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
            let candidate = unsafeDowncast(focused, to: AXUIElement.self)
            var owner: pid_t = 0
            if AXUIElementGetPid(candidate, &owner) == .success, owner == application.processIdentifier {
                element = candidate
            }
        }
        return DeliveryTarget(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            applicationName: application.localizedName,
            focusedElement: element
        )
    }
}

struct DeliveryResult: Equatable {
    enum Clipboard: Equatable {
        /// The person's own clipboard was put back after pasting.
        case restored
        /// The session waits on the clipboard for the person to paste.
        case holdsSession
        /// Another app wrote to the clipboard meanwhile, so Linefeed left it be.
        case leftAlone
        case failed
    }

    let pastedText: Bool
    let pastedScreenshots: Bool
    let clipboard: Clipboard
}

/// Places a finished session where the person was working: the text, then
/// the screenshots, each with its own paste. A text-only session gives the
/// person's clipboard back afterwards; screenshots stay on the clipboard so
/// they can be pasted again where an app ignored them.
@MainActor
enum Delivery {
    /// Apps read the clipboard some time after they receive ⌘V, and nothing
    /// reports when they have, so each paste gets this long before the
    /// clipboard changes again.
    private static let pasteSettleTime: Duration = .milliseconds(320)

    static func deliver(_ session: SavedSession, to target: DeliveryTarget?, pasting: Bool) async -> DeliveryResult {
        let pasteboard = NSPasteboard.general
        let text = session.manifest.transcript.text
        let screenshots = session.screenshotURLs
        guard !session.manifest.contextualClipboardText.isEmpty || !screenshots.isEmpty else {
            return DeliveryResult(pastedText: false, pastedScreenshots: false, clipboard: .leftAlone)
        }
        guard pasting, let target, CGPreflightPostEventAccess() else {
            return DeliveryResult(pastedText: false, pastedScreenshots: false, clipboard: copy(session, to: pasteboard))
        }

        let original = screenshots.isEmpty && target.hasTextFocus ? ClipboardSnapshot(of: pasteboard) : nil
        var pastedText = false
        var pastedScreenshots = false
        var expectedChange: Int?

        if !text.isEmpty, Clipboard.copyText(text, to: pasteboard) {
            expectedChange = pasteboard.changeCount
            pastedText = paste(into: target)
            try? await Task.sleep(for: pasteSettleTime)
        }
        if !screenshots.isEmpty, pastedText || text.isEmpty,
           expectedChange.map({ $0 == pasteboard.changeCount }) ?? true,
           Clipboard.copyImages(screenshots, to: pasteboard) {
            expectedChange = pasteboard.changeCount
            pastedScreenshots = paste(into: target)
            try? await Task.sleep(for: pasteSettleTime)
        }

        guard expectedChange == nil || expectedChange == pasteboard.changeCount else {
            return DeliveryResult(pastedText: pastedText, pastedScreenshots: pastedScreenshots, clipboard: .leftAlone)
        }
        if pastedText, let original {
            original.restore(to: pasteboard)
            return DeliveryResult(pastedText: true, pastedScreenshots: false, clipboard: .restored)
        }
        return DeliveryResult(pastedText: pastedText, pastedScreenshots: pastedScreenshots, clipboard: copy(session, to: pasteboard))
    }

    private static func copy(_ session: SavedSession, to pasteboard: NSPasteboard) -> DeliveryResult.Clipboard {
        Clipboard.copy(session, to: pasteboard) ? .holdsSession : .failed
    }

    /// Pastes only while the target is still in front; the person may switch
    /// apps between the text and the screenshots.
    private static func paste(into target: DeliveryTarget) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else { return false }
        if let element = target.focusedElement {
            AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(target.processIdentifier)
        up.postToPid(target.processIdentifier)
        return true
    }
}
