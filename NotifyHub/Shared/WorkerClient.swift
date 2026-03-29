import Foundation

final class WorkerClient {
    static let shared = WorkerClient()

    private let baseURL: URL
    private let apiKey: String

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let url = Bundle.main.object(forInfoDictionaryKey: "WorkerURL") as? String ?? "http://localhost:8787"
        self.baseURL = URL(string: url)!
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "APIKey") as? String ?? ""
    }

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        return req
    }

    func fetchTimeline(cursor: Int? = nil, limit: Int = 50) async throws -> TimelineResponse {
        var path = "/timeline?limit=\(limit)"
        if let cursor {
            path += "&cursor=\(cursor)"
        }
        let req = request(path)
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
