import SwiftUI

struct ContentView: View {
    @Environment(NotificationStore.self) private var envStore: NotificationStore?
    @State private var ownStore = NotificationStore()
    @State var selectedEvent: NotifyEvent?
    @State var showSidebar = true
    var extraToolbar: (() -> AnyView)? = nil

    private var store: NotificationStore { envStore ?? ownStore }

    private var selectedIndex: Int? {
        guard let selected = selectedEvent else { return nil }
        return store.events.firstIndex(of: selected)
    }

    var body: some View {
        HSplitView {
            if showSidebar {
                List(store.events, selection: $selectedEvent) { event in
                    EventRow(event: event)
                        .tag(event)
                        .onAppear {
                            if event.id == store.events.last?.id {
                                Task { await store.loadMore() }
                            }
                        }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
                .overlay {
                    if store.events.isEmpty && !store.isLoading {
                        ContentUnavailableView(
                            "No Events",
                            systemImage: "bell.slash",
                            description: Text(store.error ?? "Events will appear here when received.")
                        )
                    }
                }
            }

            VStack(spacing: 0) {
                // Fixed toolbar
                HStack(spacing: 12) {
                    Button {
                        withAnimation { showSidebar.toggle() }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help(showSidebar ? "Hide sidebar" : "Show sidebar")

                    Button { navigatePrevious() } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == nil || selectedIndex == 0)

                    Button { navigateNext() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == nil || selectedIndex == store.events.count - 1)

                    Spacer()

                    if let extraToolbar {
                        extraToolbar()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Detail
                Group {
                    if let event = selectedEvent {
                        EventDetailView(event: event, store: store)
                    } else {
                        ContentUnavailableView("Select an Event", systemImage: "bell")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .refreshable { await store.refresh() }
        .task {
            if envStore == nil { await ownStore.refresh() }
        }
    }

    private func navigatePrevious() {
        guard let idx = selectedIndex, idx > 0 else { return }
        selectedEvent = store.events[idx - 1]
    }

    private func navigateNext() {
        guard let idx = selectedIndex, idx < store.events.count - 1 else { return }
        selectedEvent = store.events[idx + 1]
    }
}

struct EventRow: View {
    let event: NotifyEvent

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.isRead ? .clear : .blue)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if event.urgent {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }

                    levelBadge
                }

                Text(event.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Text(event.source)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())

                    Spacer()

                    Text(event.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var levelBadge: some View {
        switch event.level {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .warn:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
        case .info:
            EmptyView()
        }
    }
}
