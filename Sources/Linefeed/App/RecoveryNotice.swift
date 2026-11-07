import AppKit
import Observation
import SwiftUI

@MainActor
final class RecoveryNotice: NSObject, NSWindowDelegate {
    @MainActor
    @Observable
    final class Content {
        var title = ""
        var detail = ""
        var actionTitle = "OK"
        @ObservationIgnored var action: () -> Void = {}
    }

    private let content = Content()
    private var panel: NSPanel?

    func show(_ notice: RecordingReport.Notice, perform: @escaping (RecordingReport.Notice.Action) -> Void) {
        content.title = notice.title
        content.detail = notice.detail
        content.actionTitle = notice.action?.title ?? "OK"
        content.action = { [weak self] in
            self?.panel?.close()
            if let action = notice.action { perform(action) }
        }
        // A notice must not take focus from the app the person is dictating into.
        (panel ?? makePanel()).orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }

    /// AppKit honors `.nonactivatingPanel` only when the panel is created with it.
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = NSHostingController(rootView: NoticeView(content: content))
        panel.title = "Linefeed"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .brandInk
        panel.level = .floating
        panel.delegate = self
        panel.center()
        self.panel = panel
        return panel
    }
}

private struct NoticeView: View {
    let content: RecoveryNotice.Content

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.14)).frame(width: 42, height: 42)
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title).font(.system(size: 14, weight: .semibold))
                Text(content.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Button(content.actionTitle, action: content.action)
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(18)
        .frame(width: 590)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }
}
