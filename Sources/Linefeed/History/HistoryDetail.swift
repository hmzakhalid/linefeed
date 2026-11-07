import AppKit
import LinefeedCore
import SwiftUI

struct HistoryDetail: View {
    let session: SavedSession
    let model: HistoryModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.stroke).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    transcript
                    contextTimeline
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
                .frame(maxWidth: 850, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("RECORDING")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Theme.accent)
                Text(session.manifest.startedAt.formatted(date: .complete, time: .shortened))
                    .font(.system(size: 20, weight: .semibold))
                metadata
            }
            Spacer(minLength: 20)
            Button("Show in Finder") { model.reveal(session) }
                .buttonStyle(QuietButtonStyle())
            Button("Copy") { model.copy(session) }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        .padding(.leading, 30)
        .padding(.trailing, 22)
        .padding(.top, 38)
        .padding(.bottom, 17)
    }

    private var metadata: some View {
        HStack(spacing: 9) {
            if session.manifest.duration > 0 {
                Text(SessionTimecode.string(for: session.manifest.duration))
            }
            if !session.manifest.language.isEmpty { Text(session.manifest.language.lowercased()) }
            if !session.manifest.recordingMode.isEmpty { Text(session.manifest.recordingMode.lowercased()) }
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(Theme.secondary)
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionLabel("Transcript")
            Text(session.manifest.transcript.text.isEmpty ? "No words were captured." : session.manifest.transcript.text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(
                    session.manifest.transcript.text.isEmpty
                        ? Theme.secondary
                        : Theme.text.opacity(0.92)
                )
                .textSelection(.enabled)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Theme.surface.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke) }
        }
    }

    @ViewBuilder
    private var contextTimeline: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionLabel("Screenshots", trailing: "\(session.manifest.captures.count)")
            if session.manifest.captures.isEmpty {
                Text("No screenshots in this recording.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                    .padding(.vertical, 22)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(session.manifest.captures.enumerated()), id: \.element.id) { index, capture in
                        CaptureTimelineRow(
                            capture: capture,
                            imageURL: session.imageURL(for: capture),
                            startedAt: session.manifest.startedAt,
                            isLast: index == session.manifest.captures.count - 1
                        )
                    }
                }
            }
        }
    }

    private func sectionLabel(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let trailing { Text(trailing) }
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(1.1)
        .foregroundStyle(Theme.secondary)
    }
}

private struct CaptureTimelineRow: View {
    let capture: SessionCaptureRecord
    let imageURL: URL
    let startedAt: Date
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.18)).frame(width: 22, height: 22)
                    Circle().fill(Theme.accent).frame(width: 7, height: 7)
                }
                if !isLast {
                    Rectangle()
                        .fill(Theme.accent.opacity(0.38))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Screenshot \(capture.index)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Theme.accent)
                    Text(SessionTimecode.string(for: capture.offset))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    Spacer()
                    if let offset = capture.offset {
                        Text(startedAt.addingTimeInterval(offset).formatted(date: .omitted, time: .standard))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.secondary)
                    }
                }

                if capture.excerpt.isEmpty {
                    Text("No nearby words were heard.")
                        .foregroundStyle(Theme.secondary)
                } else {
                    Text("“\(capture.excerpt)”")
                        .foregroundStyle(Theme.text.opacity(0.86))
                }

                ScreenshotView(url: imageURL)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(16)
            .background(Theme.surface.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke) }
            .padding(.bottom, isLast ? 0 : 18)
        }
    }
}

private struct ScreenshotView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Label("Screenshot unavailable", systemImage: "photo.badge.exclamationmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)) }
        .onAppear { image = NSImage(contentsOf: url) }
        .onChange(of: url) { _, value in image = NSImage(contentsOf: value) }
    }
}
