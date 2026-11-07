import SwiftUI

struct HistorySidebar: View {
    @Bindable var model: HistoryModel

    var body: some View {
        VStack(spacing: 0) {
            header
            search

            if model.filteredSessions.isEmpty {
                VStack(spacing: 7) {
                    Text(model.sessions.isEmpty ? "NO HISTORY YET" : "NO MATCHES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                    Text(model.sessions.isEmpty ? "Your finished recordings will appear here." : "Try a different word.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(model.filteredSessions) { session in
                            Button {
                                model.selectedID = session.id
                            } label: {
                                HistoryRow(
                                    session: session,
                                    selected: model.selectedID == session.id
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open session from \(session.manifest.startedAt.formatted())")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 18)
                }
            }

            footer
        }
        .background(Color.black.opacity(0.22))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("LINEFEED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(String(format: "%02d", model.sessions.count))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
            }
            Text("History")
                .font(.system(size: 24, weight: .semibold))
            Text("Your words and screenshots, in order.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 48)
        .padding(.bottom, 16)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)
            TextField("Search your history", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(Theme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke) }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(Theme.accent).frame(width: 5, height: 5)
            Text("ONLY ON THIS MAC")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Theme.secondary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 38)
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }
}

private struct HistoryRow: View {
    let session: SavedSession
    let selected: Bool

    var body: some View {
        HStack(spacing: 11) {
            VStack(spacing: 0) {
                Circle()
                    .fill(selected ? Theme.accent : Theme.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(selected ? Theme.accent.opacity(0.5) : Theme.stroke)
                    .frame(width: 1)
            }
            .frame(width: 9, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(session.manifest.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 7) {
                    Text(session.manifest.startedAt.formatted(date: .abbreviated, time: .shortened))
                    if !session.manifest.captures.isEmpty {
                        Text("·")
                        Label("\(session.manifest.captures.count)", systemImage: "photo")
                    }
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.secondary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            selected ? Color.white.opacity(0.075) : Color.white.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.white.opacity(0.15) : Theme.stroke)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
