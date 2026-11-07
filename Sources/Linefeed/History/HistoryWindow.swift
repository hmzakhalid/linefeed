import AppKit

@MainActor
final class HistoryWindow {
    private let model: HistoryModel
    private let window: BrandWindow

    init(store: SessionStore) {
        let model = HistoryModel(store: store)
        self.model = model
        window = BrandWindow(title: "Linefeed History", resizable: true) {
            HistoryView(model: model)
        }
    }

    func show() {
        model.refresh()
        window.show()
    }

    func refresh() {
        guard window.isVisible else { return }
        model.refresh()
    }
}
