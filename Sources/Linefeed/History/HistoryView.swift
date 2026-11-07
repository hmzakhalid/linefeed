import SwiftUI

struct HistoryView: View {
    let model: HistoryModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            HStack(spacing: 0) {
                HistorySidebar(model: model)
                    .frame(width: 306)

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(width: 1)

                Group {
                    if let session = model.selectedSession {
                        HistoryDetail(session: session, model: model)
                    } else {
                        HistoryEmptyState(hasSessions: !model.sessions.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let notice = model.notice {
                Text(notice)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Color.black.opacity(0.94), in: Capsule())
                    .overlay { Capsule().stroke(Theme.stroke) }
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .foregroundStyle(Theme.text)
                .animation(.easeOut(duration: 0.18), value: model.notice)
        .onAppear(perform: model.refresh)
    }
}

private struct HistoryEmptyState: View {
    let hasSessions: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(hasSessions ? "NO MATCH" : "NO HISTORY YET")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Theme.accent)
            Text(hasSessions ? "Choose another recording." : "Finish a recording and it will appear here.")
                .font(.system(size: 17, weight: .semibold))
            Text("Your history stays on this Mac.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
