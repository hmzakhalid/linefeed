import AppKit
import LinefeedCore
import SwiftUI

/// Click, then press the shortcut you want: a modifier chord released
/// without a key, or a key with modifiers. Escape cancels.
struct ShortcutRecorder: View {
    let shortcut: Shortcut
    @Binding var isCapturing: Bool
    let validate: (Shortcut) -> String?
    let onChange: (Shortcut) -> Void

    @State private var held: ModifierSet = []
    @State private var problem: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button { isCapturing.toggle() } label: {
                Text(isCapturing ? (held.isEmpty ? "Press a shortcut…" : held.symbols) : shortcut.label)
                    .font(.system(size: 13, weight: .semibold, design: isCapturing && held.isEmpty ? .default : .monospaced))
                    .foregroundStyle(isCapturing ? Theme.accent : Theme.text)
                    .frame(minWidth: 132, minHeight: 34)
                    .padding(.horizontal, 12)
                    .background(Theme.text.opacity(isCapturing ? 0.09 : 0.06), in: RoundedRectangle(cornerRadius: 9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9).stroke(isCapturing ? Theme.accent.opacity(0.7) : Theme.stroke)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCapturing ? "Recording a new shortcut" : "Shortcut \(shortcut.label). Click to change.")
            if let problem {
                Text(problem).font(.system(size: 10)).foregroundStyle(Theme.accent).frame(maxWidth: 260, alignment: .trailing)
            }
        }
        .onChange(of: isCapturing) { _, capturing in capturing ? begin() : end() }
        .onDisappear(perform: end)
    }

    private func begin() {
        problem = nil
        held = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            MainActor.assumeIsolated { handle(event) }
            return nil
        }
    }

    private func end() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        held = []
        if isCapturing { isCapturing = false }
    }

    private func handle(_ event: NSEvent) {
        let modifiers = ModifierSet(event.modifierFlags)
        switch event.type {
        case .flagsChanged:
            if modifiers.isEmpty, !held.isEmpty {
                propose(Shortcut(modifiers: held))
            } else if modifiers.isSuperset(of: held) {
                held = modifiers
            }
        case .keyDown:
            if event.keyCode == ShortcutEngine.escapeKeyCode, modifiers.isEmpty {
                end()
            } else {
                propose(Shortcut(modifiers: modifiers, key: .named(code: event.keyCode, characters: event.charactersIgnoringModifiers)))
            }
        default:
            break
        }
    }

    private func propose(_ candidate: Shortcut) {
        held = []
        if let problem = validate(candidate) {
            self.problem = problem
            return
        }
        problem = nil
        onChange(candidate)
        end()
    }
}
