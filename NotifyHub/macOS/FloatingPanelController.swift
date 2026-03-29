#if os(macOS)
import AppKit
import SwiftUI

class FloatingPanelController {
    private var miniPanel: MiniPanel?
    private var fullPanel: FullPanel?
    private let store = NotificationStore()
    @State private var currentIndex = 0
    private var isPinned = true

    func show() {
        if miniPanel != nil || fullPanel != nil {
            miniPanel?.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = PanelRootView(
            store: store,
            onExpand: { [weak self] in self?.showFull() },
            onCollapse: { [weak self] in self?.showMini() },
            onTogglePin: { [weak self] pinned in
                self?.isPinned = pinned
                self?.miniPanel?.setAlwaysOnTop(pinned)
                self?.fullPanel?.setAlwaysOnTop(pinned)
            }
        )

        let mini = MiniPanel(contentView: rootView.miniContent)
        mini.makeKeyAndOrderFront(nil)
        self.miniPanel = mini

        // Pre-create full panel (hidden)
        let full = FullPanel(contentView: rootView.fullContent)
        self.fullPanel = full
    }

    private func showFull() {
        miniPanel?.savePosition()
        miniPanel?.orderOut(nil)
        fullPanel?.makeKeyAndOrderFront(nil)
    }

    private func showMini() {
        fullPanel?.savePosition()
        fullPanel?.orderOut(nil)
        miniPanel?.makeKeyAndOrderFront(nil)
    }

    func saveState() {
        miniPanel?.savePosition()
        fullPanel?.savePosition()
    }
}
#endif
