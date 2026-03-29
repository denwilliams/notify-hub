import UIKit
import BackgroundTasks

class IOSAppDelegate: NSObject, UIApplicationDelegate {
    static let backgroundTaskID = "com.notifyhub.app.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppBadge.requestPermission()
        registerBackgroundRefresh()
        return true
    }

    private func registerBackgroundRefresh() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskID,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task as! BGAppRefreshTask)
        }
        scheduleBackgroundRefresh()
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        let fetchTask = Task {
            let store = NotificationStore()
            await store.refresh()
            await AppBadge.update(count: store.unreadCount)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            fetchTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
