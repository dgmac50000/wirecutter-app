import Foundation

final class SearchAPIClient {
    static let shared = SearchAPIClient()

    private let baseURL: URL

    init(baseURL: URL = URL(string: "https://YOUR_API_HOST")!) {
        self.baseURL = baseURL
    }

    func search(query: String) async throws -> GenaiSearchResponse {
        let url = baseURL.appendingPathComponent("/wirecutter/genai-search")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["query": query]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SearchError.badStatus(statusCode)
        }

        return try JSONDecoder().decode(GenaiSearchResponse.self, from: data)
    }
}

enum SearchError: LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            return "Server returned status \(code)"
        }
    }
}
