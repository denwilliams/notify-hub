import SwiftUI

@main
struct NotifyHubApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif

    @State private var store = NotificationStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        #if os(macOS)
        // macOS uses the floating panel; this window group is hidden
        Settings {
            EmptyView()
        }
        #else
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refresh() }
                    }
                }
        }
        #endif
    }
}
