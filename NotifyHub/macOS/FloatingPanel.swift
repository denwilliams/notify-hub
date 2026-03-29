#if os(macOS)
import AppKit
import SwiftUI

// Mini panel — borderless, translucent, rounded, no shadow
class MiniPanel: NSPanel {
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 220, height: 82)),
            styleMask: [.nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        alphaValue = 0.75

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        self.contentView = visualEffect
        restorePosition(key: "MiniPanelFrame")
    }

    override func close() {
        savePosition(key: "MiniPanelFrame")
        super.close()
    }

    func setAlwaysOnTop(_ pinned: Bool) {
        level = pinned ? .floating : .normal
    }

    func savePosition(key: String = "MiniPanelFrame") {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: key)
    }

    private func restorePosition(key: String) {
        if let saved = UserDefaults.standard.string(forKey: key) {
            let rect = NSRectFromString(saved)
            if rect != .zero { setFrame(rect, display: true); return }
        }
        center()
    }
}

// Full panel — closable, resizable, no visible titlebar
class FullPanel: NSPanel {
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 600, height: 500)),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
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

        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView

        restorePosition(key: "FullPanelFrame")
    }

    override func close() {
        savePosition(key: "FullPanelFrame")
        orderOut(nil)
    }

    func setAlwaysOnTop(_ pinned: Bool) {
        level = pinned ? .floating : .normal
    }

    func savePosition(key: String = "FullPanelFrame") {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: key)
    }

    private func restorePosition(key: String) {
        if let saved = UserDefaults.standard.string(forKey: key) {
            let rect = NSRectFromString(saved)
            if rect != .zero { setFrame(rect, display: true); return }
        }
        center()
    }
}
#endif
