#if os(macOS)
import AppKit

enum DockBadge {
    static func update(count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    static func bounce() {
        NSApp.requestUserAttention(.criticalRequest)
    }
}
#endif
