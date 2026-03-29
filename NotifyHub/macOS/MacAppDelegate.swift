#if os(macOS)
import AppKit
import SwiftUI
import ServiceManagement

class MacAppDelegate: NSObject, NSApplicationDelegate {
    private let panelController = FloatingPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupLoginItem()
        panelController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController.saveState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panelController.show()
        return true
    }

    private func setupLoginItem() {
        try? SMAppService.mainApp.register()
    }
}
#endif
