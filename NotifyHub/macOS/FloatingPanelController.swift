import AppKit
import SwiftUI

class FloatingPanelController {
    private var panel: FloatingPanel?
    private var isCollapsed = false
    private let expandedSize = NSSize(width: 360, height: 500)
    private let collapsedSize = NSSize(width: 200, height: 48)

    func show(with contentView: some View) {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let panel = FloatingPanel(contentView: contentView)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func toggle() {
        guard let panel else { return }

        isCollapsed.toggle()
        let origin = panel.frame.origin
        let newSize = isCollapsed ? collapsedSize : expandedSize

        panel.setFrame(
            NSRect(origin: origin, size: newSize),
            display: true,
            animate: true
        )
    }

    func saveState() {
        panel?.savePosition()
    }
}
