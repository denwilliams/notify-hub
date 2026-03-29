import SwiftUI

struct EventDetailView: View {
    let event: NotifyEvent
    let store: NotificationStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    levelIcon
                    Text(event.title)
                        .font(.title2.bold())
                    Spacer()
                    if event.urgent {
                        Label("Urgent", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }

                Text(event.message)
                    .font(.body)

                Divider()

                LabeledContent("Source", value: event.source)
                LabeledContent("Level", value: event.level.rawValue)
                LabeledContent("Received", value: event.createdAt.formatted(.dateTime))

                if let readAt = event.readAt {
                    LabeledContent("Read", value: readAt.formatted(.dateTime))
                }

                if let urlString = event.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Open Link", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(event.isRead ? "Mark as Unread" : "Mark as Read") {
                    Task { await store.toggleRead(event) }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle(event.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if !event.isRead {
                await store.toggleRead(event)
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
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        }
    }
}
