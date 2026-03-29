import Foundation

enum EventLevel: String, Codable, CaseIterable {
    case info
    case warn
    case error
    case inProgress = "in_progress"
}

struct NotifyEvent: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let message: String
    let source: String
    let level: EventLevel
    let urgent: Bool
    let url: String?
    let taskId: String?
    let createdAt: Date
    let readAt: Date?

    var isRead: Bool { readAt != nil }
    var isUpcoming: Bool { createdAt > Date() }
}

struct TimelineResponse: Codable {
    let events: [NotifyEvent]
    let nextCursor: Int?
}
