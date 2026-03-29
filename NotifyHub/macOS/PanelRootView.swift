#if os(macOS)
import SwiftUI

@Observable
class PanelState {
    var currentIndex = 0
    var isPinned = true
    var previousEventCount = 0
}

struct PanelRootView {
    var store: NotificationStore
    var onExpand: () -> Void
    var onCollapse: () -> Void
    var onTogglePin: (Bool) -> Void

    var miniContent: some View {
        MiniPanelContent(
            store: store,
            onExpand: onExpand,
            onTogglePin: onTogglePin
        )
    }

    var fullContent: some View {
        FullPanelContent(
            store: store,
            onCollapse: onCollapse,
            onTogglePin: onTogglePin
        )
    }
}

private struct MiniPanelContent: View {
    var store: NotificationStore
    @State private var state = PanelState()
    var onExpand: () -> Void
    var onTogglePin: (Bool) -> Void

    var body: some View {
        MiniView(
            store: store,
            currentIndex: $state.currentIndex,
            onExpand: onExpand,
            onTogglePin: {
                state.isPinned.toggle()
                onTogglePin(state.isPinned)
            },
            isPinned: state.isPinned
        )
        .onChange(of: store.events.count) { oldCount, newCount in
            if newCount > state.previousEventCount && state.previousEventCount > 0 {
                state.currentIndex = 0
            }
            state.previousEventCount = newCount
        }
        .task {
            await store.refresh()
            state.previousEventCount = store.events.count
            DockBadge.update(count: store.unreadCount)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await store.refresh()
                DockBadge.update(count: store.unreadCount)
            }
        }
    }
}

private struct FullPanelContent: View {
    var store: NotificationStore
    @State private var isPinned = true
    var onCollapse: () -> Void
    var onTogglePin: (Bool) -> Void

    var body: some View {
        ContentView(
            extraToolbar: {
                AnyView(HStack(spacing: 12) {
                    Button {
                        isPinned.toggle()
                        onTogglePin(isPinned)
                    } label: {
                        Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help(isPinned ? "Unpin from top" : "Pin to top")

                    Button(action: onCollapse) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Collapse to mini view")
                })
            }
        )
        .environment(store)
    }
}
#endif
