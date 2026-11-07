import AppKit
import SwiftUI

struct IslandSettingsSection: View {
    @Bindable var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            preview
            SettingsGroup {
                SettingsRow(title: "Size", detail: "How much room the island takes") {
                    Picker("Size", selection: $settings.island.width) {
                        ForEach(IslandAppearance.Width.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 268)
                }
                if NSScreen.screens.contains(where: { $0.safeAreaInsets.top > 0 }) {
                    SettingsRow(title: "Camera spacing", detail: "Space between the camera and the island's content") {
                        Picker("Camera spacing", selection: $settings.island.clearance) {
                            ForEach(IslandAppearance.Clearance.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 268)
                    }
                }
                SettingsToggle(title: "Language and mode", detail: "Show what Linefeed is listening for", isOn: $settings.island.showsDetails)
                SettingsToggle(title: "Timer", detail: "Show how long you've been recording", isOn: $settings.island.showsTimer)
                SettingsToggle(title: "Screenshots", detail: "Show a thumbnail as each screenshot lands", isOn: $settings.island.showsScreenshots)
            }
            HStack {
                Spacer()
                Button("Restore Defaults") { settings.island = IslandAppearance() }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PREVIEW")
                Spacer()
                Text("LISTENING")
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 14)
            .frame(height: 30)

            Rectangle().fill(Theme.stroke).frame(height: 1)

            let size = RecordingIslandView.size(for: settings.island, hasNotch: true)
            IslandPreview(appearance: settings.island)
                .frame(width: size.width, height: size.height)
                .scaleEffect(0.8)
                .frame(width: size.width * 0.8, height: size.height * 0.8)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface.opacity(0.52), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke) }
    }
}

private struct IslandPreview: NSViewRepresentable {
    let appearance: IslandAppearance

    func makeNSView(context: Context) -> RecordingIslandView {
        let view = RecordingIslandView()
        view.language = "English"
        view.recordingMode = "Quick note"
        view.level = 0.72
        view.reduceMotion = true
        view.startedAt = Date().addingTimeInterval(-17)
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: RecordingIslandView, context: Context) {
        view.apply(appearance, hasNotch: true)
    }
}
