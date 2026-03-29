import Foundation

enum EventLevel: String, Codable, CaseIterable {
    case info
    case warn
    case error
}

struct NotifyEvent: Identifiable, Codable {
    let id: Int
    let title: String
    let message: String
    let source: String
    let level: EventLevel
    let urgent: Bool
    let url: String?
    let createdAt: Date
    let readAt: Date?

    var isRead: Bool { readAt != nil }
}

struct TimelineResponse: Codable {
    let events: [NotifyEvent]
    let nextCursor: Int?
}
