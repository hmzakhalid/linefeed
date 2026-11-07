import SwiftUI

struct StageProgress: View {
    let current: SetupStage

    var body: some View {
        HStack(spacing: 5) {
            ForEach(SetupStage.allCases.filter { $0 != .welcome }) { stage in
                Capsule()
                    .fill(
                        stage.rawValue <= current.rawValue
                            ? Theme.accentGradient
                            : LinearGradient(
                                colors: [Theme.text.opacity(0.12)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(width: stage == current ? 20 : 6, height: 5)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup step \(current.rawValue) of \(SetupStage.allCases.count - 1)")
    }
}

struct WelcomeFact: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.secondary)
    }
}

struct WelcomeFlow: View {
    let quickShortcut: String

    private var steps: [(symbol: String, title: String)] {
        [(quickShortcut, "Speak"), ("◯", "Circle"), ("↵", "Done")]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                let step = steps[index]
                HStack(spacing: 8) {
                    Text(step.symbol)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(index == 1 ? Theme.accent : Theme.text)
                    Text(step.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.text.opacity(0.86))
                }
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(width: 38, height: 1)
                        .padding(.horizontal, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(width: 365, height: 52, alignment: .leading)
        .background(Theme.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speak, circle something for context, and it arrives as text")
    }
}

struct WelcomeIslandPreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.black.opacity(0.28))
                .frame(width: 330, height: 245)
                .overlay {
                    RoundedRectangle(cornerRadius: 32).stroke(Theme.text.opacity(0.07))
                }
            VStack(spacing: 18) {
                Text("WHILE YOU SPEAK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Theme.secondary.opacity(0.58))
                LiveIslandPreview()
                    .frame(width: 302, height: 86)
                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow")
                        .foregroundStyle(Theme.text)
                    Capsule().fill(Theme.accentGradient).frame(width: 62, height: 3)
                    Circle().stroke(Theme.text.opacity(0.72), lineWidth: 1.5).frame(width: 22, height: 22)
                }
            }
        }
    }
}

struct LiveIslandPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.4 : 1.0 / 18)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 13) {
                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<7, id: \.self) { index in
                        let value = reduceMotion ? 0.5 : (sin(phase * 5 + Double(index) * 0.85) + 1) / 2
                        Capsule()
                            .fill(Theme.text)
                            .frame(width: 3, height: 8 + value * 22)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        DotMatrixText(text: "REC").frame(width: 24, height: 7)
                    }
                    Text("English · Quick note")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "photo.fill")
                    Text("2")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text)
                Text("00:12")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 76)
            .background(Color.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 25))
            .overlay(alignment: .top) {
                Capsule().fill(Color.black).frame(width: 86, height: 17).offset(y: 5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 25).stroke(Theme.text.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.42), radius: 22, y: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording island preview")
    }
}

struct ReadinessPill: View {
    let icon: String
    let title: String
    let ready: Bool

    var body: some View {
        Label(title, systemImage: ready ? "checkmark.circle.fill" : icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ready ? Theme.text : Theme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Theme.text.opacity(0.045), in: Capsule())
            .overlay { Capsule().stroke(Theme.stroke) }
    }
}

struct AmbientField: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.text.opacity(0.018), .clear, Color.black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Theme.text.opacity(0.075), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 470
            )
        }
        .allowsHitTesting(false)
    }
}
