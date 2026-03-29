import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView

        restorePosition()
    }

    override func close() {
        savePosition()
        super.close()
    }

    func savePosition() {
        UserDefaults.standard.set(
            NSStringFromRect(frame),
            forKey: "FloatingPanelFrame"
        )
    }

    func restorePosition() {
        if let saved = UserDefaults.standard.string(forKey: "FloatingPanelFrame") {
            let rect = NSRectFromString(saved)
            if rect != .zero {
                setFrame(rect, display: true)
                return
            }
        }
        center()
    }
}
