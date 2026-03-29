import Foundation
import SwiftUI

@Observable
final class NotificationStore {
    private(set) var events: [NotifyEvent] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private var nextCursor: Int?
    private var hasMore = true

    var unreadCount: Int {
        events.filter { !$0.isRead }.count
    }

    @MainActor
    func refresh() async {
        isLoading = true
        error = nil
        do {
            let response = try await WorkerClient.shared.fetchTimeline()
            events = response.events
            nextCursor = response.nextCursor
            hasMore = response.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func loadMore() async {
        guard hasMore, !isLoading, let cursor = nextCursor else { return }
        isLoading = true
        do {
            let response = try await WorkerClient.shared.fetchTimeline(cursor: cursor)
            events.append(contentsOf: response.events)
            nextCursor = response.nextCursor
            hasMore = response.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func toggleRead(_ event: NotifyEvent) async {
        do {
            if event.isRead {
                try await WorkerClient.shared.markUnread(eventId: event.id)
            } else {
                try await WorkerClient.shared.markRead(eventId: event.id)
            }
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
