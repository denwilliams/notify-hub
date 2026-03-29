import AppKit
import SwiftUI
import ServiceManagement

class MacAppDelegate: NSObject, NSApplicationDelegate {
    private let panelController = FloatingPanelController()
    private let store = NotificationStore()
    private var pollTimer: DispatchSourceTimer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupLoginItem()
        showPanel()
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController.saveState()
        pollTimer?.cancel()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showPanel()
        return true
    }

    private func setupLoginItem() {
        try? SMAppService.mainApp.register()
    }

    private func showPanel() {
        let view = ContentView()
        panelController.show(with: view)
    }

    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.store.refresh()
                DockBadge.update(count: self.store.unreadCount)
            }
        }
        timer.resume()
        pollTimer = timer

        // Initial fetch
        Task { @MainActor in
            await store.refresh()
            DockBadge.update(count: store.unreadCount)
        }
    }
}
