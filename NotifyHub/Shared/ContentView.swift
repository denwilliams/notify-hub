import SwiftUI

struct ContentView: View {
    @State private var store = NotificationStore()
    @State private var selectedEvent: NotifyEvent?

    var body: some View {
        NavigationSplitView {
            List(store.events, selection: $selectedEvent) { event in
                EventRow(event: event)
                    .tag(event)
                    .onAppear {
                        if event.id == store.events.last?.id {
                            Task { await store.loadMore() }
                        }
                    }
            }
            .navigationTitle("NotifyHub")
            .refreshable { await store.refresh() }
            .overlay {
                if store.events.isEmpty && !store.isLoading {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "bell.slash",
                        description: Text(store.error ?? "Events will appear here when received.")
                    )
                }
            }
        } detail: {
            if let event = selectedEvent {
                EventDetailView(event: event, store: store)
            } else {
                ContentUnavailableView("Select an Event", systemImage: "bell")
            }
        }
        .task { await store.refresh() }
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
