#if os(iOS)
import UIKit
import UserNotifications

enum AppBadge {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { _, _ in }
    }

    @MainActor
    static func update(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
#endif
