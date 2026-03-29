#if os(iOS)
import SwiftUI

struct iPadDashboardView: View {
    @Environment(NotificationStore.self) private var envStore: NotificationStore?
    @State private var ownStore = NotificationStore()
    @State private var selectedEvent: NotifyEvent?
    @State private var carouselSelection: Int?

    private var store: NotificationStore { envStore ?? ownStore }

    private var unreadEvents: [NotifyEvent] {
        store.events.filter { !$0.isRead }
    }

    private var recentEvents: [NotifyEvent] {
        Array(store.events.prefix(10))
    }

    private var carouselEvents: [NotifyEvent] {
        unreadEvents.isEmpty ? recentEvents : unreadEvents
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .refreshable { await store.refresh() }
        .task {
            if envStore == nil { await ownStore.refresh() }
        }
        .sheet(item: $selectedEvent) { event in
            NavigationStack {
                EventDetailView(event: event, store: store)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedEvent = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Portrait: carousel on top, list below

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            carouselSection
                .frame(height: 180)

            Divider()

            denseList
        }
    }

    // MARK: - Landscape: carousel on top, list below

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            carouselSection
                .frame(height: 220)

            Divider()

            denseList
        }
    }

    // MARK: - Carousel

    private var carouselSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(unreadEvents.isEmpty ? "Recent" : "Unread")
                    .font(.title3.bold())
                if !unreadEvents.isEmpty {
                    Text("\(unreadEvents.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                }
                Spacer()
                Text("NotifyHub")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(carouselEvents) { event in
                        CarouselCard(event: event)
                            .onTapGesture { selectedEvent = event }
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Dense list

    private var denseList: some View {
        List {
            ForEach(store.events) { event in
                DenseEventRow(event: event)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedEvent = event }
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task { await store.toggleRead(event) }
                        } label: {
                            Label(
                                event.isRead ? "Unread" : "Read",
                                systemImage: event.isRead ? "envelope.badge" : "envelope.open"
                            )
                        }
                        .tint(event.isRead ? .blue : .gray)
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Carousel Card

private struct CarouselCard: View {
    let event: NotifyEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                levelIcon
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if event.urgent {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(event.message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer()

            HStack {
                Text(event.source)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Text(event.createdAt, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 320, height: 160)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .overlay {
            if !event.isRead {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.blue, lineWidth: 3)
            }
        }
        .background {
            if !event.isRead {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.blue.opacity(0.06))
            }
        }
    }

    @ViewBuilder
    private var levelIcon: some View {
        switch event.level {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .warn:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.yellow)
        case .info:
            if !event.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Dense Event Row

private struct DenseEventRow: View {
    let event: NotifyEvent

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(event.isRead ? .clear : .blue)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(.system(size: 14, weight: event.isRead ? .regular : .semibold))
                        .lineLimit(1)
                    Spacer()
                    if event.urgent {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                    levelIcon
                    Text(event.createdAt, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 8) {
                    Text(event.source)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(event.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var levelIcon: some View {
        switch event.level {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        case .warn:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
        case .info:
            EmptyView()
        }
    }
}
#endif
