import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isEnabled ? Theme.background : Theme.secondary)
            .padding(.horizontal, 19)
            .frame(minWidth: 132, minHeight: 38)
            .background(isEnabled ? Theme.text : Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.text.opacity(isEnabled ? 0.10 : 0.05)) }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.52)
            .shadow(color: Color.black.opacity(isEnabled ? 0.24 : 0), radius: 8, y: 4)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.text.opacity(configuration.isPressed ? 0.55 : 0.82))
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(Theme.text.opacity(configuration.isPressed ? 0.035 : 0.055), in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).stroke(Theme.stroke) }
    }
}

struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(Theme.accent)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat) -> some View {
        background(Theme.surface.opacity(0.74), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: cornerRadius).stroke(Theme.stroke, lineWidth: 1) }
    }
}

struct ShortcutCard: View {
    let keys: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 11) {
            Text(keys)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 48, height: 38)
                .background(Theme.text.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 15)
    }
}
