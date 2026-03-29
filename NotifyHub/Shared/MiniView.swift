#if os(macOS)
import SwiftUI

struct MiniView: View {
    @Bindable var store: NotificationStore
    @Binding var currentIndex: Int
    var onExpand: () -> Void
    var onTogglePin: () -> Void
    var isPinned: Bool

    private var event: NotifyEvent? {
        guard !store.events.isEmpty, currentIndex < store.events.count else { return nil }
        return store.events[currentIndex]
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
                        Text(event.createdAt, style: .relative)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    Task { await store.toggleRead(event) }
                }
            } else {
                Text("No events")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 220)
    }


}
#endif
