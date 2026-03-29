import Foundation

final class WorkerClient {
    static let shared = WorkerClient()

    private let baseURL: URL
    private let apiKey: String

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) { return date }
            // Fallback without fractional seconds
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            if let date = basic.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return d
    }()

    private init() {
        let host = Bundle.main.object(forInfoDictionaryKey: "WorkerHost") as? String ?? "localhost:8787"
        let scheme = host.contains("localhost") ? "http" : "https"
        self.baseURL = URL(string: "\(scheme)://\(host)")!
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "APIKey") as? String ?? ""
    }

    private func request(_ path: String, query: [String: String] = [:], method: String = "GET") -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        return req
    }

    func fetchTimeline(cursor: Int? = nil, limit: Int = 50) async throws -> TimelineResponse {
        var query = ["limit": "\(limit)"]
        if let cursor {
            query["cursor"] = "\(cursor)"
        }
        let req = request("/timeline", query: query)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(TimelineResponse.self, from: data)
    }

    func markRead(eventId: Int) async throws {
        let req = request("/events/\(eventId)/read", method: "PUT")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }

    func markUnread(eventId: Int) async throws {
        let req = request("/events/\(eventId)/read", method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }
}
