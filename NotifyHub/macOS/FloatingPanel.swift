#if os(macOS)
import AppKit
import SwiftUI

// Mini panel — borderless, translucent, rounded, no shadow
class MiniPanel: NSPanel {
    private enum DodgeState { case home, dodgingOut, dodged, dodgingIn }
    private var dodgeState: DodgeState = .home
    private var homeFrame: NSRect?
    private var dodgeMonitorGlobal: Any?
    private var dodgeMonitorLocal: Any?
    private var trackingArea: NSTrackingArea?

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
        installTrackingArea()
    }

    override func close() {
        savePosition(key: "MiniPanelFrame")
        removeCursorMonitor()
        super.close()
    }

    func setAlwaysOnTop(_ pinned: Bool) {
        level = pinned ? .floating : .normal
    }

    func savePosition(key: String = "MiniPanelFrame") {
        // If currently dodged, persist the home position rather than the peek strip
        let frameToSave = homeFrame ?? frame
        UserDefaults.standard.set(NSStringFromRect(frameToSave), forKey: key)
    }

    private func restorePosition(key: String) {
        if let saved = UserDefaults.standard.string(forKey: key) {
            let rect = NSRectFromString(saved)
            if rect != .zero { setFrame(rect, display: true); return }
        }
        center()
    }

    // MARK: - Hover-dodge

    private func installTrackingArea() {
        guard let view = contentView else { return }
        if let existing = trackingArea { view.removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard dodgeState == .home else { return }
        let shift = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        if shift { return }
        startDodge()
    }

    private func startDodge() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        homeFrame = frame
        dodgeState = .dodgingOut

        var dodged = frame
        let peek: CGFloat = 6
        dodged.origin.x = screen.visibleFrame.maxX - peek

        animateFrame(to: dodged) { [weak self] in
            guard let self = self else { return }
            self.dodgeState = .dodged
            self.installCursorMonitor()
        }
    }

    private func installCursorMonitor() {
        guard let home = homeFrame else { return }
        let homeRect = home.insetBy(dx: -8, dy: -8)
        let handler: (NSEvent) -> Void = { [weak self] _ in
            guard let self = self, self.dodgeState == .dodged else { return }
            if !homeRect.contains(NSEvent.mouseLocation) {
                self.endDodge()
            }
        }
        dodgeMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler)
        dodgeMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            handler(event); return event
        }
    }

    private func removeCursorMonitor() {
        if let g = dodgeMonitorGlobal { NSEvent.removeMonitor(g); dodgeMonitorGlobal = nil }
        if let l = dodgeMonitorLocal { NSEvent.removeMonitor(l); dodgeMonitorLocal = nil }
    }

    private func endDodge() {
        guard let home = homeFrame else { return }
        removeCursorMonitor()
        dodgeState = .dodgingIn
        animateFrame(to: home) { [weak self] in
            guard let self = self else { return }
            self.dodgeState = .home
            self.homeFrame = nil
        }
    }

    private func animateFrame(to target: NSRect, completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(target, display: true)
        }, completionHandler: completion)
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
