#if os(macOS)
import SwiftUI

struct MiniView: View {
    @Bindable var store: NotificationStore
    @Binding var currentIndex: Int
    var onExpand: () -> Void
    var onTogglePin: () -> Void
    var isPinned: Bool
    @State private var isHovering = false

    private var event: NotifyEvent? {
        guard !store.events.isEmpty, currentIndex < store.events.count else { return nil }
        return store.events[currentIndex]
    }

    private var unreadIndices: [Int] {
        store.events.enumerated().compactMap { $0.element.isRead ? nil : $0.offset }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Toolbar: pin, < 1/1 >, expand
            HStack(spacing: 4) {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                        .font(.system(size: 9))
                        .foregroundStyle(isPinned ? .primary : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        currentIndex = max(currentIndex - 1, 0)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(currentIndex > 0 ? .secondary : .quaternary)
                .disabled(currentIndex <= 0)

                Text(store.events.isEmpty ? "0/0" : "\(currentIndex + 1)/\(store.events.count)")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)

                Button {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        currentIndex = min(currentIndex + 1, max(store.events.count - 1, 0))
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(currentIndex < store.events.count - 1 ? .secondary : .quaternary)
                .disabled(store.events.isEmpty || currentIndex >= store.events.count - 1)

                Spacer()

                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
            }

            if let event {
                VStack(alignment: .leading, spacing: 3) {
                    // Title row
                    HStack(spacing: 4) {
                        if !event.isRead {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)
                        }
                        Text(event.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        if event.urgent {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }

                    // Message
                    Text(event.message)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Source + time
                    HStack {
                        Text(event.source)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        RelativeTimeText(date: event.createdAt)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            } else {
                Text("No events")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 220)
        .overlay {
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if let event { Task { await store.toggleRead(event) } }
                    }
                    .onTapGesture(count: 1) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            currentIndex = max(currentIndex - 1, 0)
                        }
                    }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if let event { Task { await store.toggleRead(event) } }
                    }
                    .onTapGesture(count: 1) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            currentIndex = min(currentIndex + 1, max(store.events.count - 1, 0))
                        }
                    }
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .task(id: isHovering) {
            guard !isHovering else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !isHovering else { return }
                let unread = unreadIndices
                guard !unread.isEmpty else { continue }
                // If currently on an unread event and it's the only one, stay
                if unread.count == 1 && unread.first == currentIndex { continue }
                // Find the next unread index after current, wrapping around
                let next = unread.first(where: { $0 > currentIndex }) ?? unread.first!
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentIndex = next
                }
            }
        }
    }


}
#endif
